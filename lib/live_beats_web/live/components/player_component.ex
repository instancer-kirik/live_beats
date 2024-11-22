defmodule LiveBeatsWeb.PlayerComponent do
  use LiveBeatsWeb, :live_component
  import Phoenix.HTML.Form

  alias Phoenix.LiveView.JS

  alias LiveBeats.Streaming.MediaServer

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      stream_key: nil,
      playing: false,
      current_time: 0,
      duration: 0,
      clip_start: nil,
      clip_end: nil,
      clips: [])}
  end

  @impl true
  def update(%{stream_key: stream_key} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:stream_key, stream_key)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div class="flex-shrink-0">
            <img class="h-8 w-8" src={~p"/images/phoenix.png"} alt="" />
          </div>
          <div>
            <h3 class="text-sm font-medium text-gray-900"><%= @stream_key %></h3>
            <p class="text-sm text-gray-500">
              <%= if @playing, do: "Playing", else: "Stopped" %>
              (<%= format_duration(@current_time) %> / <%= format_duration(@duration) %>)
            </p>
          </div>
        </div>
        <div class="flex items-center space-x-4">
          <%= if @playing do %>
            <button phx-click="stop" phx-target={@myself}>
              <.icon name="hero-stop" />
              Stop
            </button>
          <% else %>
            <button phx-click="play" phx-target={@myself}>
              <.icon name="hero-play" />
              Play
            </button>
          <% end %>
        </div>
      </div>

      <div class="mt-4">
        <div class="relative">
          <div class="overflow-hidden h-2 text-xs flex rounded bg-purple-200">
            <div
              class="shadow-none flex flex-col text-center whitespace-nowrap text-white justify-center bg-purple-500"
              style={"width: #{(@current_time / @duration) * 100}%"}
            >
            </div>
          </div>
        </div>
      </div>

      <div class="mt-4">
        <%= if @clip_start do %>
          <div class="clip-controls">
            <p>Recording clip... (<%= format_duration(@current_time - @clip_start) %>)</p>
            <.form for={%{}} phx-submit="save_clip" phx-target={@myself}>
              <%= text_input :clip, :title, placeholder: "Clip title", required: true, class: "mt-2 block w-full rounded-lg border-zinc-300 text-zinc-900 focus:border-zinc-400 focus:ring-0 sm:text-sm sm:leading-6" %>
              <%= text_input :clip, :description, placeholder: "Description", class: "mt-2 block w-full rounded-lg border-zinc-300 text-zinc-900 focus:border-zinc-400 focus:ring-0 sm:text-sm sm:leading-6" %>
              <.button type="submit">Save Clip</.button>
              <.button type="button" phx-click="cancel_clip" phx-target={@myself}>Cancel</.button>
            </.form>
          </div>
        <% else %>
          <button phx-click="start_clip" phx-target={@myself}>
            <.icon name="hero-video-camera" />
            Start Clip
          </button>
        <% end %>
      </div>

      <div class="mt-4">
        <h4 class="text-sm font-medium text-gray-900">Clips</h4>
        <div class="mt-2 grid grid-cols-1 gap-4 sm:grid-cols-2">
          <%= for clip <- @clips do %>
            <div class="relative rounded-lg border border-gray-300 bg-white px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-gray-400">
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-gray-900">
                  <%= clip.title %>
                </p>
                <p class="text-sm text-gray-500">
                  <%= clip.description %>
                </p>
                <p class="text-sm text-gray-500">
                  <%= format_duration(clip.start_time) %> - <%= format_duration(clip.end_time) %>
                </p>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_duration(nil), do: "00:00"
  defp format_duration(seconds) when is_float(seconds), do: format_duration(trunc(seconds))
  defp format_duration(seconds) when seconds < 0, do: "00:00"
  defp format_duration(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [minutes, remaining_seconds])
  end

  @impl true
  def handle_event("play", _, socket) do
    MediaServer.play(socket.assigns.stream_key)
    {:noreply, assign(socket, playing: true)}
  end

  def handle_event("stop", _, socket) do
    MediaServer.stop(socket.assigns.stream_key)
    {:noreply, assign(socket, playing: false)}
  end

  def handle_event("start_clip", _, socket) do
    {:noreply, assign(socket, clip_start: socket.assigns.current_time)}
  end

  def handle_event("cancel_clip", _, socket) do
    {:noreply, assign(socket, clip_start: nil)}
  end

  def handle_event("save_clip", %{"clip" => %{"title" => title, "description" => description}}, socket) do
    clip = %{
      title: title,
      description: description,
      start_time: socket.assigns.clip_start,
      end_time: socket.assigns.current_time
    }

    {:noreply,
     socket
     |> update(:clips, &[clip | &1])
     |> assign(clip_start: nil)}
  end
end
