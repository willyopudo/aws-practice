#!/usr/bin/env bash
# Usage: scripts/sonar-local.sh [--down]
# Run the Sonar analysis against a local SonarQube Community container instead of SonarCloud.
# The container is kept running between runs (first start ~1-2 min, reruns are fast);
# --down removes it. Nothing leaves this machine.
set -euo pipefail

SERVER_IMAGE="${SONAR_SERVER_IMAGE:-sonarqube:community}"
SCANNER_IMAGE="sonarsource/sonar-scanner-cli:11"
NAME="sonar-local"
NET="sonar-local-net"
PORT="${SONAR_LOCAL_PORT:-9000}"
URL="http://localhost:$PORT"
# Set SONAR_LOCAL_PASSWORD if you changed the admin password in the UI.
# Falls back to SonarQube's documented first-run default.
DEFAULT_PASSWORD="admin"
DEFAULT_AUTH="admin:$DEFAULT_PASSWORD"
AUTH="admin:${SONAR_LOCAL_PASSWORD:-$DEFAULT_PASSWORD}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${1:-}" == "--down" ]]; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  echo "✓ removed $NAME"
  exit 0
fi

docker network inspect "$NET" >/dev/null 2>&1 || docker network create "$NET" >/dev/null

if [[ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null || true)" != "true" ]]; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  echo "starting $SERVER_IMAGE ..." >&2
  docker run -d --name "$NAME" --network "$NET" -p "127.0.0.1:$PORT:9000" \
    -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true "$SERVER_IMAGE" >/dev/null
fi

echo "waiting for SonarQube ..." >&2
for _ in $(seq 1 90); do
  curl -fsS "$URL/api/system/status" 2>/dev/null | grep -q '"status":"UP"' && break
  sleep 3
done
curl -fsS "$URL/api/system/status" | grep -q '"status":"UP"' || { echo "✗ SonarQube did not come up" >&2; exit 1; }

auth_ok() { curl -fsS -u "$1" "$URL/api/authentication/validate" | grep -q '"valid":true'; }
if [[ -n "${SONAR_LOCAL_PASSWORD:-}" ]] && ! auth_ok "$AUTH" && auth_ok "$DEFAULT_AUTH"; then
  curl -fsS -u "$DEFAULT_AUTH" -X POST "$URL/api/users/change_password" \
    --data-urlencode "login=admin" --data-urlencode "previousPassword=$DEFAULT_PASSWORD" \
    --data-urlencode "password=$SONAR_LOCAL_PASSWORD" >/dev/null
fi

# Short-lived token per run, held in memory only and revoked on exit.
token_name="run-$(date +%s)"
SONAR_TOKEN="$(curl -fsS -u "$AUTH" -X POST "$URL/api/user_tokens/generate" -d "name=$token_name" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
[[ -n "$SONAR_TOKEN" ]] || { echo "✗ could not create a token (admin password changed? set SONAR_LOCAL_PASSWORD)" >&2; exit 1; }
export SONAR_TOKEN
trap 'curl -fsS -u "$AUTH" -X POST "$URL/api/user_tokens/revoke" -d "name=$token_name" >/dev/null 2>&1 || true' EXIT

docker run --rm --network "$NET" -e SONAR_TOKEN -v "$REPO_ROOT:/usr/src" "$SCANNER_IMAGE" \
  -Dproject.settings=sonar-local.properties \
  -Dsonar.host.url="http://$NAME:9000" \
  -Dsonar.qualitygate.wait=true
echo "✓ report: $URL/dashboard?id=aws-practice-local"
