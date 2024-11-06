defmodule LiveBeats.Streaming.Platforms.DLive do
  @behaviour LiveBeats.Streaming.PlatformBehaviour

  @impl true
  def fetch_streams do
    # DLive API endpoint
    url = "https://api.dlive.tv/v1/live/recommend"

    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        streams = body
        |> Jason.decode!()
        |> Map.get("data")
        |> Enum.map(&format_stream/1)

        {:ok, streams}

      error ->
        {:error, "Failed to fetch DLive streams: #{inspect(error)}"}
    end
  end

  defp format_stream(stream) do
    %{
      id: stream["id"],
      platform: :dlive,
      title: stream["title"],
      streamer: stream["displayName"],
      viewer_count: stream["watchingCount"],
      thumbnail: stream["thumbnailUrl"],
      url: "https://dlive.tv/#{stream["username"]}",
      category: stream["category"],
      started_at: DateTime.from_unix!(stream["startedAt"])
    }
  end
end
