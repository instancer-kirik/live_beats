defmodule LiveBeats.Streaming.DiscoveryNode do
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      :node_id,
      :libp2p_host,
      known_peers: %{},           # Peer ID => Peer Info
      stream_registry: %{},       # Stream ID => Stream Info
      peer_streams: %{},          # Peer ID => [Stream IDs]
      discovery_topics: ["live_beats:streams", "live_beats:discovery"],
      last_heartbeat: %{}         # Peer ID => Last Heartbeat
    ]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_available_peers do
    GenServer.call(__MODULE__, :get_available_peers)
  end

  @impl true
  def init(_opts) do
    {:ok, %State{}, {:continue, :setup_discovery}}
  end

  @impl true
  def handle_continue(:setup_discovery, state) do
    # Initialize LibP2P host and join DHT
    {:ok, host} = LibP2P.new_host([
      listen_addrs: ["/ip4/0.0.0.0/tcp/0"],
      protocols: ["stream-discovery/1.0.0"]
    ])

    node_id = LibP2P.get_peer_id(host)

    # Join discovery network
    Enum.each(state.discovery_topics, fn topic ->
      LibP2P.join_topic(host, topic)
    end)

    # Start periodic tasks
    schedule_heartbeat()
    schedule_cleanup()

    {:noreply, %State{state |
      node_id: node_id,
      libp2p_host: host
    }}
  end

  # Handle incoming peer announcements
  @impl true
  def handle_info({:peer_announcement, peer_id, streams}, state) do
    new_state = state
    |> update_peer_info(peer_id, streams)
    |> broadcast_local_streams(peer_id)
    |> aggregate_streams()

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    broadcast_heartbeat(state)
    schedule_heartbeat()
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup_peers, state) do
    new_state = cleanup_stale_peers(state)
    schedule_cleanup()
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_available_peers, _from, state) do
    peers = state.known_peers
    |> Map.keys()
    |> Enum.filter(fn peer_id ->
      peer = Map.get(state.known_peers, peer_id)
      is_peer_alive?(peer, state)
    end)

    {:reply, peers, state}
  end

  defp broadcast_local_streams(state, peer_id) do
    # Get local streams
    local_streams = Map.get(state.peer_streams, state.node_id, [])
    
    # Send them to the new peer
    LibP2P.send_message(state.libp2p_host, peer_id, {:streams, local_streams})
    
    state
  end

  defp update_peer_info(state, peer_id, streams) do
    now = System.system_time(:second)
    
    new_peer_info = %{
      last_seen: now,
      streams: streams
    }

    %{state |
      known_peers: Map.put(state.known_peers, peer_id, new_peer_info),
      peer_streams: Map.put(state.peer_streams, peer_id, streams)
    }
  end

  defp aggregate_streams(state) do
    all_streams = state.peer_streams
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()

    %{state | stream_registry: Map.new(all_streams, &{&1.id, &1})}
  end

  defp is_peer_alive?(peer, state) do
    now = System.system_time(:second)
    last_seen = peer.last_seen
    now - last_seen < Application.get_env(:live_beats, :peer_timeout, 30)
  end

  defp cleanup_stale_peers(state) do
    alive_peers = state.known_peers
    |> Enum.filter(fn {_id, peer} -> is_peer_alive?(peer, state) end)
    |> Map.new()

    %{state |
      known_peers: alive_peers,
      peer_streams: Map.take(state.peer_streams, Map.keys(alive_peers))
    }
  end

  defp broadcast_heartbeat(state) do
    message = {:heartbeat, state.node_id, Map.get(state.peer_streams, state.node_id, [])}
    
    Enum.each(state.discovery_topics, fn topic ->
      LibP2P.publish(state.libp2p_host, topic, message)
    end)
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, heartbeat_interval())
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_peers, cleanup_interval())
  end

  defp heartbeat_interval, do: Application.get_env(:live_beats, :heartbeat_interval, 5000)
  defp cleanup_interval, do: Application.get_env(:live_beats, :cleanup_interval, 10000)
end
