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
      {:ok, stream_data} ->
        new_state = %State{state |
          stream_key: stream_data.stream_key,
          playback_url: stream_data.playback_url,
          rtmp_url: stream_data.rtmp_url,
          status: :ready,
          recording_path: stream_data.recording_path
        }

        # Broadcast stream ready event
        Phoenix.PubSub.broadcast(
          LiveBeats.PubSub,
          "streams",
          {:stream_ready, new_state}
        )

        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to create stream: #{inspect(reason)}")
        cleanup_stream(state)
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_call(:get_stream, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:add_viewer, viewer_id}, _from, state) do
    if Map.has_key?(state.viewers, viewer_id) do
      {:reply, {:error, :already_viewing}, state}
    else
      new_state = %State{state |
        viewers: Map.put(state.viewers, viewer_id, %{
          joined_at: DateTime.utc_now()
        })
      }
      broadcast_viewer_count(new_state)
      {:reply, :ok, new_state}
    end
  end

  def handle_call({:remove_viewer, viewer_id}, _from, state) do
    new_state = %State{state |
      viewers: Map.delete(state.viewers, viewer_id)
    }
    broadcast_viewer_count(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call(:stop_stream, _from, state) do
    cleanup_stream(state)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_call({:handle_tip, tip}, _from, state) do
    new_state = %State{state |
      tips: [tip | state.tips],
      rewards_earned: calculate_rewards(state.tips)
    }

    broadcast_tip_event(new_state, tip)
    {:reply, :ok, new_state}
  end

  # Private Functions
  defp via_tuple(stream_id) do
    {:via, Registry, {LiveBeats.Streaming.Registry, stream_id}}
  end

  defp setup_stream(state) do
    LiveBeats.Streaming.TranscodingManager.create_stream(state.id, %{
      name: "stream_#{state.id}",
      profiles: ["720p", "480p", "360p"],
      recording: true
    })
  end

  defp cleanup_stream(state) do
    # Stop transcoding
    LiveBeats.Streaming.TranscodingManager.stop_stream(state.id)

    # Save recording if enabled
    if state.recording_path do
      save_recording(state)
    end

    # Notify viewers
    Phoenix.PubSub.broadcast(
      LiveBeats.PubSub,
      "stream:#{state.id}",
      {:stream_ended, state.id}
    )
  end

  defp broadcast_viewer_count(state) do
    Phoenix.PubSub.broadcast(
      LiveBeats.PubSub,
      "stream:#{state.id}",
      {:viewer_count_updated, state.id, map_size(state.viewers)}
    )
  end

  def generate_stream_key(user_id) do
    salt = LiveBeats.Streaming.Config.get_stream_key_salt()
    key = :crypto.strong_rand_bytes(16)
    hash = :crypto.hash(:sha256, "#{key}#{salt}#{user_id}")
    Base.encode16(hash) <> "_" <> to_string(user_id)
  end

  def validate_stream_key(stream_key) do
    case String.split(stream_key, "_") do
      [key, user_id] when byte_size(key) == 64 ->
        case LiveBeats.Accounts.get_user(user_id) do
          nil -> {:error, :invalid_user}
          user -> {:ok, user}
        end
      _ -> {:error, :invalid_format}
    end
  end

  defp save_recording(state) do
    recording_filename = "stream_#{state.id}_#{DateTime.to_unix(state.started_at)}.mp4"
    recording_path = Path.join([state.recording_path, recording_filename])

    # Save recording metadata to database
    {:ok, _recording} = LiveBeats.Content.create_recording(%{
      stream_id: state.id,
      owner_id: state.owner_id,
      title: state.title,
      path: recording_path,
      duration: DateTime.diff(DateTime.utc_now(), state.started_at)
    })
  end

  defp calculate_rewards(tips) do
    # Implement your rewards calculation logic here
    # For example, you can use a simple sum of tips
    Enum.sum(tips)
  end

  defp broadcast_tip_event(state, tip) do
    # Implement your broadcast logic here
    # For example, you can broadcast a tip event to the stream
    Phoenix.PubSub.broadcast(
      LiveBeats.PubSub,
      "stream:#{state.id}",
      {:tip_received, state.id, tip}
    )
  end
end
