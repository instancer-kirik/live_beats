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

  # Periodic heartbeat to maintain peer list
  @impl true
  def handle_info(:heartbeat, state) do
    broadcast_announcement(state)
    schedule_heartbeat()
    {:noreply, state}
  end

  # Clean up stale peers
  @impl true
  def handle_info(:cleanup, state) do
    new_state = cleanup_stale_peers(state)
    schedule_cleanup()
    {:noreply, new_state}
  end

  # Private functions
  defp update_peer_info(state, peer_id, streams) do
    %State{state |
      known_peers: Map.put(state.known_peers, peer_id, %{
        last_seen: DateTime.utc_now(),
        stream_count: length(streams)
      }),
      peer_streams: Map.put(state.peer_streams, peer_id, streams)
    }
  end

  defp aggregate_streams(state) do
    # Combine local and peer streams
    all_streams = state.peer_streams
    |> Map.values()
    |> List.flatten()
    |> Enum.concat(Map.values(state.stream_registry))
    |> Enum.uniq_by(& &1.id)
    |> sort_by_relevance()

    # Broadcast aggregated streams
    Phoenix.PubSub.broadcast(
      LiveBeats.PubSub,
      "stream_discovery",
      {:streams_updated, all_streams}
    )

    state
  end

  defp sort_by_relevance(streams) do
    Enum.sort_by(streams, fn stream ->
      {
        stream.viewer_count,
        stream.stake_amount,
        -DateTime.to_unix(stream.started_at)
      }
    end, :desc)
  end

  defp broadcast_announcement(state) do
    local_streams = Map.values(state.stream_registry)

    LibP2P.publish(state.libp2p_host, "live_beats:discovery", %{
      peer_id: state.node_id,
      streams: local_streams,
      timestamp: DateTime.utc_now()
    })
  end

  defp cleanup_stale_peers(state) do
    timeout = Application.get_env(:live_beats, :peer_timeout, 30)
    now = DateTime.utc_now()

    {active_peers, stale_peers} = Enum.split_with(state.known_peers, fn {_id, info} ->
      DateTime.diff(now, info.last_seen) < timeout
    end)

    # Remove stale peers
    new_state = %State{state |
      known_peers: Map.new(active_peers),
      peer_streams: Map.drop(state.peer_streams, Keyword.keys(stale_peers))
    }

    # Re-aggregate without stale peers
    aggregate_streams(new_state)
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, :timer.seconds(10))
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.seconds(30))
  end
end
