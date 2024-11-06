defmodule LiveBeats.Streaming.MediaServer do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    config = LiveBeats.Streaming.Config.get_config()

    # Start NGINX-RTMP or other media server
    case start_media_server(config) do
      {:ok, pid} -> {:ok, %{server_pid: pid, config: config}}
      {:error, reason} -> {:stop, reason}
    end
  end

  defp start_media_server(config) do
    # Example using nginx-rtmp
    nginx_conf = generate_nginx_conf(config)
    case System.cmd("nginx", ["-c", nginx_conf]) do
      {_, 0} -> {:ok, nil}
      {error, _} -> {:error, error}
    end
  end

  defp generate_nginx_conf(config) do
    """
    worker_processes auto;
    events {
      worker_connections 1024;
    }

    rtmp {
      server {
        listen #{config.rtmp_port};
        chunk_size 4096;

        application live {
          live on;
          record off;

          hls on;
          hls_path #{config.storage_path};
          hls_fragment 3;
          hls_playlist_length 60;
        }
      }
    }
    """
  end

  def handle_stream(stream) do
    case Application.get_env(:live_beats, :stream_mode) do
      :centralized ->
        # Direct RTMP ingestion and HLS distribution
        {:ok, _} = RTMP.accept_stream(stream)
        transcode_to_hls(stream)
    end
  end
end
