#!/bin/bash
# Create admin user on VPS (username: admin, password: changeme123)
# Run on VPS: sudo bash /var/www/nullroute-irc/infra/create-admin.sh
# Or from local: ssh user@your-vps 'sudo bash /var/www/nullroute-irc/infra/create-admin.sh'

set -e
APP_DIR="/var/www/nullroute-irc"
cd "$APP_DIR/app"

# Load only SECRET_KEY_BASE from .env
SECRET_KEY_BASE=$(grep '^SECRET_KEY_BASE=' "$APP_DIR/.env" 2>/dev/null | cut -d= -f2- || true)
export DATABASE_URL="${DATABASE_URL:-postgresql://nullroute:changeme@localhost/nullroute_irc_prod}"
export MIX_ENV=prod

echo "Stopping nullroute-app..."
systemctl stop nullroute-app 2>/dev/null || true
sleep 2

echo "Creating admin user..."
sudo -u www-data bash -c "cd $APP_DIR/app && export DATABASE_URL='$DATABASE_URL' && export SECRET_KEY_BASE='${SECRET_KEY_BASE:-}' && [ -z \"\$SECRET_KEY_BASE\" ] && export SECRET_KEY_BASE=\$(mix phx.gen.secret 2>/dev/null); MIX_ENV=prod mix run priv/repo/seeds.exs"

echo "Starting nullroute-app..."
systemctl start nullroute-app

echo "Done! Admin: username=admin, password=changeme123"
