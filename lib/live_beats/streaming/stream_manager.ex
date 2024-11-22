defmodule LiveBeats.Streaming.StreamManager do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{
      active_streams: %{},
      stream_mode: Application.get_env(:live_beats, :stream_mode, :centralized)
    }}
  end

  def start_stream(stream_key, opts \\ []) do
    GenServer.call(__MODULE__, {:start_stream, stream_key, opts})
  end

  def get_stream(stream_key) do
    GenServer.call(__MODULE__, {:get_stream, stream_key})
  end

  def stop_stream(stream_key) do
    GenServer.call(__MODULE__, {:stop_stream, stream_key})
  end

  @impl true
  def handle_call({:start_stream, stream_key, opts}, _from, state) do
    case state.stream_mode do
      :centralized ->
        # Simple RTMP ingestion
        {:ok, stream} = setup_rtmp_stream(stream_key, opts)
        new_state = put_in(state.active_streams[stream_key], stream)
        {:reply, {:ok, stream}, new_state}

      :hybrid ->
        # RTMP ingestion + relay nodes
        with {:ok, stream} <- setup_rtmp_stream(stream_key, opts),
             {:ok, relays} <- setup_relay_nodes(stream) do
          stream = Map.put(stream, :relays, relays)
          new_state = put_in(state.active_streams[stream_key], stream)
          {:reply, {:ok, stream}, new_state}
        end

      :p2p ->
        # WebRTC-based P2P streaming
        {:ok, stream} = setup_p2p_stream(stream_key, opts)
        new_state = put_in(state.active_streams[stream_key], stream)
        {:reply, {:ok, stream}, new_state}
    end
  end

  @impl true
  def handle_call({:get_stream, stream_key}, _from, state) do
    case Map.fetch(state.active_streams, stream_key) do
      {:ok, stream} -> {:reply, {:ok, stream}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:stop_stream, stream_key}, _from, state) do
    case Map.fetch(state.active_streams, stream_key) do
      {:ok, stream} ->
        cleanup_stream(stream)
        new_state = update_in(state.active_streams, &Map.delete(&1, stream_key))
        {:reply, :ok, new_state}
      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  defp host do
    Application.get_env(:live_beats, :streaming_host, "localhost")
  end

  defp setup_rtmp_stream(stream_key, opts) do
    # Basic RTMP setup for OBS/streaming software
    rtmp_url = "rtmp://#{host()}:1935/live/#{stream_key}"
    playback_url = "http://#{host()}:8080/hls/#{stream_key}/index.m3u8"

    {:ok, %{
      rtmp_url: rtmp_url,
      playback_url: playback_url,
      stream_key: stream_key,
      type: :rtmp,
      started_at: DateTime.utc_now(),
      options: opts
    }}
  end

  defp setup_p2p_stream(stream_key, opts) do
    # Setup WebRTC P2P streaming
    ice_servers = Application.get_env(:live_beats, :ice_servers, [
      %{urls: ["stun:stun.l.google.com:19302"]}
    ])

    {:ok, %{
      stream_key: stream_key,
      type: :p2p,
      ice_servers: ice_servers,
      started_at: DateTime.utc_now(),
      options: opts,
      peers: MapSet.new()
    }}
  end

  defp setup_relay_nodes(stream) do
    # Get available relay nodes from discovery
    nodes = LiveBeats.Streaming.DiscoveryNode.get_available_peers()
    |> Enum.filter(&(&1.type == :relay))
    |> Enum.sort_by(&(&1.capacity), :desc)
    |> Enum.take(3)  # Use top 3 nodes by capacity

    # Setup relay configuration
    relays = Enum.map(nodes, fn node ->
      %{
        node_id: node.id,
        capacity: node.capacity,
        url: "http://#{node.host}:#{node.port}/relay/#{stream.stream_key}"
      }
    end)

    {:ok, relays}
  end

  defp cleanup_stream(%{type: :rtmp} = stream) do
    # Cleanup RTMP/HLS files
    stream_path = Path.join([Application.get_env(:live_beats, :media_path), stream.stream_key])
    File.rm_rf!(stream_path)
  end

  defp cleanup_stream(%{type: :p2p} = stream) do
    # Notify peers to disconnect
    for peer <- stream.peers do
      WebRTC.send_message(peer, {:stream_ended, stream.stream_key})
    end
  end

  defp cleanup_stream(%{relays: relays} = stream) do
    # Cleanup both RTMP and relay resources
    cleanup_stream(%{stream | type: :rtmp})
    
    # Notify relay nodes
    for relay <- relays do
      LiveBeats.Streaming.Relay.stop_stream(relay.node_id, stream.stream_key)
    end
  end
end
