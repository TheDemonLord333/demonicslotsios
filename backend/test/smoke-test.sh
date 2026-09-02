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

echo "== admin list carries a stable id for the new player =="
STATUS=$(curl -s -o /tmp/smoke_players.json -w "%{http_code}" "$BASE_URL/api/admin/players" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
expect_status "list players" 200 "$STATUS"
PLAYER_ID=$(python3 -c "
import sys, json
players = json.load(sys.stdin)
matches = [p['id'] for p in players if p['username'] == '$USERNAME']
print(matches[0] if matches else '')
" < /tmp/smoke_players.json)
[ -n "$PLAYER_ID" ] && pass "found id for $USERNAME" || fail "found id for $USERNAME"

echo "== new player defaults to level 1, winChanceMultiplier 1.0, guaranteedJackpot false =="
expect_field "default level is 1" "1" "$(json_field level < /tmp/smoke_resp.json)"
expect_field "default winChanceMultiplier is 1.0" "1" "$(json_field winChanceMultiplier < /tmp/smoke_resp.json)"
expect_field "default guaranteedJackpot is false" "False" "$(json_field guaranteedJackpot < /tmp/smoke_resp.json)"

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

echo "== admin can set level, winChanceMultiplier and guaranteedJackpot without touching admin_revision =="
REVISION_BEFORE=$(json_field adminRevision < /tmp/smoke_resp.json)
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X PATCH "$BASE_URL/api/admin/players/$PLAYER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"level":12,"winChanceMultiplier":1.08,"guaranteedJackpot":true}')
expect_status "admin level/multiplier/jackpot update" 200 "$STATUS"
expect_field "level updated" "12" "$(json_field level < /tmp/smoke_resp.json)"
expect_field "winChanceMultiplier updated" "1.08" "$(json_field winChanceMultiplier < /tmp/smoke_resp.json)"
expect_field "guaranteedJackpot updated" "True" "$(json_field guaranteedJackpot < /tmp/smoke_resp.json)"
expect_field "admin_revision unchanged by a level/multiplier/jackpot-only edit" "$REVISION_BEFORE" "$(json_field adminRevision < /tmp/smoke_resp.json)"

echo "== the next sync reflects the admin-set level/multiplier/jackpot without a server_wins conflict =="
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/sync" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"deviceToken\":\"$DEVICE_TOKEN\",\"localBalance\":4200,\"lastKnownAdminRevision\":$REVISION_BEFORE}")
expect_status "sync after level/multiplier/jackpot edit" 200 "$STATUS"
expect_field "resolution is still client_applied" "client_applied" "$(json_field resolution < /tmp/smoke_resp.json)"
expect_field "sync carries the new level" "12" "$(json_field level < /tmp/smoke_resp.json)"
expect_field "sync carries the new winChanceMultiplier" "1.08" "$(json_field winChanceMultiplier < /tmp/smoke_resp.json)"
expect_field "sync carries the new guaranteedJackpot" "True" "$(json_field guaranteedJackpot < /tmp/smoke_resp.json)"

echo "== admin can turn guaranteedJackpot back off again =="
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X PATCH "$BASE_URL/api/admin/players/$PLAYER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"guaranteedJackpot":false}')
expect_status "admin jackpot disable" 200 "$STATUS"
expect_field "guaranteedJackpot disabled" "False" "$(json_field guaranteedJackpot < /tmp/smoke_resp.json)"
expect_field "admin_revision still unchanged by a jackpot-only edit" "$REVISION_BEFORE" "$(json_field adminRevision < /tmp/smoke_resp.json)"

echo "== a client-claimed earnedLevel raises the stored level, but never lowers it =="
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/sync" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"deviceToken\":\"$DEVICE_TOKEN\",\"localBalance\":4200,\"lastKnownAdminRevision\":$REVISION_BEFORE,\"earnedLevel\":40}")
expect_status "sync with a higher earnedLevel" 200 "$STATUS"
expect_field "level raised to the claimed value" "40" "$(json_field level < /tmp/smoke_resp.json)"
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/sync" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"deviceToken\":\"$DEVICE_TOKEN\",\"localBalance\":4200,\"lastKnownAdminRevision\":$REVISION_BEFORE,\"earnedLevel\":3}")
expect_status "sync with a lower earnedLevel" 200 "$STATUS"
expect_field "level is NOT lowered by a smaller claim" "40" "$(json_field level < /tmp/smoke_resp.json)"
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/sync" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"deviceToken\":\"$DEVICE_TOKEN\",\"localBalance\":4200,\"lastKnownAdminRevision\":$REVISION_BEFORE,\"earnedLevel\":99999}")
expect_status "sync with an out-of-range earnedLevel is not an error" 200 "$STATUS"
expect_field "out-of-range claim is ignored, not applied" "40" "$(json_field level < /tmp/smoke_resp.json)"

echo "== invalid level/winChanceMultiplier/guaranteedJackpot are rejected, not silently clamped/coerced =="
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/api/admin/players/$PLAYER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"level":-500}')
expect_status "negative level rejected" 400 "$STATUS"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/api/admin/players/$PLAYER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"winChanceMultiplier":99999}')
expect_status "absurd multiplier rejected" 400 "$STATUS"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/api/admin/players/$PLAYER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"guaranteedJackpot":"yes"}')
expect_status "non-boolean guaranteedJackpot rejected" 400 "$STATUS"

echo "== admin can rename a player by id; renaming to a taken name is rejected =="
RENAMED_USERNAME="Renamed${RANDOM_SUFFIX}"
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X PATCH "$BASE_URL/api/admin/players/$PLAYER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d "{\"username\":\"$RENAMED_USERNAME\"}")
expect_status "rename" 200 "$STATUS"
expect_field "username updated" "$RENAMED_USERNAME" "$(json_field username < /tmp/smoke_resp.json)"

STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/register" \
  -H "Content-Type: application/json" -d "{\"username\":\"SmokeTaken${RANDOM_SUFFIX}\",\"initialBalance\":1}")
expect_status "register a second player to collide with" 201 "$STATUS"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "$BASE_URL/api/admin/players/$PLAYER_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d "{\"username\":\"SmokeTaken${RANDOM_SUFFIX}\"}")
expect_status "rename to a taken username rejected" 409 "$STATUS"

echo "== a device syncing under the pre-rename username still works (falls back to device token) =="
STATUS=$(curl -s -o /tmp/smoke_resp.json -w "%{http_code}" -X POST "$BASE_URL/api/players/sync" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$USERNAME\",\"deviceToken\":\"$DEVICE_TOKEN\",\"localBalance\":4200,\"lastKnownAdminRevision\":$REVISION_BEFORE}")
expect_status "sync with stale (pre-rename) username" 200 "$STATUS"
expect_field "sync reports the new username" "$RENAMED_USERNAME" "$(json_field username < /tmp/smoke_resp.json)"
USERNAME="$RENAMED_USERNAME"

echo "== admin override of balance always wins, ignoring a stale local balance =="
curl -s -o /dev/null -X PATCH "$BASE_URL/api/admin/players/$PLAYER_ID" \
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
