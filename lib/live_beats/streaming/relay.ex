defmodule LiveBeats.Streaming.Relay do
  use GenServer

  def handle_stream_chunk(chunk, state) do
    case Application.get_env(:live_beats, :stream_mode) do
      :hybrid ->
        # Store on your server
        store_chunk(chunk)

        # Also distribute to relay nodes
        state.relay_nodes
        |> Enum.filter(&(&1.capacity > threshold()))
        |> Enum.each(&relay_chunk(&1, chunk))
    end
  end

  defp relay_chunk(node, chunk) do
    case node.type do
      :viewer_relay ->
        # Send to viewers connected to this relay
        node.viewers
        |> Enum.each(&send_chunk(&1, chunk))

      :edge_relay ->
        # Send to edge servers for regional distribution
        EdgeNode.distribute(node, chunk)
    end
  end
end
