import Config

config :app, ecto_repos: [App.Repo]

config :app, App.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "nullroute_irc_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :app, AppWeb.Endpoint,
  url: [host: "localhost", port: 4000],
  http: [ip: {127, 0, 0, 1}, port: 4000],
  pubsub_server: App.PubSub,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "change-this-secret-key-in-production-use-mix-phx-gen-secret",
  live_view: [signing_salt: "change-this-too"]

config :app, AppWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/app_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :redix,
  host: "localhost",
  port: 6379,
  database: 0

import_config "#{config_env()}.exs"
