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

          # Enable recording for clips
          record_path #{config.clips_path};
          record_unique on;
          record_append on;
          
          # Execute callback when recording is done
          exec_record_done ffmpeg -i $path -c copy $dirname/$basename.mp4;
          on_record_done http://localhost:4000/api/clips/complete;
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

  defp transcode_to_hls(stream) do
    config = LiveBeats.Streaming.Config.get_config()
    stream_key = stream.key
    output_path = Path.join(config.storage_path, stream_key)

    # Ensure output directory exists
    File.mkdir_p!(output_path)

    # Start FFmpeg for HLS transcoding
    ffmpeg_args = [
      "-i", "rtmp://localhost:#{config.rtmp_port}/live/#{stream_key}",
      "-c:v", "libx264",
      "-c:a", "aac",
      "-b:v", "2500k",
      "-b:a", "128k",
      "-vf", "scale=1280:720",
      "-f", "hls",
      "-hls_time", "4",
      "-hls_list_size", "3",
      "-hls_flags", "delete_segments",
      "-hls_segment_filename", "#{output_path}/%d.ts",
      "#{output_path}/playlist.m3u8"
    ]

    case System.cmd("ffmpeg", ffmpeg_args, stderr_to_stdout: true) do
      {_, 0} -> {:ok, output_path}
      {error, _} -> {:error, error}
    end
  end

  @doc """
  Save a clip from the stream with metadata.
  """
  def save_clip(stream_key, start_time, duration, metadata) do
    config = LiveBeats.Streaming.Config.get_config()
    clip_id = generate_clip_id()
    output_path = Path.join(config.clips_path, clip_id)

    # Ensure clips directory exists
    File.mkdir_p!(config.clips_path)

    # Start FFmpeg for clip extraction
    ffmpeg_args = [
      "-ss", "#{start_time}",
      "-t", "#{duration}",
      "-i", "#{config.storage_path}/#{stream_key}/playlist.m3u8",
      "-c", "copy",
      "-y",
      "#{output_path}.mp4"
    ]

    case System.cmd("ffmpeg", ffmpeg_args, stderr_to_stdout: true) do
      {_, 0} ->
        # Save metadata
        metadata = Map.merge(metadata, %{
          clip_id: clip_id,
          stream_key: stream_key,
          start_time: start_time,
          duration: duration,
          created_at: DateTime.utc_now()
        })
        
        save_clip_metadata(clip_id, metadata)
        {:ok, clip_id}

      {error, _} ->
        {:error, error}
    end
  end

  defp generate_clip_id do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end

  defp save_clip_metadata(clip_id, metadata) do
    metadata_path = Path.join([LiveBeats.Streaming.Config.get_config().clips_path, "#{clip_id}.json"])
    File.write!(metadata_path, Jason.encode!(metadata))
  end

  @doc """
  Get clip metadata by ID.
  """
  def get_clip_metadata(clip_id) do
    config = LiveBeats.Streaming.Config.get_config()
    metadata_path = Path.join([config.clips_path, "#{clip_id}.json"])

    case File.read(metadata_path) do
      {:ok, content} -> Jason.decode!(content)
      {:error, _} -> nil
    end
  end
end
