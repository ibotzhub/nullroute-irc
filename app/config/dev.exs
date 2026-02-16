import Config

config :app, App.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "nullroute_irc_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :app, AppWeb.Endpoint,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

config :logger, :console, format: "[$level] $message\n"
