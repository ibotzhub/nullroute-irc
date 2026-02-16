import Config

config :app, App.Repo,
  username: System.get_env("DATABASE_USER", "postgres"),
  password: System.get_env("DATABASE_PASS", "postgres"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  database: System.get_env("DATABASE_NAME", "nullroute_irc_prod"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

config :app, AppWeb.Endpoint,
  pubsub_server: App.PubSub,
  watchers: [],
  http: [
    ip: {0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT", "4000")),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  check_origin: false

config :app, AppWeb.Endpoint, server: true

config :logger, level: :info

config :redix,
  host: System.get_env("REDIS_HOST", "localhost"),
  port: String.to_integer(System.get_env("REDIS_PORT", "6379")),
  database: 0
