#!/usr/bin/env bash
# Smoke test for the Demonic Slots backend: exercises registration,
# case-insensitive username uniqueness, the client-driven and admin-driven
# sync conflict resolution, and device-token authentication.
#
# Usage: BASE_URL=http://localhost:3007 ADMIN_TOKEN=... ./test/smoke-test.sh
# Defaults to a local server with a throwaway admin token if unset - run
# `npm start` in another terminal first (against a scratch/dev database).

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3007}"
ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token-12345}"
FAILURES=0

pass() { echo "  OK: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

expect_status() {
  local description="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$description (HTTP $actual)"
  else
    fail "$description (expected HTTP $expected, got $actual)"
  fi
}

expect_field() {
  local description="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$description ($actual)"
  else
    fail "$description (expected '$expected', got '$actual')"
  fi
}

json_field() {
  python3 -c "import sys, json; print(json.load(sys.stdin).get('$1', ''))"
}

RANDOM_SUFFIX=$RANDOM
USERNAME="SmokeTest${RANDOM_SUFFIX}"

echo "== health =="
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" "$BASE_URL/api/health")
expect_status "health check" 200 "$STATUS"

echo "== register =="
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/register" \
  -H "Content-Type: application/json" -d "{\"username\":\"$USERNAME\",\"initialBalance\":5000}")
expect_status "register new username" 201 "$STATUS"
DEVICE_TOKEN=$(json_field deviceToken < /tmp/smoke_resp.json)
[ -n "$DEVICE_TOKEN" ] && pass "device token issued" || fail "device token issued"

echo "== new player defaults to level 1, winChanceMultiplier 1.0 =="
expect_field "default level is 1" "1" "$(json_field level < /tmp/smoke_resp.json)"
expect_field "default winChanceMultiplier is 1.0" "1" "$(json_field winChanceMultiplier < /tmp/smoke_resp.json)"

echo "== duplicate username (different casing) is rejected =="
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/register" \
  -H "Content-Type: application/json" -d "{\"username\":\"${USERNAME,,}\",\"initialBalance\":100}")
expect_status "duplicate username rejected" 409 "$STATUS"

echo "== client-driven sync applies local balance =="
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/sync" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"deviceToken\":\"$DEVICE_TOKEN\",\"localBalance\":4200,\"lastKnownAdminRevision\":0}")
expect_status "sync request" 200 "$STATUS"
expect_field "resolution is client_applied" "client_applied" "$(json_field resolution < /tmp/smoke_resp.json)"
expect_field "balance reflects local play" "4200" "$(json_field coinBalance < /tmp/smoke_resp.json)"

echo "== admin can set level and winChanceMultiplier without touching admin_revision =="
REVISION_BEFORE=$(json_field adminRevision < /tmp/smoke_resp.json)
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X PATCH "$BASE_URL/api/admin/players/$USERNAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"level":12,"winChanceMultiplier":1.08}')
expect_status "admin level/multiplier update" 200 "$STATUS"
expect_field "level updated" "12" "$(json_field level < /tmp/smoke_resp.json)"
expect_field "winChanceMultiplier updated" "1.08" "$(json_field winChanceMultiplier < /tmp/smoke_resp.json)"
expect_field "admin_revision unchanged by a level/multiplier-only edit" "$REVISION_BEFORE" "$(json_field adminRevision < /tmp/smoke_resp.json)"

echo "== the next sync reflects the admin-set level/multiplier without a server_wins conflict =="
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/sync" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"deviceToken\":\"$DEVICE_TOKEN\",\"localBalance\":4200,\"lastKnownAdminRevision\":$REVISION_BEFORE}")
expect_status "sync after level/multiplier edit" 200 "$STATUS"
expect_field "resolution is still client_applied" "client_applied" "$(json_field resolution < /tmp/smoke_resp.json)"
expect_field "sync carries the new level" "12" "$(json_field level < /tmp/smoke_resp.json)"
expect_field "sync carries the new winChanceMultiplier" "1.08" "$(json_field winChanceMultiplier < /tmp/smoke_resp.json)"

echo "== invalid level/winChanceMultiplier are rejected, not silently clamped =="
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/api/admin/players/$USERNAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"level":-500}')
expect_status "negative level rejected" 400 "$STATUS"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/api/admin/players/$USERNAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"winChanceMultiplier":99999}')
expect_status "absurd multiplier rejected" 400 "$STATUS"

echo "== admin override of balance always wins, ignoring a stale local balance =="
curl -s -o /dev/null -X PATCH "$BASE_URL/api/admin/players/$USERNAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"balance":99999}'
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/sync" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"deviceToken\":\"$DEVICE_TOKEN\",\"localBalance\":1,\"lastKnownAdminRevision\":$REVISION_BEFORE}")
expect_status "sync after admin edit" 200 "$STATUS"
expect_field "resolution is server_wins" "server_wins" "$(json_field resolution < /tmp/smoke_resp.json)"
expect_field "server balance overrides local" "99999" "$(json_field coinBalance < /tmp/smoke_resp.json)"

echo "== wrong device token is rejected =="
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/sync" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"deviceToken\":\"wrong-token\",\"localBalance\":1,\"lastKnownAdminRevision\":1}")
expect_status "wrong device token rejected" 403 "$STATUS"

echo "== admin routes require the token =="
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/admin/players")
expect_status "admin route without token rejected" 401 "$STATUS"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All checks passed."
  exit 0
else
  echo "$FAILURES check(s) failed."
  exit 1
fi
