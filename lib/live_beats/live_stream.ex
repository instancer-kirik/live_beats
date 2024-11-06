defmodule LiveBeats.LiveStream do
  use GenServer
  require Logger

  defmodule State do
    defstruct [:stream_id, :ipfs_node, :stream_key, :viewers, :metadata]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %State{
      viewers: %{},
      metadata: %{},
      ipfs_node: init_ipfs_node()
    }}
  end

  # Public API
  def start_stream(stream_key, metadata) do
    GenServer.call(__MODULE__, {:start_stream, stream_key, metadata})
  end

  def stop_stream(stream_id) do
    GenServer.call(__MODULE__, {:stop_stream, stream_id})
  end

  # Private Functions
  defp init_ipfs_node do
    # Initialize IPFS node for stream storage
    # This would integrate with your IPFS/LibP2P implementation
  end
end
