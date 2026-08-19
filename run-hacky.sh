#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
set -a
source .env
set +a
export PATH="$PWD/target/release:$PATH"

pkill -f buzz-acp 2>/dev/null || true
pkill -f buzz-agent 2>/dev/null || true
pkill -f buzz-dev-mcp 2>/dev/null || true
sleep 2

exec env \
  BUZZ_AGENT_PROVIDER=openai \
  OPENAI_COMPAT_API_KEY="$DEEPSEEK_API_KEY" \
  OPENAI_COMPAT_BASE_URL=https://api.deepseek.com/v1 \
  OPENAI_COMPAT_MODEL=deepseek-chat \
  OPENAI_COMPAT_API=chat \
  BUZZ_ACP_AGENT_OWNER="$RELAY_OWNER_PUBKEY" \
  PATH="$PATH" \
  buzz-acp \
    --relay-url "$RELAY_URL" \
    --private-key "$AGENT_PRIVATE_KEY" \
    --agent-command buzz-agent \
    --agent-args acp \
    --mcp-command buzz-dev-mcp \
    --system-prompt-file /tmp/hacky-prompt.txt \
    --channels ecfea7b1-e369-4ff8-917a-18abb2c2b8a8 \
    --subscribe mentions \
    --respond-to owner-only \
  >> /tmp/hacky-acp.log 2>&1
