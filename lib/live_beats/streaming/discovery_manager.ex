defmodule LiveBeats.Streaming.DiscoveryManager do
  use GenServer

  defmodule State do
    defstruct [
      active_streams: %{},
      featured_streams: [],
      categories: %{},
      metrics: %{}
    ]
  end

  def handle_stream_start(stream) do
    GenServer.cast(__MODULE__, {:stream_started, stream})
  end

  def handle_stream_end(stream_id) do
    GenServer.cast(__MODULE__, {:stream_ended, stream_id})
  end

  def get_featured_streams do
    GenServer.call(__MODULE__, :get_featured)
  end

  def get_streams_by_category(category) do
    GenServer.call(__MODULE__, {:get_by_category, category})
  end
end
