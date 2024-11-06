defmodule LiveBeats.Streaming.StreamProtocol do
  use Protobuf, syntax: :proto3

  defmodule StreamMessage do
    use Protobuf, syntax: :proto3

    @derive Jason.Encoder
    defstruct [:type, :stream_id, :data, :timestamp]

    field :type, 1, type: :string
    field :stream_id, 2, type: :string
    field :data, 3, type: :bytes
    field :timestamp, 4, type: :int64
  end

  def handle_stream(stream) do
    case read_message(stream) do
      {:ok, message} -> process_message(message)
      error -> error
    end
  end

  def process_message(%StreamMessage{type: "viewer_join"} = msg) do
    LiveBeats.Streaming.Stream.handle_viewer_join(msg.stream_id, msg.data)
  end

  def process_message(%StreamMessage{type: "stream_chunk"} = msg) do
    LiveBeats.Streaming.Stream.handle_stream_chunk(msg.stream_id, msg.data)
  end

  # Add more message handlers as needed
end
