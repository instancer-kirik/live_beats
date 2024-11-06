defmodule LiveBeats.Streaming.NodeManager do
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      :ipfs_node,
      :libp2p_host,
      :peer_id,
      :discovery_service,
      :stream_protocol,
      connected_peers: %{},
      stream_registry: %{}
    ]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %State{}, {:continue, :init_node}}
  end

  @impl true
  def handle_continue(:init_node, state) do
    # Initialize IPFS node and LibP2P host
    {:ok, ipfs_node} = IPFS.start_node()
    {:ok, libp2p_host} = LibP2P.new_host([
      listen_addrs: ["/ip4/0.0.0.0/tcp/0"],
      protocols: ["stream/1.0.0"]
    ])
    {:ok, peer_id} = LibP2P.get_peer_id(libp2p_host)

    # Initialize discovery service
    {:ok, discovery} = LibP2P.new_discovery_service(libp2p_host)

    # Initialize stream protocol handler
    {:ok, stream_protocol} = init_stream_protocol(libp2p_host)

    # Start discovery of other nodes
    LibP2P.advertise(discovery, "live_beats_stream", peer_id)

    Logger.info("Node started with peer_id: #{peer_id}")

    {:noreply, %State{
      ipfs_node: ipfs_node,
      libp2p_host: libp2p_host,
      peer_id: peer_id,
      discovery_service: discovery,
      stream_protocol: stream_protocol
    }}
  end

  @impl true
  def handle_info({:peer_discovered, peer_id, "live_beats_stream"}, state) do
    case connect_to_peer(peer_id, state) do
      {:ok, peer_info} ->
        new_peers = Map.put(state.connected_peers, peer_id, peer_info)
        {:noreply, %{state | connected_peers: new_peers}}
      {:error, reason} ->
        Logger.warn("Failed to connect to peer #{peer_id}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_node_info, _from, state) do
    info = %{
      peer_id: state.peer_id,
      connected_peers: map_size(state.connected_peers),
      active_streams: map_size(state.stream_registry)
    }
    {:reply, info, state}
  end

  # Stream handling
  def register_stream(stream_id, stream_info) do
    GenServer.call(__MODULE__, {:register_stream, stream_id, stream_info})
  end

  def get_stream_peers(stream_id) do
    GenServer.call(__MODULE__, {:get_stream_peers, stream_id})
  end

  # Private functions
  defp init_stream_protocol(host) do
    LibP2P.new_protocol(host, "stream/1.0.0", fn stream ->
      handle_stream_protocol(stream)
    end)
  end

  defp handle_stream_protocol(stream) do
    # Handle incoming stream data
    # This could be stream metadata, viewer counts, etc.
    Task.start(fn ->
      case StreamProtocol.handle_stream(stream) do
        {:ok, data} ->
          Phoenix.PubSub.broadcast(
            LiveBeats.PubSub,
            "stream_updates",
            {:stream_data, data}
          )
        {:error, reason} ->
          Logger.error("Stream protocol error: #{inspect(reason)}")
      end
    end)
  end

  defp connect_to_peer(peer_id, state) do
    with {:ok, connection} <- LibP2P.connect(state.libp2p_host, peer_id),
         {:ok, peer_info} <- exchange_metadata(connection) do
      {:ok, %{
        connection: connection,
        info: peer_info,
        connected_at: DateTime.utc_now()
      }}
    end
  end

  defp exchange_metadata(connection) do
    # Exchange node capabilities, supported protocols, etc.
    LibP2P.send_protocol_message(connection, "metadata", %{
      version: "1.0.0",
      capabilities: ["stream", "relay"],
      streams: get_active_streams()
    })
  end

  defp get_active_streams do
    # Get list of active streams from StreamRegistry
    LiveBeats.Streaming.StreamRegistry.list_active_streams()
  end
end
