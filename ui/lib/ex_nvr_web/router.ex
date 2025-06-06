defmodule ExNVRWeb.Router do
  use ExNVRWeb, :router

  import ExNVRWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {ExNVRWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json", "jpg", "mp4"]
    plug :fetch_session
    plug :fetch_current_user
  end

  pipeline :api_require_authenticated_user do
    plug :require_authenticated_user, api: true
  end

  pipeline :reverse_proxy do
    plug ExNVRWeb.Plug.ProxyAllow
    plug ExNVRWeb.Plug.ProxyPathRewriter
  end

  scope "/api", ExNVRWeb do
    pipe_through [:api, :require_webhook_token, ExNVRWeb.Plug.Device]

    post "/devices/:device_id/events", API.EventController, :create
    post "/devices/:device_id/events/lpr", API.EventController, :create_lpr
  end

  scope "/api", ExNVRWeb do
    pipe_through [:api, :api_require_authenticated_user]

    resources "/users", API.UserController, except: [:new, :edit]

    resources "/remote-storages", API.RemoteStorageController, except: [:new, :edit]

    resources "/devices", API.DeviceController, except: [:new, :edit]

    get "/events", API.EventController, :events
    get "/events/lpr", API.EventController, :lpr

    get "/recordings/chunks", API.RecordingController, :chunks

    post "/onvif/discover", API.OnvifController, :discover
    get "/onvif/discover", API.OnvifController, :discover

    scope "/devices/:device_id" do
      pipe_through ExNVRWeb.Plug.Device

      get "/recordings", API.RecordingController, :index
      get "/recordings/:recording_id/blob", API.RecordingController, :blob

      get "/hls/index.m3u8", API.DeviceStreamingController, :hls_stream

      get "/snapshot", API.DeviceStreamingController, :snapshot
      get "/footage", API.DeviceStreamingController, :footage

      get "/bif/:hour", API.DeviceStreamingController, :bif
    end

    get "/system/status", API.SystemStatusController, :status
  end

  scope "/api", ExNVRWeb do
    pipe_through :api

    post "/users/login", API.UserSessionController, :login

    scope "/devices/:device_id" do
      pipe_through ExNVRWeb.Plug.Device

      get "/hls/:segment_name", API.DeviceStreamingController, :hls_stream_segment
    end
  end

  if Application.compile_env(:ex_nvr, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ExNVRWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{ExNVRWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/login", UserLoginLive, :new
      live "/users/register", UserRegistrationLive, :new
      live "/users/reset-password", UserForgotPasswordLive, :new
      live "/users/reset-password/:token", UserResetPasswordLive, :edit
    end

    post "/users/login", UserSessionController, :create
  end

  scope "/" do
    pipe_through [:browser, :require_authenticated_user]

    get "/", ExNVRWeb.PageController, :home
    get "/webrtc/:device_id", ExNVRWeb.PageController, :webrtc

    import Phoenix.LiveDashboard.Router
    live_dashboard "/live-dashboard", metrics: ExNVRWeb.Telemetry

    live_session :require_authenticated_user,
      on_mount: [
        {ExNVRWeb.UserAuth, :ensure_authenticated},
        {ExNVRWeb.Navigation, :attach_hook}
      ] do
      live "/dashboard", ExNVRWeb.DashboardLive, :new

      live "/devices", ExNVRWeb.DeviceListLive, :list

      live "/recordings", ExNVRWeb.RecordingListLive, :list
      live "/events/generic", ExNVRWeb.GenericEventsLive, :index
      live "/events/lpr", ExNVRWeb.LPREventsListLive, :list

      live "/users/settings", ExNVRWeb.UserSettingsLive, :edit
      live "/users/settings/confirm-email/:token", ExNVRWeb.UserSettingsLive, :confirm_email

      IO.inspect(ExNVRWeb.PluginRegistry.routes())
      for {path, view, action} <- ExNVRWeb.PluginRegistry.routes() do
        IO.inspect(path, label: "Plugin path:")
        IO.inspect(view, label: "Plugin view")
        IO.inspect(action, label: "Plugin action")
        live path, view, action
      end
    end
  end

  scope "/", ExNVRWeb do
    pipe_through [:browser]

    delete "/users/logout", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{ExNVRWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope "/", ExNVRWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin_user]

    live_session :require_admin_user,
      on_mount: [
        {ExNVRWeb.UserAuth, :ensure_authenticated},
        {ExNVRWeb.UserAuth, :ensure_user_is_admin},
        {ExNVRWeb.Navigation, :attach_hook}
      ] do
      live "/devices/:id", DeviceLive, :edit

      live "/remote-storages", RemoteStorageListLive, :list
      live "/remote-storages/:id", RemoteStorageLive, :edit

      live "/onvif-discovery", OnvifDiscoveryLive, :onvif_discovery

      live "/users", UserListLive, :list
      live "/users/:id", UserLive, :edit
    end
  end

  scope "/service" do
    pipe_through [:reverse_proxy]

    forward "/", ReverseProxyPlug,
      upstream: &ExNVRWeb.ReverseProxy.reverse_proxy/1,
      error_callback: &ExNVRWeb.ReverseProxy.handle_error/2,
      preserve_host_header: true
  end
end
