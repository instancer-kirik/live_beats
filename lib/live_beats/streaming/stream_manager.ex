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

  @impl true
  def handle_call({:start_stream, stream_key, opts}, _from, state) do
    case state.stream_mode do
      :centralized ->
        # Simple RTMP ingestion
        {:ok, stream} = setup_rtmp_stream(stream_key, opts)
        {:reply, {:ok, stream}, state}

      :hybrid ->
        # RTMP ingestion + relay nodes
        with {:ok, stream} <- setup_rtmp_stream(stream_key, opts),
             {:ok, relays} <- setup_relay_nodes(stream) do
          {:reply, {:ok, stream}, state}
        end

      :p2p ->
        # WebRTC-based P2P streaming
        {:ok, stream} = setup_p2p_stream(stream_key, opts)
        {:reply, {:ok, stream}, state}
    end
  end

  defp setup_rtmp_stream(stream_key, opts) do
    # Basic RTMP setup for OBS/streaming software
    rtmp_url = "rtmp://#{host()}:1935/live/#{stream_key}"
    playback_url = "http://#{host()}:8080/hls/#{stream_key}/index.m3u8"

    {:ok, %{
      rtmp_url: rtmp_url,
      playback_url: playback_url,
      stream_key: stream_key
    }}
  end
end
