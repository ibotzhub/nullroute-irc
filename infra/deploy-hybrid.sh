#!/bin/bash
# Deploy hybrid architecture (Phoenix + Go Gateway + Redis)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="${APP_DIR:-$PROJECT_DIR}"

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root (use sudo)"
        exit 1
    fi
}

install_redis() {
    if ! command -v redis-server &> /dev/null; then
        print_status "Installing Redis..."
        apt update
        apt install -y redis-server
        systemctl enable redis-server
        systemctl start redis-server
    fi
}

build_gateway() {
    print_status "Building Go gateway..."
    cd "$APP_DIR/gateway"
    go mod download
    go build -o gateway ./cmd/gateway
    chmod +x gateway
    print_status "Gateway built"
}

setup_gateway_service() {
    print_status "Creating gateway systemd service..."
    cat > /etc/systemd/system/nullroute-gateway.service <<EOF
[Unit]
Description=NullRoute IRC Gateway (Go)
After=network.target redis.service

[Service]
Type=simple
User=www-data
WorkingDirectory=$APP_DIR/gateway
ExecStart=$APP_DIR/gateway/gateway
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=REDIS_ADDR=localhost:6379
Environment=IRC_HOST=irc.example.com
Environment=IRC_PORT=6697
Environment=IRC_TLS=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable nullroute-gateway
    print_status "Gateway service created"
}

setup_phoenix_service() {
    print_status "Creating Phoenix systemd service..."
    cat > /etc/systemd/system/nullroute-app.service <<EOF
[Unit]
Description=NullRoute IRC App (Phoenix)
After=network.target redis.service postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=$APP_DIR/app
ExecStart=/usr/local/bin/mix phx.server
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=MIX_ENV=prod
Environment=PORT=4000
Environment=SECRET_KEY_BASE=\$(mix phx.gen.secret)
Environment=REDIS_HOST=localhost
Environment=REDIS_PORT=6379

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable nullroute-app
    print_status "Phoenix service created"
}

print_status "Hybrid deployment setup complete!"
print_warning "Next steps:"
echo "  1. Install Elixir/Phoenix on VPS"
echo "  2. cd $APP_DIR/app && mix deps.get && mix ecto.setup"
echo "  3. Build React UI: cd $APP_DIR/ui && npm install && npm run build"
echo "  4. Copy ui/dist/* to app/priv/static/"
echo "  5. Configure Apache with infra/apache/nullroute-irc-hybrid.conf"
echo "  6. Start services: sudo systemctl start nullroute-gateway nullroute-app"
