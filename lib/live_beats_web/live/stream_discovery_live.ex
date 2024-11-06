defmodule LiveBeatsWeb.StreamDiscoveryLive do
  use LiveBeatsWeb, :live_view
  alias LiveBeats.Streaming

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveBeats.PubSub, "stream_discovery")
      Phoenix.PubSub.subscribe(LiveBeats.PubSub, "external_streams")
      Phoenix.PubSub.subscribe(LiveBeats.PubSub, "stream_metrics")
    end

    {:ok,
     assign(socket,
       page_title: "Discover Streams",
       discovered_streams: Streaming.list_active_streams(),
       external_streams: %{},
       promoted_streams: Streaming.list_promoted_streams(),
       categories: Streaming.list_categories(),
       selected_category: nil,
       selected_platforms: [:all],
       sort_by: :viewers,
       network_stats: %{
         peer_count: 0,
         total_streams: 0,
         total_viewers: 0,
         platform_streams: %{}
       }
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> apply_filters(params)}
  end

  @impl true
  def handle_event("filter", %{"category" => category}, socket) do
    {:noreply,
     push_patch(socket,
       to: Routes.stream_discovery_path(socket, :index, category: category)
     )}
  end

  @impl true
  def handle_event("sort", %{"by" => sort_by}, socket) do
    {:noreply,
     socket
     |> assign(:sort_by, String.to_atom(sort_by))
     |> sort_streams()}
  end

  @impl true
  def handle_info({:streams_updated, streams}, socket) do
    {:noreply,
     socket
     |> assign(:discovered_streams, streams)
     |> apply_current_filters()
     |> update_network_stats()}
  end

  @impl true
  def handle_info({:network_stats, stats}, socket) do
    {:noreply, assign(socket, :network_stats, stats)}
  end

  @impl true
  def handle_info({:external_streams_updated, streams}, socket) do
    {:noreply,
     socket
     |> assign(:external_streams, streams)
     |> apply_current_filters()
     |> update_network_stats()}
  end

  defp apply_filters(socket, %{"category" => category}) do
    socket
    |> assign(:selected_category, category)
    |> filter_streams()
    |> sort_streams()
  end

  defp apply_filters(socket, %{"platform" => platform} = params) do
    socket
    |> assign(:selected_platforms, [String.to_atom(platform)])
    |> apply_filters(Map.delete(params, "platform"))
  end

  defp apply_filters(socket, _params), do: socket

  defp filter_streams(%{assigns: %{selected_category: nil}} = socket), do: socket
  defp filter_streams(%{assigns: %{selected_category: category}} = socket) do
    filtered = Enum.filter(socket.assigns.discovered_streams, & &1.category == category)
    assign(socket, :discovered_streams, filtered)
  end

  defp filter_streams(%{assigns: %{selected_platforms: [:all]}} = socket), do: socket
  defp filter_streams(%{assigns: %{selected_platforms: platforms}} = socket) do
    filtered = socket.assigns.external_streams
    |> Enum.filter(fn {platform, _} -> platform in platforms end)
    |> Enum.flat_map(fn {_, streams} -> streams end)

    assign(socket, :discovered_streams, filtered)
  end

  defp sort_streams(%{assigns: %{sort_by: :viewers}} = socket) do
    sorted = Enum.sort_by(socket.assigns.discovered_streams, & &1.viewer_count, :desc)
    assign(socket, :discovered_streams, sorted)
  end
  defp sort_streams(%{assigns: %{sort_by: :staked}} = socket) do
    sorted = Enum.sort_by(socket.assigns.discovered_streams, & &1.stake_amount, :desc)
    assign(socket, :discovered_streams, sorted)
  end

  defp apply_current_filters(socket) do
    socket
    |> filter_streams()
    |> sort_streams()
  end

  defp update_network_stats(socket) do
    stats = %{
      peer_count: length(LiveBeats.Streaming.DiscoveryNode.get_peers()),
      total_streams: length(socket.assigns.discovered_streams),
      total_viewers: Enum.sum(Enum.map(socket.assigns.discovered_streams, & &1.viewer_count))
    }
    assign(socket, :network_stats, stats)
  end
end
