defmodule LiveBeats.Streaming.P2PStream do
  alias LiveBeats.Streaming.DiscoveryNode

  @chunk_size 65536  # 64KB chunks

  def handle_stream(stream) do
    case Application.get_env(:live_beats, :stream_mode) do
      :p2p ->
        # Create WebRTC mesh network
        peers = get_available_peers()

        # Distribute stream chunks via WebRTC
        stream
        |> chunk_stream()
        |> Enum.each(fn chunk ->
          WebRTC.broadcast_to_peers(peers, chunk)
        end)
    end
  end

  def get_available_peers do
    DiscoveryNode.get_available_peers()
  end

  def chunk_stream(stream) do
    Stream.resource(
      fn -> start_stream_read(stream) end,
      &read_chunk/1,
      &close_stream/1
    )
  end

  defp start_stream_read(stream) do
    case stream do
      %{path: path} when is_binary(path) ->
        File.open!(path, [:read, :binary])
      
      %{data: data} when is_binary(data) ->
        {:memory, data, 0}
      
      _ ->
        raise "Invalid stream source"
    end
  end

  defp read_chunk({:memory, data, pos}) do
    case binary_part(data, pos, min(@chunk_size, byte_size(data) - pos)) do
      "" -> {:halt, {:memory, data, pos}}
      chunk ->
        new_pos = pos + byte_size(chunk)
        {[chunk], {:memory, data, new_pos}}
    end
  end

  defp read_chunk(file) do
    case IO.binread(file, @chunk_size) do
      :eof -> {:halt, file}
      data -> {[data], file}
    end
  end

  defp close_stream({:memory, _data, _pos}), do: :ok
  defp close_stream(file), do: File.close(file)

  defp create_chunk_metadata(chunk, index) do
    %{
      index: index,
      size: byte_size(chunk),
      timestamp: System.system_time(:millisecond)
    }
  end
end
