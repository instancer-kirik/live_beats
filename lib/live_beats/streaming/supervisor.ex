defmodule LiveBeats.Streaming.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      LiveBeats.Streaming.Config,
      LiveBeats.Streaming.MediaServer,
      LiveBeats.Streaming.NodeManager,
      LiveBeats.Streaming.TranscodingManager,
      {Registry, keys: :unique, name: LiveBeats.Streaming.Registry},
      {DynamicSupervisor, name: LiveBeats.Streaming.StreamSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
