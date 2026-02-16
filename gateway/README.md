# IRC Gateway (Go)

Microservice that manages IRC connections and communicates with Phoenix app via Redis Pub/Sub.

## Architecture

- Subscribes to Redis channels: `commands:<userId>`
- Publishes IRC events to: `events:<userId>`
- One IRC connection per user session

## Build

```bash
go mod download
go build -o gateway ./cmd/gateway
```

## Run

```bash
./gateway
```

Requires Redis running on `localhost:6379`.

## Environment Variables

- `REDIS_ADDR` (default: `localhost:6379`)
- `IRC_HOST` (default: `irc.example.com`)
- `IRC_PORT` (default: `6697`)
- `IRC_TLS` (default: `true`)

## Redis Message Format

### Commands (Phoenix → Gateway)

```json
{
  "type": "join",
  "data": {"channel": "#lobby"}
}
```

### Events (Gateway → Phoenix)

```json
{
  "type": "irc:message",
  "data": {
    "nick": "alice",
    "target": "#lobby",
    "message": "hello",
    "time": "2026-02-14T10:00:00Z"
  },
  "user_id": 42
}
```
