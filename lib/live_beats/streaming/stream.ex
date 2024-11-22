defmodule LiveBeats.Streaming.Stream do
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      :id,
      :owner_id,
      :title,
      :stream_key,
      :playback_url,
      :rtmp_url,
      :status,
      :started_at,
      :thumbnail_url,
      :category,
      viewers: %{},
      chat_messages: [],
      stream_metrics: %{},
      recording_path: nil,
      streamer_address: nil,
      stake_amount: 0,
      token_contract: nil,
      rewards_contract: nil,
      tips: [],
      rewards_earned: 0
    ]
  end

  # Public API
  def start_link(opts) do
    stream_id = opts[:stream_id] || raise ArgumentError, "stream_id is required"
    owner_id = opts[:owner_id] || raise ArgumentError, "owner_id is required"

    GenServer.start_link(__MODULE__, opts, name: via_tuple(stream_id))
  end

  def get_stream(stream_id) do
    GenServer.call(via_tuple(stream_id), :get_stream)
  end

  def update_title(stream_id, title) do
    GenServer.call(via_tuple(stream_id), {:update_title, title})
  end

  def add_viewer(stream_id, viewer_id) do
    GenServer.call(via_tuple(stream_id), {:add_viewer, viewer_id})
  end

  def remove_viewer(stream_id, viewer_id) do
    GenServer.call(via_tuple(stream_id), {:remove_viewer, viewer_id})
  end

  def stop_stream(stream_id) do
    GenServer.call(via_tuple(stream_id), :stop_stream)
  end

  def handle_tip(stream_id, tip) do
    GenServer.call(via_tuple(stream_id), {:handle_tip, tip})
  end

  def update_stake(stream_id, stake_info) do
    GenServer.call(via_tuple(stream_id), {:update_stake, stake_info})
  end

  def get_stake(stream_id) do
    GenServer.call(via_tuple(stream_id), :get_stake)
  end

  # GenServer Callbacks
  @impl true
  def init(opts) do
    stream_id = opts[:stream_id]
    owner_id = opts[:owner_id]
    title = opts[:title] || "Untitled Stream"
    category = opts[:category]

    state = %State{
      id: stream_id,
      owner_id: owner_id,
      title: title,
      category: category,
      status: :initializing,
      started_at: DateTime.utc_now(),
      stream_key: generate_stream_key(owner_id),
      streamer_address: opts[:streamer_address],
      token_contract: get_token_contract(),
      rewards_contract: get_rewards_contract(),
      stake_amount: 0,
      tips: [],
      rewards_earned: 0
    }

    {:ok, state, {:continue, :setup_stream}}
  end

  @impl true
  def handle_continue(:setup_stream, state) do
    case setup_stream(state) do
      {:ok, stream_info} ->
        new_state = %{state |
          rtmp_url: stream_info.rtmp_url,
          playback_url: stream_info.playback_url,
          status: :ready
        }
        {:noreply, new_state}
      {:error, reason} ->
        Logger.error("Failed to setup stream: #{inspect(reason)}")
        {:stop, reason, state}
    end
  end

  @impl true
  def handle_call(:get_stream, _from, state) do
    {:reply, {:ok, state_to_map(state)}, state}
  end

  def handle_call({:update_title, title}, _from, state) do
    new_state = %{state | title: title}
    {:reply, :ok, new_state}
  end

  def handle_call({:add_viewer, viewer_id}, _from, state) do
    new_state = update_in(state.viewers, &Map.put(&1, viewer_id, %{
      joined_at: DateTime.utc_now(),
      tips_sent: 0
    }))
    {:reply, :ok, new_state}
  end

  def handle_call({:remove_viewer, viewer_id}, _from, state) do
    new_state = update_in(state.viewers, &Map.delete(&1, viewer_id))
    {:reply, :ok, new_state}
  end

  def handle_call({:handle_tip, tip}, _from, state) do
    new_state = %{state |
      tips: [tip | state.tips],
      rewards_earned: state.rewards_earned + tip.amount
    }
    
    if viewer = get_in(state.viewers, [tip.from]) do
      new_state = update_in(new_state.viewers[tip.from], fn v ->
        %{v | tips_sent: v.tips_sent + tip.amount}
      end)
    end

    {:reply, :ok, new_state}
  end

  def handle_call({:update_stake, stake_info}, _from, state) do
    new_state = %{state |
      stake_amount: stake_info.amount,
      streamer_address: stake_info.address
    }
    {:reply, :ok, new_state}
  end

  def handle_call(:get_stake, _from, state) do
    stake_info = %{
      amount: state.stake_amount,
      address: state.streamer_address
    }
    {:reply, {:ok, stake_info}, state}
  end

  def handle_call(:stop_stream, _from, state) do
    cleanup_stream(state)
    {:stop, :normal, :ok, state}
  end

  # Private Functions
  defp get_token_contract do
    Application.get_env(:live_beats, :token_contract) ||
      raise "Token contract address not configured"
  end

  defp get_rewards_contract do
    Application.get_env(:live_beats, :rewards_contract) ||
      raise "Rewards contract address not configured"
  end

  defp setup_stream(state) do
    case LiveBeats.Streaming.StreamManager.setup_rtmp_stream(state.stream_key, %{
      title: state.title,
      owner_id: state.owner_id
    }) do
      {:ok, stream_info} -> {:ok, stream_info}
      error -> error
    end
  end

  defp cleanup_stream(state) do
    # Cleanup resources
    LiveBeats.Streaming.StreamManager.cleanup_stream(state.stream_key)
    
    # Distribute rewards if any
    if state.rewards_earned > 0 do
      distribute_rewards(state)
    end
  end

  defp distribute_rewards(state) do
    try do
      {:ok, _tx} = Web3.Contract.send(
        state.rewards_contract,
        "distributeRewards",
        [state.streamer_address, state.rewards_earned],
        gas: 200_000
      )
    rescue
      e ->
        Logger.error("Failed to distribute rewards: #{inspect(e)}")
    end
  end

  defp state_to_map(state) do
    Map.from_struct(state)
  end

  defp via_tuple(stream_id) do
    {:via, Registry, {LiveBeats.StreamRegistry, stream_id}}
  end

  defp generate_stream_key(user_id) do
    salt = LiveBeats.Streaming.Config.get_stream_key_salt()
    key = :crypto.strong_rand_bytes(16)
    hash = :crypto.hash(:sha256, "#{key}#{salt}#{user_id}")
    Base.encode16(hash) <> "_" <> to_string(user_id)
  end
end
