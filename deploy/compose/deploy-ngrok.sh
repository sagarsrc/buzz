#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Use the repo-root .env only for NGROK_* values; the real compose .env is below.
ROOT_ENV="/root/buzz/.env"
ENV_FILE="${SCRIPT_DIR}/.env"
EXAMPLE="${SCRIPT_DIR}/.env.example"
NGROK_LOG="/tmp/ngrok-buzz.log"

PYTHON="/opt/buzz-venv/bin/python"

fail() { echo "$1" >&2; exit 1; }

[[ -f "$EXAMPLE" ]] || fail "Missing ${EXAMPLE}"

# ---------------------------------------------------------------------------
# 1. Read NGROK auth token (and optional static domain) from root .env.
# ---------------------------------------------------------------------------
NGROK_AUTH_TOKEN=""
NGROK_STATIC_DOMAIN=""
if [[ -f "$ROOT_ENV" ]]; then
  NGROK_AUTH_TOKEN="$(grep -E '^NGROK_AUTH_TOKEN=' "$ROOT_ENV" | cut -d= -f2- | head -n1 || true)"
  NGROK_STATIC_DOMAIN="$(grep -E '^NGROK_STATIC_DOMAIN=' "$ROOT_ENV" | cut -d= -f2- | head -n1 || true)"
fi

if [[ -z "${NGROK_AUTH_TOKEN}" ]]; then
  fail "No NGROK_AUTH_TOKEN found in ${ROOT_ENV}. Add it and rerun."
fi

# ---------------------------------------------------------------------------
# 2. Configure ngrok.
# ---------------------------------------------------------------------------
ngrok config add-authtoken "${NGROK_AUTH_TOKEN}" >/dev/null

# ---------------------------------------------------------------------------
# 3. Start or reuse an ngrok tunnel to localhost:3000.
# ---------------------------------------------------------------------------
PUBLIC_URL=""
if curl -fsS http://127.0.0.1:4040/api/tunnels >/dev/null 2>&1; then
  PUBLIC_URL="$(curl -fsS http://127.0.0.1:4040/api/tunnels | /usr/bin/python3 -c 'import sys,json; ts=json.load(sys.stdin)["tunnels"]; print(next(t["public_url"] for t in ts if t["public_url"].startswith("https://")))' 2>/dev/null || true)"
fi

if [[ -z "${PUBLIC_URL}" ]]; then
  echo "Starting ngrok tunnel..."
  rm -f "$NGROK_LOG"
  if [[ -n "${NGROK_STATIC_DOMAIN}" ]]; then
    nohup ngrok http --url="${NGROK_STATIC_DOMAIN}" 3000 >"$NGROK_LOG" 2>&1 &
  else
    nohup ngrok http 3000 >"$NGROK_LOG" 2>&1 &
  fi
  disown

  for i in {1..30}; do
    if PUBLIC_URL="$(curl -fsS http://127.0.0.1:4040/api/tunnels 2>/dev/null | /usr/bin/python3 -c 'import sys,json; ts=json.load(sys.stdin)["tunnels"]; print(next(t["public_url"] for t in ts if t["public_url"].startswith("https://")))' 2>/dev/null || true)" && [[ -n "$PUBLIC_URL" ]]; then
      break
    fi
    sleep 1
  done
fi

[[ -n "${PUBLIC_URL}" ]] || fail "ngrok did not expose a public URL. Check ${NGROK_LOG}"
echo "ngrok public URL: ${PUBLIC_URL}"

HOST="${PUBLIC_URL#https://}"
HOST="${HOST#http://}"
HOST="${HOST%/}"

# ---------------------------------------------------------------------------
# 4. Generate stable secrets and owner keypair.
# ---------------------------------------------------------------------------
hex32() { openssl rand -hex 32; }

RELAY_PRIVATE_KEY="$(hex32)"
RELAY_OWNER_PUBKEY="$("$PYTHON" - <<PY
import coincurve
priv = bytes.fromhex("${RELAY_PRIVATE_KEY}")
print(coincurve.PrivateKey(priv).public_key.format(compressed=False)[1:33].hex())
PY
)"

POSTGRES_PASSWORD="$(hex32)"
REDIS_PASSWORD="$(hex32)"
GIT_HMAC="$(hex32)"
S3_ACCESS="$(hex32)"
S3_SECRET="$(hex32)"

# ---------------------------------------------------------------------------
# 5. Write deploy/compose/.env.
# ---------------------------------------------------------------------------
cp "$EXAMPLE" "$ENV_FILE"

"$PYTHON" - <<PY
import re
path = "${ENV_FILE}"
with open(path) as f:
    text = f.read()

def repl(name, value):
    global text
    text = re.sub(rf"^{re.escape(name)}=.*$", f"{name}={value}", text, flags=re.M)

repl("BUZZ_IMAGE", "ghcr.io/block/buzz:main")
repl("BUZZ_DOMAIN", "${HOST}")
repl("RELAY_URL", "wss://${HOST}")
repl("BUZZ_MEDIA_BASE_URL", "https://${HOST}/media")
repl("BUZZ_MEDIA_SERVER_DOMAIN", "${HOST}")
repl("BUZZ_CORS_ORIGINS", "https://${HOST}")
repl("RELAY_OWNER_PUBKEY", "${RELAY_OWNER_PUBKEY}")
repl("BUZZ_RELAY_PRIVATE_KEY", "${RELAY_PRIVATE_KEY}")
repl("BUZZ_GIT_HOOK_HMAC_SECRET", "${GIT_HMAC}")
repl("POSTGRES_PASSWORD", "${POSTGRES_PASSWORD}")
repl("REDIS_PASSWORD", "${REDIS_PASSWORD}")
repl("BUZZ_S3_ACCESS_KEY", "${S3_ACCESS}")
repl("BUZZ_S3_SECRET_KEY", "${S3_SECRET}")


with open(path, "w") as f:
    f.write(text)
PY

# Sanity check: no CHANGE_ME left.
if grep -Eq '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=.*CHANGE_ME' "$ENV_FILE"; then
  grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=.*CHANGE_ME' "$ENV_FILE" >&2
  fail ".env still contains CHANGE_ME placeholders"
fi

# ---------------------------------------------------------------------------
# 6. Validate Compose config.
# ---------------------------------------------------------------------------
./run.sh config >/dev/null

# ---------------------------------------------------------------------------
# 7. Start the Buzz stack.
# ---------------------------------------------------------------------------
echo "Starting Buzz stack..."
./run.sh start

# ---------------------------------------------------------------------------
# 8. Add the owner pubkey as an admin member so they can auth.
# ---------------------------------------------------------------------------
sleep 2
./run.sh add-member "${RELAY_OWNER_PUBKEY}" --role admin || true

# ---------------------------------------------------------------------------
# 9. Local health check.
# ---------------------------------------------------------------------------
echo "Waiting for relay health..."
for i in {1..30}; do
  if curl -fsS "http://127.0.0.1:3000/_liveness" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -fsS "http://127.0.0.1:3000/_liveness" || fail "Relay health check failed"

# ---------------------------------------------------------------------------
# 10. Print handover.
# ---------------------------------------------------------------------------
cat <<MSG

=== Buzz deployed via ngrok ===
Public relay URL:    wss://${HOST}
Public HTTPS root:   https://${HOST}
Local health:        http://127.0.0.1:3000/_liveness
Local status:        http://127.0.0.1:3000/_status
NIP-11 info:         curl -H 'Accept: application/nostr+json' https://${HOST}/

Owner pubkey (hex):  ${RELAY_OWNER_PUBKEY}
Owner private key:   ${RELAY_PRIVATE_KEY}

BACK UP deploy/compose/.env IMMEDIATELY. Losing these keys breaks the relay.

To stop:   cd deploy/compose && ./run.sh stop
To start:  cd deploy/compose && ./run.sh start
To logs:   cd deploy/compose && ./run.sh logs

ngrok is running detached. To stop it: pkill ngrok
MSG
