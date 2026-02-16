defmodule AppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :app

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug AppWeb.SecurityHeaders

  plug Plug.Static,
    at: "/",
    from: :app,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session,
    store: :cookie,
    key: "_app_key",
    signing_salt: "change-this-too",
    max_age: 604_800,  # 7 days
    http_only: true,
    secure: Application.compile_env(:app, :force_ssl, false),
    same_site: "Lax"

  socket "/socket", AppWeb.UserSocket,
    websocket: [connect_info: [{:session, [store: :cookie, key: "_app_key", signing_salt: "change-this-too"]}]],
    longpoll: true,
    check_origin: false

  plug AppWeb.Router
end
