defmodule AppWeb.Router do
  use AppWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug AppWeb.RateLimit
    plug :fetch_session
  end

  pipeline :health do
    plug :accepts, ["json", "html"]
  end

  # For serving uploaded files - accept any content type
  pipeline :uploads do
    plug :fetch_session
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/api", AppWeb do
    pipe_through :health
    get "/health", PageController, :health

    pipe_through :api
    post "/auth/login", AuthController, :login
    post "/auth/register", AuthController, :register
    post "/auth/logout", AuthController, :logout
    get "/auth/me", AuthController, :me
    get "/auth/socket_token", AuthController, :socket_token

    # User settings (theme only)
    get "/user/settings", UserSettingsController, :get_settings
    put "/user/settings", UserSettingsController, :update_settings

    # User profiles
    get "/profile/:id", ProfileController, :show
    put "/profile", ProfileController, :update

    # Messages endpoints (specific routes before :id to avoid wrong matches)
    get "/messages", MessagesController, :index
    get "/messages/channel/:channel/pinned", MessagesController, :pinned
    get "/messages/channel/:channel/search", MessagesController, :search
    post "/messages/:message_id/reactions", MessagesController, :add_reaction
    delete "/messages/:message_id/reactions", MessagesController, :remove_reaction
    get "/messages/:id", MessagesController, :show
    put "/messages/:id", MessagesController, :update
    delete "/messages/:id", MessagesController, :delete
    post "/messages/:id/pin", MessagesController, :pin
    post "/messages/:id/unpin", MessagesController, :unpin

    # File upload
    post "/upload", UploadController, :upload

    # IRC commands endpoints
    get "/irc/ignore", IRCCommandsController, :ignore_list
    get "/irc/channel/:channel/operators", IRCCommandsController, :channel_operators
    get "/irc/channel/:channel/modes", IRCCommandsController, :channel_modes
    get "/irc/who/:nick", IRCCommandsController, :who

    # Admin endpoints (require admin role)
    get "/admin/settings", AdminController, :settings
    put "/admin/settings", AdminController, :update_settings
    get "/admin/users", AdminController, :users
    post "/admin/users/:id/admin", AdminController, :set_admin
    post "/admin/users/:id/master_admin", AdminController, :set_master_admin
    post "/admin/users/:id/approve", AdminController, :approve_user

    # Role management endpoints
    get "/admin/roles", RolesController, :index
    post "/admin/roles", RolesController, :create
    put "/admin/roles/:id", RolesController, :update
    delete "/admin/roles/:id", RolesController, :delete
    post "/admin/roles/assign", RolesController, :assign_role
    post "/admin/roles/remove", RolesController, :remove_role
  end

  # Static file serving for uploads (no auth required - URLs are shareable)
  scope "/uploads", AppWeb do
    pipe_through :uploads
    get "/*path", PageController, :static_file
  end

  scope "/", AppWeb do
    pipe_through :browser

    get "/*path", PageController, :index
  end

  if Application.compile_env(:app, :dev_routes, false) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: AppWeb.Telemetry
    end
  end
end
