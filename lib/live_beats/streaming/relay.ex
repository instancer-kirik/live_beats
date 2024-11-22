defmodule LiveBeats.Streaming.Relay do
  use GenServer
  require Logger

  @default_capacity_threshold 0.8  # 80% capacity
  @chunk_ttl :timer.minutes(5)     # Keep chunks for 5 minutes

  defmodule State do
    defstruct [
      :node_id,
      :node_type,
      chunks: %{},           # chunk_id => {chunk, timestamp}
      viewers: MapSet.new(), # Set of viewer connections
      relay_nodes: [],       # List of other relay nodes
      capacity: 1.0,         # Current capacity (0.0 to 1.0)
      stats: %{
        chunks_received: 0,
        chunks_relayed: 0,
        bytes_transferred: 0
      }
    ]
  end

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def join_as_viewer(viewer_id) do
    GenServer.call(__MODULE__, {:join_viewer, viewer_id})
  end

  def leave_as_viewer(viewer_id) do
    GenServer.call(__MODULE__, {:leave_viewer, viewer_id})
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    node_type = Keyword.get(opts, :node_type, :viewer_relay)
    node_id = generate_node_id()

    # Start periodic cleanup
    schedule_cleanup()

    {:ok, %State{
      node_id: node_id,
      node_type: node_type
    }}
  end

  @impl true
  def handle_call({:join_viewer, viewer_id}, _from, state) do
    new_state = %State{state |
      viewers: MapSet.put(state.viewers, viewer_id)
    }
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:leave_viewer, viewer_id}, _from, state) do
    new_state = %State{state |
      viewers: MapSet.delete(state.viewers, viewer_id)
    }
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info(:cleanup_chunks, state) do
    new_state = cleanup_old_chunks(state)
    schedule_cleanup()
    {:noreply, new_state}
  end

  def handle_stream_chunk(chunk, state) do
    case Application.get_env(:live_beats, :stream_mode) do
      :hybrid ->
        # Store on your server
        store_chunk(chunk)

        # Also distribute to relay nodes
        state.relay_nodes
        |> Enum.filter(&(&1.capacity > threshold()))
        |> Enum.each(&relay_chunk(&1, chunk))

        # Update stats
        new_stats = Map.update!(state.stats, :chunks_received, &(&1 + 1))
        {:noreply, %State{state | stats: new_stats}}
    end
  end

  # Private Functions

  defp store_chunk(chunk) do
    chunk_id = generate_chunk_id(chunk)
    now = System.system_time(:millisecond)

    # Store in ETS for fast access
    :ets.insert(:stream_chunks, {chunk_id, chunk, now})

    # Also store metadata in state
    GenServer.cast(__MODULE__, {:chunk_stored, chunk_id, byte_size(chunk)})
  end

  defp send_chunk(viewer, chunk) do
    case viewer.transport do
      :websocket ->
        Phoenix.Channel.push(viewer.socket, "stream_chunk", %{
          chunk: Base.encode64(chunk),
          timestamp: System.system_time(:millisecond)
        })

      :webrtc ->
        WebRTC.send_chunk(viewer.peer_connection, chunk)
    end

    # Update stats
    GenServer.cast(__MODULE__, {:chunk_sent, byte_size(chunk)})
  end

  defp threshold do
    Application.get_env(:live_beats, :relay_capacity_threshold, @default_capacity_threshold)
  end

  defp cleanup_old_chunks(state) do
    now = System.system_time(:millisecond)
    cutoff = now - @chunk_ttl

    # Remove old chunks from ETS
    :ets.select_delete(:stream_chunks, [{
      {:'_', :'_', :'$1'},
      [{:<, :'$1', cutoff}],
      [true]
    }])

    # Update capacity based on remaining chunks
    remaining_chunks = :ets.info(:stream_chunks, :size)
    max_chunks = Application.get_env(:live_beats, :max_chunks, 10000)
    new_capacity = 1.0 - (remaining_chunks / max_chunks)

    %State{state | capacity: new_capacity}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_chunks, :timer.minutes(1))
  end

  defp generate_node_id do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end

  defp generate_chunk_id(chunk) do
    :crypto.hash(:sha256, chunk)
    |> Base.url_encode64(padding: false)
  end

  # Handle stats updates
  @impl true
  def handle_cast({:chunk_stored, _chunk_id, size}, state) do
    new_stats = Map.update!(state.stats, :bytes_transferred, &(&1 + size))
    {:noreply, %State{state | stats: new_stats}}
  end

  @impl true
  def handle_cast({:chunk_sent, size}, state) do
    new_stats = state.stats
    |> Map.update!(:chunks_relayed, &(&1 + 1))
    |> Map.update!(:bytes_transferred, &(&1 + size))

    {:noreply, %State{state | stats: new_stats}}
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
