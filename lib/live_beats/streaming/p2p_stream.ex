defmodule LiveBeats.Streaming.P2PStream do
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
end
