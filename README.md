# NullRoute IRC

A web-based IRC client built with Phoenix (Elixir), React, and a Go IRC gateway. Connect to any IRC network through your browser.

## Architecture

- **Phoenix** – Web app, WebSocket channels, auth, API
- **React** – Frontend UI
- **Go gateway** – IRC protocol bridge (one connection per user)
- **Redis** – Pub/Sub between Phoenix and the gateway

## Quick Start (Development)

```bash
# Prerequisites: Elixir, Node.js, Go, PostgreSQL, Redis

# Backend
cd app && mix deps.get && mix ecto.setup && mix phx.server

# Frontend (separate terminal)
cd ui && npm install && npm run dev

# Gateway (separate terminal)
cd gateway && go build -o gateway ./cmd/gateway && ./gateway
```

Visit http://localhost:5173 (Vite proxies /socket and /api to Phoenix).

## Deployment

1. **Copy config templates:**
   ```bash
   cp .env.deploy.example .env.deploy
   ```

2. **Edit `.env.deploy`** with your VPS details:
   - `VPS_HOST` – Your server hostname or IP
   - `VPS_USER` – SSH user (e.g. `deploy`)
   - `VPS_PASSWORD` – SSH password (optional if using keys)
   - `VPS_APP_DIR` – Install path (default `/var/www/nullroute-irc`)

3. **Edit infra configs** before deploy:
   - `infra/nullroute-app.service` – `DATABASE_URL`, `PHX_HOST`
   - `infra/nullroute-gateway.service` – `IRC_HOST`, `IRC_PORT` (your IRC server)
   - `infra/apache/*.conf` – Replace `example.com` with your domain

4. **On the VPS** (one-time setup):
   - PostgreSQL, Redis, Node.js, Go, Elixir
   - Apache with mod_proxy, mod_proxy_wstunnel, mod_ssl
   - Certbot for SSL: `certbot --apache -d irc.yourdomain.com`

5. **Deploy:**
   ```bash
   ./deploy-new-features.sh
   ```

## Configuration

| Variable | Description |
|----------|-------------|
| `IRC_HOST` | IRC server hostname (e.g. `irc.libera.chat`) |
| `IRC_PORT` | IRC port (6697 for TLS) |
| `IRC_TLS` | `true` or `false` |
| `IRC_INSECURE_SKIP_VERIFY` | Set to `true` if IRC server cert doesn't match hostname |
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Phoenix secret (generate with `mix phx.gen.secret`) |

## License

MIT
