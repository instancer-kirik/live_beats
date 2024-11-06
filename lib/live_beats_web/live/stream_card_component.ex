defmodule LiveBeatsWeb.StreamCardComponent do
  use LiveBeatsWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class={"relative rounded-lg overflow-hidden shadow-md #{if @promoted, do: "border-2 border-yellow-400"}"}>
      <div class="aspect-w-16 aspect-h-9 bg-gray-200">
        <img src={@stream.thumbnail_url} alt="" class="object-cover"/>
        <div class="absolute top-2 right-2 px-2 py-1 bg-red-600 text-white rounded-md text-sm">
          LIVE
        </div>
      </div>

      <div class="p-4">
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-medium truncate"><%= @stream.title %></h3>
          <span class="text-sm text-gray-500">
            <%= @stream.viewer_count %> viewers
          </span>
        </div>

        <div class="mt-2 flex items-center text-sm text-gray-500">
          <span class="truncate"><%= @stream.category %></span>
          <span class="mx-2">•</span>
          <span><%= @stream.stake_amount %> STRM staked</span>
        </div>

        <div class="mt-4">
          <%= live_redirect "Watch Stream", to: Routes.stream_path(@socket, :show, @stream.id), class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700" %>
        </div>
      </div>
    </div>
    """
  end
end
