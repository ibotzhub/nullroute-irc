#!/bin/bash
# Deploy NullRoute IRC to VPS
# Usage: ./deploy-new-features.sh
#
# REQUIRED: Create .env.deploy with your values (see .env.deploy.example)
#   VPS_USER, VPS_HOST, VPS_PASSWORD, VPS_APP_DIR
#
# Required on VPS: deploy user must be able to run sudo for: tar, chown, mkdir, cp, systemctl

set -e

# Load config from .env.deploy (create from .env.deploy.example)
if [ -f ".env.deploy" ]; then
  set -a
  source .env.deploy
  set +a
fi

VPS_USER="${VPS_USER:-deploy}"
VPS_HOST="${VPS_HOST:?Set VPS_HOST in .env.deploy}"
VPS_APP_DIR="${VPS_APP_DIR:-/var/www/nullroute-irc}"
VPS_PASSWORD="${VPS_PASSWORD:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

if [ -z "$VPS_HOST" ]; then
  print_error "VPS_HOST not set. Copy .env.deploy.example to .env.deploy and fill in your values."
  exit 1
fi

# Check if sshpass is installed (needed when using password)
if [ -n "$VPS_PASSWORD" ] && ! command -v sshpass &> /dev/null; then
    print_error "sshpass is required when using password. Install with: sudo apt install sshpass"
    exit 1
fi

# Run from script directory (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_status "Deploying to $VPS_HOST..."

# Find npm (nvm, fnm, or system)
find_npm() {
    if command -v npm &> /dev/null; then
        return 0
    fi
    if [ -f "$HOME/.nvm/nvm.sh" ]; then
        . "$HOME/.nvm/nvm.sh"
        command -v npm &> /dev/null && return 0
    fi
    if [ -f "$HOME/.local/share/fnm/fnm" ]; then
        eval "$("$HOME/.local/share/fnm/fnm" env)"
        command -v npm &> /dev/null && return 0
    fi
    [ -x "/usr/bin/npm" ] && export PATH="/usr/bin:$PATH" && return 0
    return 1
}

BUILD_LOCAL=false
if find_npm; then
    print_status "Building React frontend locally..."
    (cd ui && npm run build) && BUILD_LOCAL=true
fi

if [ "$BUILD_LOCAL" != "true" ]; then
    print_warning "npm not found locally. Will build frontend on VPS."
fi

print_status "Creating deployment package..."
if [ "$BUILD_LOCAL" = "true" ] && [ -d "ui/dist" ]; then
    tar czf /tmp/nullroute-features.tar.gz \
        --exclude='app/_build' \
        --exclude='app/deps' \
        --exclude='gateway/.gocache' \
        --exclude='gateway/.gopath' \
        -C . app ui/dist infra gateway
else
    tar czf /tmp/nullroute-features.tar.gz \
        --exclude='app/_build' \
        --exclude='app/deps' \
        --exclude='node_modules' \
        --exclude='dist' \
        --exclude='gateway/.gocache' \
        --exclude='gateway/.gopath' \
        -C . app ui infra gateway
fi

print_status "Uploading to VPS..."
if [ -n "$VPS_PASSWORD" ]; then
  sshpass -p "$VPS_PASSWORD" scp -o StrictHostKeyChecking=no \
    /tmp/nullroute-features.tar.gz \
    ${VPS_USER}@${VPS_HOST}:/tmp/
else
  scp -o StrictHostKeyChecking=no \
    /tmp/nullroute-features.tar.gz \
    ${VPS_USER}@${VPS_HOST}:/tmp/
fi

print_status "Running migrations and deploying on VPS..."
run_ssh() {
  if [ -n "$VPS_PASSWORD" ]; then
    sshpass -p "$VPS_PASSWORD" ssh -o StrictHostKeyChecking=no "$@"
  else
    ssh -o StrictHostKeyChecking=no "$@"
  fi
}

run_ssh "${VPS_USER}@${VPS_HOST}" "SUDO_PASS=${VPS_PASSWORD:-} APP_DIR=${VPS_APP_DIR} DATABASE_URL=${DATABASE_URL:-} bash -s" << 'ENDSSH'
set -e
APP_DIR="${APP_DIR:-/var/www/nullroute-irc}"
SUDO() { if sudo -n true 2>/dev/null; then sudo "$@"; else echo "${SUDO_PASS:-}" | sudo -S "$@"; fi; }

SUDO tar xzf /tmp/nullroute-features.tar.gz -C "$APP_DIR"
rm -f /tmp/nullroute-features.tar.gz
SUDO chown -R www-data:www-data "$APP_DIR"

[ ! -f "$APP_DIR/.env" ] && NEED_ENV=1 || NEED_ENV=0
[ "$NEED_ENV" = "0" ] && ! grep -q '^SECRET_KEY_BASE=' "$APP_DIR/.env" 2>/dev/null && NEED_ENV=1
if [ "$NEED_ENV" = "1" ]; then
  SK=$(cd "$APP_DIR/app" && mix phx.gen.secret 2>/dev/null || echo "CHANGE_ME_$(date +%s)")
  echo "SECRET_KEY_BASE=$SK" > /tmp/nullroute-env
  SUDO cp /tmp/nullroute-env "$APP_DIR/.env"
  rm -f /tmp/nullroute-env
  SUDO chown www-data:www-data "$APP_DIR/.env"
  SUDO chmod 600 "$APP_DIR/.env"
  echo "Created .env with SECRET_KEY_BASE"
fi
SECRET_KEY_BASE=$(grep '^SECRET_KEY_BASE=' "$APP_DIR/.env" 2>/dev/null | cut -d= -f2- || true)

cd "$APP_DIR/app"
[ -z "$SECRET_KEY_BASE" ] && SECRET_KEY_BASE=$(mix phx.gen.secret 2>/dev/null || echo 'placeholder')
DB_URL="${DATABASE_URL:-postgresql://user:password@localhost/nullroute_irc_prod}"
SUDO -u www-data bash -c "export DATABASE_URL='$DB_URL' && export SECRET_KEY_BASE='$SECRET_KEY_BASE' && MIX_ENV=prod mix ecto.migrate"

SUDO mkdir -p priv/static priv/static/uploads
if [ -d "../ui" ] && [ -f "../ui/package.json" ]; then
  SUDO rm -rf ../ui/dist
  SUDO -u www-data bash -c "cd $APP_DIR/ui && npm install && npm run build"
  [ -d "../ui/dist" ] && SUDO cp -r ../ui/dist/* priv/static/
fi
SUDO chown -R www-data:www-data "$APP_DIR"

[ -f "$APP_DIR/infra/nullroute-app.service" ] && SUDO cp "$APP_DIR/infra/nullroute-app.service" /etc/systemd/system/
[ -f "$APP_DIR/infra/nullroute-gateway.service" ] && SUDO cp "$APP_DIR/infra/nullroute-gateway.service" /etc/systemd/system/
SUDO systemctl daemon-reload 2>/dev/null || true

if command -v go &>/dev/null && [ -d "$APP_DIR/gateway" ]; then
  if (cd "$APP_DIR/gateway" && go build -o /tmp/gateway-build ./cmd/gateway) 2>/dev/null; then
    SUDO systemctl stop nullroute-gateway 2>/dev/null || true
    SUDO cp /tmp/gateway-build "$APP_DIR/gateway/gateway" 2>/dev/null && \
    SUDO chown www-data:www-data "$APP_DIR/gateway/gateway" 2>/dev/null && \
    SUDO systemctl start nullroute-gateway 2>/dev/null && echo "Gateway rebuilt"
  fi
fi

SUDO systemctl restart nullroute-app
SUDO systemctl restart nullroute-gateway 2>/dev/null || true
[ -f "$APP_DIR/infra/fix-apache-websocket.sh" ] && SUDO bash "$APP_DIR/infra/fix-apache-websocket.sh" 2>/dev/null || true
echo "Deployment complete!"
ENDSSH

print_status "Deployment complete!"
print_warning "Check logs: ssh ${VPS_USER}@${VPS_HOST} 'sudo journalctl -u nullroute-app -f'"
