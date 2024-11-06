defmodule LiveBeats.Streaming.StreamRegistry do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{streams: %{}, metrics: %{}}}
  end

  def register_stream(stream_id, stream_info) do
    GenServer.call(__MODULE__, {:register_stream, stream_id, stream_info})
  end

  def list_active_streams do
    GenServer.call(__MODULE__, :list_active_streams)
  end

  def get_stream_metrics(stream_id) do
    GenServer.call(__MODULE__, {:get_metrics, stream_id})
  end

  # ... implement handle_call callbacks ...
end
