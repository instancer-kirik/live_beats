defmodule LiveBeatsWeb.Router do
  use LiveBeatsWeb, :router
  import LiveBeatsWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LiveBeatsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Set up authentication pipelines
  pipeline :authenticate_user do
    plug :require_authenticated_user
  end

  pipeline :redirect_if_authenticated do
    plug :redirect_if_user_is_authenticated
  end

  scope "/deats" do
    pipe_through [:browser, :redirect_if_authenticated]

    live "/", LiveBeatsWeb.HomeLive, :index
    live "/profile/settings", LiveBeatsWeb.UserSettingsLive, :edit
    live "/:username", LiveBeatsWeb.ProfileLive, :show
    live "/:username/songs/:id", LiveBeatsWeb.SongLive, :show
  end

  scope "/deats" do
    pipe_through [:browser, :authenticate_user]

    # Add authenticated routes here
  end

  scope "/deats" do
    pipe_through :browser

    # Add public routes here
  end

  # OAuth routes
  scope "/auth", LiveBeatsWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :delete
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:live_beats, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LiveBeatsWeb.Telemetry
    end
  end
end
