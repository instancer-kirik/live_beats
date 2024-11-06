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
    {:noreply, refresh_streams(state)}
  end

  @impl true
  def handle_info(:refresh, state) do
    schedule_refresh()
    {:noreply, refresh_streams(state)}
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

    broadcast_updates(streams)

    %State{state |
      cached_streams: streams,
      last_refresh: DateTime.utc_now()
    }
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp broadcast_updates(streams) do
    Phoenix.PubSub.broadcast(
      LiveBeats.PubSub,
      "external_streams",
      {:external_streams_updated, streams}
    )
  end
end
