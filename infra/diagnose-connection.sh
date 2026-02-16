#!/bin/bash
# Full connection diagnostic for NullRoute IRC
# Run: ssh user@your-vps 'bash -s' < infra/diagnose-connection.sh

set -e

echo "=========================================="
echo "  NullRoute IRC Connection Diagnostic"
echo "=========================================="
echo ""

echo "1. SERVICES"
echo "------------"
for svc in nullroute-app nullroute-gateway redis-server postgresql; do
  status=$(systemctl is-active $svc 2>/dev/null || echo "not-found")
  printf "  %-20s %s\n" "$svc:" "$status"
done
echo ""

echo "2. REDIS"
echo "--------"
redis-cli PING 2>/dev/null && echo "  Redis: OK" || echo "  Redis: FAILED"
echo ""

echo "3. PHOENIX (port 4000)"
echo "----------------------"
ss -tlnp 2>/dev/null | grep -q 4000 && echo "  Phoenix listening: YES" || echo "  Phoenix listening: NO"
echo ""

echo "4. IRC SERVER (\${IRC_HOST:-irc.example.com}:\${IRC_PORT:-6697})"
echo "----------------------------------------"
if timeout 3 openssl s_client -connect "${IRC_HOST:-irc.example.com}:${IRC_PORT:-6697}" -quiet 2>/dev/null | head -1 | grep -q "NOTICE\|Welcome"; then
  echo "  IRC server: REACHABLE"
else
  echo "  IRC server: UNREACHABLE or no response"
fi
echo ""

echo "5. GO GATEWAY LOGS (last 15 lines)"
echo "----------------------------------"
journalctl -u nullroute-gateway -n 15 --no-pager 2>/dev/null || echo "  (need sudo for journalctl)"
echo ""

echo "6. MANUAL REDIS TEST"
echo "--------------------"
echo "  To watch for connect commands while you load the page:"
echo "    redis-cli PSUBSCRIBE 'commands:*'"
echo "  You should see a PUBLISH when you join the IRC client."
echo ""

echo "7. WEBSOCKET URL"
echo "----------------"
echo "  wss://irc.example.com/socket/websocket?vsn=2.0.0"
echo "  (Requires session cookie - must be logged in)"
echo ""

echo "8. BROWSER CONSOLE CHECK"
echo "------------------------"
echo "  - Open DevTools (F12) -> Console"
echo "  - Look for: 'transport: connected' or WebSocket errors"
echo "  - Look for: 'Channel join error'"
echo ""
