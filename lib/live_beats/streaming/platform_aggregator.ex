defmodule LiveBeats.Streaming.PlatformAggregator do
  use GenServer
  require Logger

  @platforms [:dlive, :theta, :twitch, :kick, :youtube]
  @refresh_interval :timer.minutes(1)

  defmodule State do
    defstruct platforms: %{},
              cached_streams: %{},
              last_refresh: nil
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %State{
      platforms: %{
        dlive: LiveBeats.Streaming.Platforms.DLive,
        theta: LiveBeats.Streaming.Platforms.Theta,
        twitch: LiveBeats.Streaming.Platforms.Twitch,
        kick: LiveBeats.Streaming.Platforms.Kick,
        youtube: LiveBeats.Streaming.Platforms.YouTube
      }
    }

    {:ok, state, {:continue, :initial_fetch}}
  end

  @impl true
  def handle_continue(:initial_fetch, state) do
    schedule_refresh()
    {:noreply, refresh_streams(state)}
  end

  @impl true
  def handle_info(:refresh, state) do
    schedule_refresh()
    {:noreply, refresh_streams(state)}
  end

  def get_streams(platform) do
    GenServer.call(__MODULE__, {:get_streams, platform})
  end

  def get_all_streams do
    GenServer.call(__MODULE__, :get_all_streams)
  end

  @impl true
  def handle_call({:get_streams, platform}, _from, state) do
    case Map.fetch(state.cached_streams, platform) do
      {:ok, streams} -> {:reply, {:ok, streams}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:get_all_streams, _from, state) do
    {:reply, {:ok, state.cached_streams}, state}
  end

  defp refresh_streams(state) do
    streams = Enum.reduce(@platforms, %{}, fn platform, acc ->
      case fetch_platform_streams(platform, state.platforms) do
        {:ok, platform_streams} ->
          Map.put(acc, platform, platform_streams)
        {:error, reason} ->
          Logger.error("Failed to fetch #{platform} streams: #{inspect(reason)}")
          acc
      end
    end)

    %{state |
      cached_streams: streams,
      last_refresh: DateTime.utc_now()
    }
  end

  defp fetch_platform_streams(platform, platforms) do
    case Map.fetch(platforms, platform) do
      {:ok, module} ->
        try do
          module.fetch_streams()
        rescue
          e ->
            Logger.error("Error fetching streams from #{platform}: #{inspect(e)}")
            {:error, :fetch_failed}
        end
      :error ->
        {:error, :platform_not_found}
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
end
