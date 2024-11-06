defmodule LiveBeats.Streaming.Platforms.Theta do
  @behaviour LiveBeats.Streaming.PlatformBehaviour

  @impl true
  def fetch_streams do
    url = "https://api.theta.tv/v1/live_streams"

    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        streams = body
        |> Jason.decode!()
        |> Map.get("body")
        |> Enum.map(&format_stream/1)

        {:ok, streams}

      error ->
        {:error, "Failed to fetch Theta streams: #{inspect(error)}"}
    end
  end

  defp format_stream(stream) do
    %{
      id: stream["id"],
      platform: :theta,
      title: stream["title"],
      streamer: stream["user"]["username"],
      viewer_count: stream["concurrent_viewers"],
      thumbnail: stream["thumbnail"],
      url: "https://theta.tv/#{stream["user"]["username"]}",
      category: stream["category"],
      started_at: DateTime.from_iso8601!(stream["started_at"])
    }
  end
end
