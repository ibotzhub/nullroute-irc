#!/bin/bash
# Complete VPS setup script for hybrid architecture
# Run on VPS: sudo bash infra/setup-vps.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_DIR="/var/www/nullroute-irc"
APP_DIR="$PROJECT_DIR"

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

check_root

print_status "Setting up hybrid architecture on VPS..."

# 1. Install Redis if needed
if ! command -v redis-server &> /dev/null; then
    print_status "Installing Redis..."
    apt update
    apt install -y redis-server
    systemctl enable redis-server
    systemctl start redis-server
else
    print_status "Redis already installed"
fi

# 2. Install Elixir/Phoenix if needed
if ! command -v mix &> /dev/null; then
    print_warning "Elixir not found. Installing..."
    apt install -y erlang elixir
    mix local.hex --force
    mix local.rebar --force
    mix archive.install hex phx_new 1.7.0 --force
else
    print_status "Elixir already installed"
    # Ensure rebar3 is available
    mix local.rebar --force 2>/dev/null || true
    # Check Elixir version - Phoenix 1.7 needs Elixir 1.15+
    ELIXIR_VERSION=$(mix --version | head -1 | awk '{print $2}' | cut -d. -f1,2)
    if [ "$(printf '%s\n' "1.15" "$ELIXIR_VERSION" | sort -V | head -n1)" != "1.15" ]; then
        print_warning "Elixir $ELIXIR_VERSION detected, but Phoenix 1.7 requires 1.15+. Continuing anyway..."
    fi
fi

# 3. Install Postgres if needed
if ! command -v psql &> /dev/null; then
    print_status "Installing Postgres..."
    apt install -y postgresql postgresql-contrib
    systemctl enable postgresql
    systemctl start postgresql
    
    # Create database user
    sudo -u postgres psql -c "CREATE USER nullroute WITH PASSWORD 'changeme';" || true
    sudo -u postgres psql -c "CREATE DATABASE nullroute_irc_prod OWNER nullroute;" || true
else
    print_status "Postgres already installed"
fi

# 3.5. Install Go if needed
if ! command -v go &> /dev/null; then
    print_status "Installing Go..."
    apt update
    apt install -y golang-go
else
    print_status "Go already installed"
fi

# 3.6. Install Node.js if needed
if ! command -v node &> /dev/null; then
    print_status "Installing Node.js..."
    apt update
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
else
    print_status "Node.js already installed"
fi

# 4. Build Go Gateway
print_status "Building Go gateway..."
cd "$APP_DIR/gateway"
go mod download
go build -o gateway ./cmd/gateway
chmod +x gateway
print_status "Gateway built"

# 5. Setup Phoenix App
print_status "Setting up Phoenix app..."
cd "$APP_DIR/app"
# Ensure rebar3 is available before deps.get
mix local.rebar --force 2>/dev/null || true
mix deps.get
# Use production environment for database setup
export DATABASE_URL="postgresql://nullroute:changeme@localhost/nullroute_irc_prod"
export SECRET_KEY_BASE=$(mix phx.gen.secret)
MIX_ENV=prod mix ecto.create || print_warning "Database might already exist"
MIX_ENV=prod mix ecto.migrate
print_status "Phoenix app ready"

# 6. Build React UI
print_status "Building React UI..."
cd "$APP_DIR/ui"
npm install
npm run build
mkdir -p ../app/priv/static
cp -r dist/* ../app/priv/static/
print_status "React UI built and copied"

# 7. Create systemd services
print_status "Creating systemd services..."

# Gateway service
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

# Phoenix service
SECRET_KEY=$(cd "$APP_DIR/app" && mix phx.gen.secret)
# Create www-data home directory and install Hex/rebar
mkdir -p /var/www/.mix/archives
chown -R www-data:www-data /var/www/.mix
sudo -u www-data bash -c "cd $APP_DIR/app && mix local.hex --force"
sudo -u www-data bash -c "cd $APP_DIR/app && mix local.rebar --force"
cat > /etc/systemd/system/nullroute-app.service <<EOF
[Unit]
Description=NullRoute IRC App (Phoenix)
After=network.target redis.service postgresql.service

[Service]
Type=simple
User=www-data
WorkingDirectory=$APP_DIR/app
ExecStart=/bin/bash -c 'export PATH=\$PATH:/usr/local/bin && /usr/bin/mix phx.server'
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=MIX_ENV=prod
Environment=PORT=4000
Environment=SECRET_KEY_BASE=$SECRET_KEY
Environment=REDIS_HOST=localhost
Environment=REDIS_PORT=6379
Environment=DATABASE_URL=postgresql://nullroute:changeme@localhost/nullroute_irc_prod
Environment=PHX_HOST=irc.example.com

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable nullroute-gateway nullroute-app

# 8. Set permissions
chown -R www-data:www-data "$APP_DIR"

print_status "Setup complete!"
print_info "Start services:"
echo "  sudo systemctl start nullroute-gateway"
echo "  sudo systemctl start nullroute-app"
echo ""
print_info "Check status:"
echo "  sudo systemctl status nullroute-gateway"
echo "  sudo systemctl status nullroute-app"
echo ""
print_warning "Next: Configure Apache with infra/apache/nullroute-irc-hybrid.conf"
