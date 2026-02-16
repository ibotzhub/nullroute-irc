#!/bin/bash
# Fix Apache WebSocket proxy for Phoenix Channels
# Run on VPS: sudo bash infra/fix-apache-websocket.sh
#
# Set DOMAIN_NAME env or edit this script to match your domain.

set -e

APP_DIR="/var/www/nullroute-irc"
DOMAIN_NAME="${DOMAIN_NAME:-irc.example.com}"
CONF_HTTP="/etc/apache2/sites-available/nullroute-irc-hybrid.conf"
CONF_SSL="/etc/apache2/sites-available/nullroute-irc-hybrid-le-ssl.conf"
[ ! -f "$CONF_SSL" ] && CONF_SSL=$(ls /etc/apache2/sites-available/*irc*ssl* 2>/dev/null | head -1)

echo "Fixing Apache WebSocket proxy for $DOMAIN_NAME..."

a2enmod rewrite proxy proxy_http proxy_wstunnel 2>/dev/null || true

if [ -f "$APP_DIR/infra/apache/nullroute-irc-hybrid.conf" ]; then
  cp "$APP_DIR/infra/apache/nullroute-irc-hybrid.conf" "$CONF_HTTP"
  sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" "$CONF_HTTP"
  echo "Updated $CONF_HTTP"
fi

if [ -f "$APP_DIR/infra/apache/nullroute-irc-hybrid-ssl.conf" ] && [ -f "$CONF_SSL" ]; then
  cp "$APP_DIR/infra/apache/nullroute-irc-hybrid-ssl.conf" "$CONF_SSL"
  sed -i "s/irc.example.com/$DOMAIN_NAME/g" "$CONF_SSL"
  sed -i "s/chat.example.com/chat.$DOMAIN_NAME/g" "$CONF_SSL"
  sed -i "s|YOUR_DOMAIN|$DOMAIN_NAME|g" "$CONF_SSL"
  echo "Updated $CONF_SSL"
elif [ -f "$CONF_SSL" ]; then
  echo "No SSL config in infra. Run: sudo certbot --apache -d $DOMAIN_NAME"
  echo "Then re-run this script."
fi

apache2ctl configtest
systemctl reload apache2
echo "Apache reloaded."
