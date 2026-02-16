# Phoenix App (Elixir)

Main application layer handling accounts, admin, overlay features (reactions, pins, search), and WebSocket connections to browsers.

## Setup

Requires Elixir 1.14+ and Erlang/OTP 25+.

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
mix phx.server
```

## Architecture

- **WebSocket**: Phoenix Channels (`/socket`) for browser connections
- **Redis**: Pub/Sub bridge to Go gateway (`commands:<userId>`, `events:<userId>`)
- **Database**: Postgres (or SQLite) for accounts, settings, overlay features

## Environment Variables

- `DATABASE_URL` - Postgres connection string
- `SECRET_KEY_BASE` - Phoenix secret (generate with `mix phx.gen.secret`)
- `REDIS_HOST` (default: `localhost`)
- `REDIS_PORT` (default: `6379`)
- `PORT` (default: `4000`)

## Development

```bash
mix phx.server
```

Frontend React build should be copied to `priv/static/` after building.
