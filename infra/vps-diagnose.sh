#!/bin/bash
# Run on VPS to diagnose connection/feature issues
# Usage: ssh user@your-vps 'bash -s' < infra/vps-diagnose.sh
# Or: ssh user@your-vps, then: bash /var/www/nullroute-irc/infra/vps-diagnose.sh

set -e

echo "=== NullRoute IRC VPS Diagnostic ==="
echo ""

echo "1. Service status:"
systemctl is-active nullroute-app 2>/dev/null && echo "  nullroute-app: running" || echo "  nullroute-app: NOT RUNNING"
systemctl is-active nullroute-gateway 2>/dev/null && echo "  nullroute-gateway: running" || echo "  nullroute-gateway: NOT RUNNING"
systemctl is-active redis-server 2>/dev/null && echo "  redis: running" || systemctl is-active redis 2>/dev/null && echo "  redis: running" || echo "  redis: NOT RUNNING"
systemctl is-active postgresql 2>/dev/null && echo "  postgresql: running" || echo "  postgresql: NOT RUNNING"
echo ""

echo "2. Phoenix listening on 4000?"
ss -tlnp 2>/dev/null | grep 4000 || netstat -tlnp 2>/dev/null | grep 4000 || echo "  Port 4000 not in use - Phoenix may not be running"
echo ""

echo "3. Apache sites enabled:"
ls -la /etc/apache2/sites-enabled/ 2>/dev/null | grep -E 'nullroute|irc' || echo "  No nullroute/irc sites found"
echo ""

echo "4. SSL vhost for irc/chat - WebSocket config present?"
for f in /etc/apache2/sites-enabled/*ssl* /etc/apache2/sites-enabled/*irc*; do
  [ -f "$f" ] && (grep -l "upgrade=websocket\|ProxyPass.*socket" "$f" 2>/dev/null && echo "  $f: has WebSocket" || echo "  $f: MISSING WebSocket proxy")
done
echo ""

echo "5. Certbot certs (for irc + chat):"
certbot certificates 2>/dev/null | grep -A2 "irc\|chat" || echo "  Run: sudo certbot certificates"
echo ""

echo "6. Recent nullroute-app errors:"
journalctl -u nullroute-app -n 20 --no-pager 2>/dev/null | tail -15 || true
echo ""

echo "7. Recent nullroute-gateway errors:"
journalctl -u nullroute-gateway -n 20 --no-pager 2>/dev/null | tail -15 || true
echo ""

echo "8. Apache error log (last 10):"
sudo tail -10 /var/log/apache2/nullroute-irc*.log 2>/dev/null || sudo tail -10 /var/log/apache2/error.log 2>/dev/null || true
echo ""

echo "=== Quick fixes ==="
echo "  1. Fix WebSocket: sudo bash /var/www/nullroute-irc/infra/fix-apache-websocket.sh"
echo "  2. Restart: sudo systemctl restart nullroute-app nullroute-gateway"
echo "  3. For your domain:"
echo "     - Add to cert: sudo certbot --apache -d irc.yourdomain.com -d chat.yourdomain.com"
echo "     - Disable conflicting site if needed: sudo a2dissite other-site.conf; sudo systemctl reload apache2"
