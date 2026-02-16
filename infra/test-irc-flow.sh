#!/bin/bash
# Test IRC flow: login, then verify gateway receives connect and connects to IRC
# Run: bash infra/test-irc-flow.sh

set -e
BASE="${BASE_URL:-https://irc.example.com}"
COOKIES="/tmp/irc-test-cookies.txt"

echo "=== NullRoute IRC Flow Test ==="
echo ""

echo "1. Login..."
LOGIN=$(curl -s -c "$COOKIES" -b "$COOKIES" -X POST "$BASE/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"changeme123"}')
if echo "$LOGIN" | grep -q '"user"'; then
  echo "   OK - Logged in as admin"
else
  echo "   FAIL - Login failed: $LOGIN"
  exit 1
fi

echo ""
echo "2. Load app (with session)..."
APP=$(curl -s -b "$COOKIES" "$BASE/")
if echo "$APP" | grep -q 'NullRoute IRC'; then
  echo "   OK - App loads"
else
  echo "   FAIL - App did not load"
  exit 1
fi

echo ""
echo "3. Check /api/auth/me..."
ME=$(curl -s -b "$COOKIES" "$BASE/api/auth/me")
if echo "$ME" | grep -q '"id"'; then
  echo "   OK - Session valid"
else
  echo "   FAIL - Session invalid: $ME"
  exit 1
fi

echo ""
echo "=== API/HTTP tests passed ==="
echo ""
echo "To fully test IRC:"
echo "  1. Open \$BASE_URL (or https://irc.example.com) in a browser"
echo "  2. Log in as admin / changeme123"
echo "  3. You should see 'Connecting...' then 'Connected' with your nick"
echo "  4. Join #test and send a message"
echo ""
echo "To check gateway logs on VPS:"
echo "  ssh user@your-vps 'sudo journalctl -u nullroute-gateway -f'"
echo ""
