# Self-host Buzz on a VPS with ngrok

This guide walks through running a single-node Buzz relay on a VPS (tested on a Contabo Ubuntu 24.04 machine) and exposing it over the public internet with an ngrok HTTPS tunnel.

It also includes an optional end-to-end agent test: a HackerNews-curating agent that replies in a Buzz channel using the ACP harness, `buzz-agent`, `buzz-dev-mcp`, and DeepSeek.

## What you get

- A Buzz relay reachable at a public `wss://` WebSocket URL.
- Postgres, Redis, MinIO, and git storage running in Docker Compose.
- A working `@HN Curator` agent you can mention in a channel.

## Prerequisites

- A VPS with root access running Ubuntu 24.04 (or similar Debian/Ubuntu).
- At least 2 vCPU, 4 GB RAM, 20 GB disk (more for real use).
- An [ngrok](https://ngrok.com) account and authtoken.
- For the agent test: a DeepSeek API key.

## Required installations

You will install the following on the VPS:

| Tool | Why it is needed |
|------|------------------|
| Docker Engine + Docker Compose v2 plugin | Runs the Buzz relay stack (relay, Postgres, Redis, MinIO) |
| ngrok v3 | Creates a public HTTPS tunnel to the local relay |
| uv | Used only to create a small Python venv for Nostr key derivation |
| coincurve (in a uv venv) | Derives an owner/agent pubkey from a hex private key |
| Rust toolchain (via Hermit in the repo) | Builds `buzz`, `buzz-agent`, `buzz-acp`, `buzz-dev-mcp` |
| git | Cloning the Buzz repository |

All commands below are run as root unless noted.

## 1. Prepare the server

```bash
apt update
apt install -y ca-certificates curl
```

For fully non-interactive installs, export this first so apt dialogs do not block:

```bash
export DEBIAN_FRONTEND=noninteractive
```

## 2. Install Docker Engine and Compose v2

```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update
apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
```

## 3. Install ngrok and uv

```bash
# ngrok
curl -fsSLO https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
tar xvzf ngrok-v3-stable-linux-amd64.tgz -C /usr/local/bin
rm ngrok-v3-stable-linux-amd64.tgz

# uv (used for a tiny Python key helper)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## 4. Clone Buzz and build release binaries

```bash
git clone https://github.com/block/buzz.git
cd buzz
. ./bin/activate-hermit

cargo build --release -p buzz-cli -p buzz-agent -p buzz-acp -p buzz-dev-mcp
```

The binaries land in `target/release/`.

## 5. Configure secrets

Create a repo-root `.env` file. This file is already gitignored.

```bash
cat > .env <<'EOF'
NGROK_AUTH_TOKEN=<your-ngrok-authtoken>
DEEPSEEK_API_KEY=<your-deepseek-key>
EOF
```

Do not put real values in any committed file. The deployment script below generates the remaining secrets for you.

## 6. Deploy the relay

A bootstrap script is provided at `deploy/compose/deploy-ngrok.sh`. It:

1. Reads `NGROK_AUTH_TOKEN` from the repo-root `.env`.
2. Starts an ngrok tunnel to `localhost:3000`.
3. Generates stable relay keys, DB/Redis/S3/git secrets, and an owner keypair.
4. Writes `deploy/compose/.env` with the dynamic public ngrok URL wired into `RELAY_URL`, `BUZZ_MEDIA_BASE_URL`, and `BUZZ_CORS_ORIGINS`.
5. Starts the Docker Compose stack.
6. Adds the owner pubkey as a relay admin.

Run it:

```bash
./deploy/compose/deploy-ngrok.sh
```

At the end it prints:

- Public relay WebSocket URL: `wss://<host>.ngrok-free.app`
- Public HTTPS root: `https://<host>.ngrok-free.app`
- Owner pubkey (hex)
- Owner private key

**Back up `deploy/compose/.env` immediately.** Losing the relay private key or owner key breaks the deployment.

### Verify the relay

```bash
curl -fsS "https://<host>.ngrok-free.app/_liveness"
curl -fsS -H "Accept: application/nostr+json" "https://<host>.ngrok-free.app/"
```

You should see `ok` and a JSON NIP-11 document.

### What the NIP-11 JSON means

The JSON at the relay root is the expected NIP-11 information document. Important fields:

- `self` — the relay's signing pubkey. Clients verify group metadata and membership events against it.
- `supported_nips` — protocol features implemented by the relay.
- `auth_required: true` — WebSocket clients must complete NIP-42 AUTH before subscribing or publishing.
- `restricted_writes: true` — only authorized pubkeys may publish events.

## 7. Optional: run the HackerNews agent

### 7.1 Add the `web_fetch` MCP tool

The guide assumes the repo contains the small `web_fetch` tool in `buzz-dev-mcp` and the HackerNews persona pack. If you are following from a clean checkout, add these files first:

- `crates/buzz-dev-mcp/src/web_fetch.rs`
- the persona pack under `packs/hacker-news/`

Then rebuild:

```bash
cargo build --release -p buzz-cli -p buzz-agent -p buzz-acp -p buzz-dev-mcp
```

### 7.2 Create an agent keypair

```bash
uv venv /opt/buzz-venv
uv pip install --python /opt/buzz-venv/bin/python coincurve

/opt/buzz-venv/bin/python - <<'PY'
import coincurve, secrets
priv = secrets.token_hex(32)
pub = coincurve.PrivateKey(bytes.fromhex(priv)).public_key.format(compressed=False)[1:33].hex()
print(f"AGENT_PRIVATE_KEY={priv}")
print(f"AGENT_PUBKEY={pub}")
PY
```

Append the output to your repo-root `.env` (never commit it).

### 7.3 Add the agent as a relay and channel member

Use the relay owner key for these commands.

```bash
export PATH="$PWD/target/release:$PATH"
export BUZZ_RELAY_URL="https://<host>.ngrok-free.app"
export BUZZ_PRIVATE_KEY=<owner-private-key>

# Add to relay membership
cd deploy/compose
./run.sh add-member <AGENT_PUBKEY> --role member

# Create a channel
buzz channels create --name agents --type stream --visibility open
# -> note the returned channel_id

# Add the agent to the channel
buzz channels add-member \
  --channel <channel_id> \
  --pubkey <AGENT_PUBKEY> \
  --role bot
```

### 7.4 Write the agent system prompt

Create `/tmp/hacky-prompt.txt`:

```text
You are hacky, a Buzz agent that fetches the latest HackerNews stories.

When someone asks for news:
1. Use the `web_fetch` tool to GET `https://hacker-news.firebaseio.com/v0/topstories.json`.
2. Parse the JSON array of story IDs and take only the first 2.
3. For each ID, call `web_fetch` to GET `https://hacker-news.firebaseio.com/v0/item/{id}.json`.
4. Extract `title`, `url`, `score`, and `by` from each item.
5. Use the `shell` tool to run `sleep 10` so the user can see the agent working / loading state.
6. Post a concise one-line summary per story back to the channel using the `shell` tool:
   buzz messages send --channel <channel_id> --content "your summary here"

Keep the summary very short. If the API call fails, report the error.
```

Replace `<channel_id>` with the UUID created in the previous step.

### 7.5 Start the ACP harness

A helper script is provided at `/root/buzz/run-hacky.sh`. It reads the generated keys and DeepSeek config from the repo-root `.env` and starts `buzz-acp`.

```bash
cd /root/buzz
chmod +x run-hacky.sh
nohup ./run-hacky.sh > /tmp/hacky-start.log 2>&1 &
disown
```

Wait a few seconds, then confirm it discovered the channel:

```bash
tail -n 20 /tmp/hacky-acp.log
```

You should see `discovered 1 channel(s)` and `subscribed to channel <channel_id>`.

### 7.6 Mention the agent

```bash
buzz messages send \
  --channel <channel_id> \
  --content "@hacky news" \
  --mention <AGENT_PUBKEY>
```

The agent will fetch 2 stories, wait 10 seconds, and post the summaries. Watch the loading indicator in the channel, then check the result:

```bash
buzz --format compact messages get --channel <channel_id> --limit 10
```

### 7.7 Register `hacky` in the desktop app

ACP agents respond to mentions but do not automatically appear in the desktop **Agents** page. To show `hacky` there, send a desktop agent draft:

```bash
export BUZZ_PRIVATE_KEY=$AGENT_PRIVATE_KEY
export BUZZ_AUTH_TAG=$(/opt/buzz-venv/bin/python - <<'PY'
import hashlib, json, os
from coincurve import PrivateKey

owner_hex = os.environ['RELAY_OWNER_PUBKEY']  # owner pubkey hex
agent_priv = os.environ['AGENT_PRIVATE_KEY']
agent_pub = PrivateKey.from_hex(agent_priv).public_key.format(compressed=False)[1:33].hex()
preimage = f"nostr:agent-auth:{agent_pub}:"
digest = hashlib.sha256(preimage.encode()).digest()
sig = PrivateKey.from_hex(os.environ['BUZZ_RELAY_PRIVATE_KEY']).sign_schnorr(digest, None).hex()
print(json.dumps(["auth", owner_hex, "", sig]))
PY
)

buzz agents draft-create \
  --channel <channel_id> \
  --display-name hacky \
  --system-prompt "Fetch the latest 2 HackerNews stories and summarize them briefly when asked."
```

> On a closed-membership relay, the agent-owner mapping is not auto-materialized. If `draft-create` fails with `observer frame is not authorized for this agent owner`, set it directly in Postgres:
>
> ```bash
> cd deploy/compose
> docker compose exec -T postgres psql -U buzz -d buzz -c "
> UPDATE users
> SET agent_owner_pubkey = decode('<owner-pubkey-hex>','hex')
> WHERE community_id = (SELECT id FROM communities WHERE host = '<host>.ngrok-free.app')::uuid
>   AND pubkey = decode('<agent-pubkey-hex>','hex');
> "
> ```
>
> Then retry `buzz agents draft-create`.

After the draft is sent, open Buzz Desktop → **Agents**, review the `hacky` draft, and save it. `hacky` will then appear in the Agents page.

## 8. Operations

### Start / stop

```bash
cd deploy/compose
./run.sh start
./run.sh stop
./run.sh logs
```

### Stop ngrok

```bash
pkill ngrok
```

### Re-deploy with a new tunnel URL

If you restart ngrok without a static domain, the public URL changes. Re-run `./deploy/compose/deploy-ngrok.sh` and update any clients.

For a stable URL, reserve a static ngrok domain and add this to `.env` before running the deploy script:

```bash
NGROK_STATIC_DOMAIN=<your-domain>.ngrok-free.app
```

### Security notes

- Keep `.env` and `deploy/compose/.env` private and backed up.
- Do not commit them; they are already gitignored.
- The default `BUZZ_IMAGE=ghcr.io/block/buzz:main` tracks the latest pre-release build. Pin to a SHA or semver tag for anything production-like.

## Files introduced by this workflow

| File | Purpose |
|------|---------|
| `deploy/compose/deploy-ngrok.sh` | One-command VPS bootstrap + ngrok deployment |
| `docs/guides/self-host-vps-ngrok.md` | This guide |
| `crates/buzz-dev-mcp/src/web_fetch.rs` | MCP tool that lets agents read public HTTP/HTTPS APIs |
| `packs/hacker-news/` | Example persona pack for the HackerNews agent |

## Gotchas and things to watch out for

- **Non-interactive apt installs can hang** on package-configuration dialogs (e.g., "Pending kernel upgrade"). Set `DEBIAN_FRONTEND=noninteractive` before `apt install`.
- **Docker Compose v2.24.4+ is required** if you later enable the bundled Caddy TLS overlay (`BUZZ_COMPOSE_TLS=true`), because the overlay uses the `!reset` tag.
- **Rust first build is slow.** Hermit downloads the Rust toolchain and Cargo fetches all dependencies; expect several minutes and a few hundred megabytes.
- **Use uv, not system pip.** Ubuntu marks Python as externally managed, so `pip install` will fail. The guide uses `uv venv` + `uv pip install`.
- **Hex secrets only.** The relay builds `DATABASE_URL` and `REDIS_URL` from the raw password. Base64 passwords can contain `/`, which breaks URL parsing (`invalid port number`). The bootstrap script generates hex secrets to avoid this.
- **Free ngrok URLs are dynamic.** Every tunnel restart may give a new public URL. Reserve a static ngrok domain for a stable link.
- **Only one free ngrok tunnel at a time.** Stop any existing `ngrok` process before starting the deployment script.
- **Relay membership is enforced.** Any pubkey that wants to publish (owner, agent, user) must be added as a relay member first. Owners are added by the bootstrap script; agents must be added manually.
- **Channel membership matters for agents.** `buzz-acp` only subscribes to channels where the agent pubkey is already a member. Add the agent to the channel, then restart the harness.
- **Use the public URL for CLI and ACP.** Commands against `http://localhost:3000` fail with `no community is configured for this host` because the relay seeds its community from the public `RELAY_URL` host.
- **CORS is strict when set.** If you later serve a web client from a different origin, add it to `BUZZ_CORS_ORIGINS`.
- **`buzz-agent` has no built-in tools.** It routes every tool call through the MCP server (`buzz-dev-mcp`). If a tool is missing, the agent cannot perform that action.
- **LLM provider env vars must reach the agent child.** `buzz-acp` spawns `buzz-agent` with a sanitized environment. Pass `BUZZ_AGENT_PROVIDER`, `OPENAI_COMPAT_API_KEY`, etc. explicitly, not just via `source .env`.
- **DeepSeek uses the OpenAI-compatible endpoint.** Set `OPENAI_COMPAT_BASE_URL=https://api.deepseek.com/v1` and `OPENAI_COMPAT_MODEL=deepseek-chat`.
- **No inbound firewall ports needed.** ngrok opens an outbound tunnel, so you do not need to open 80/443/3000 on the VPS firewall.
- **Port 3000 must be free locally.** The relay binds `0.0.0.0:3000`; ngrok forwards to that port.
- **`:main` image tag is mutable.** Pin to a SHA or semver tag for anything beyond a demo.
- **Back up `.env` before upgrades.** It contains irreplaceable relay keys and database credentials.

## Sharing with peers

By default the relay root `/` returns the NIP-11 JSON document and the bundled web UI is not exposed. To let peers open Buzz in a browser and join the relay, do two things:

### 1. Enable the web UI

Add to `deploy/compose/.env`:

```bash
BUZZ_SERVE_GIT_WEB_GUI=true
```

Restart the relay:

```bash
cd deploy/compose
./run.sh restart
```

Now `https://<host>.ngrok-free.app/` serves the web app HTML.

### 2. Mint an invite

New pubkeys are rejected with `restricted: not a relay member` until they are added to relay membership. The cleanest way to onboard peers is an invite claim link.

`buzz-cli` does not have an invite subcommand, so mint one via the authenticated HTTP API. The endpoint requires a NIP-98 (kind:27235) signed auth event from an owner/admin key.

Install `pynostr` in the uv venv:

```bash
uv pip install --python /opt/buzz-venv/bin/python pynostr
```

Run:

```bash
/opt/buzz-venv/bin/python - <<'PY'
import base64, hashlib, json, os, time
import requests
from pynostr.key import PrivateKey
from pynostr.event import Event

owner_hex = os.environ['BUZZ_PRIVATE_KEY']  # owner 64-hex private key
host = '<host>.ngrok-free.app'
path = '/api/invites'
url = f'https://{host}{path}'

body = json.dumps({'ttl_secs': 259200, 'max_uses': 10})  # 72h, 10 uses
body_bytes = body.encode()
payload_hash = hashlib.sha256(body_bytes).hexdigest()

event = Event(
    kind=27235,
    content='',
    pubkey=PrivateKey.from_hex(owner_hex).public_key.hex(),
    created_at=int(time.time()),
    tags=[['u', url], ['method', 'POST'], ['payload', payload_hash]],
)
event.sign(owner_hex)

auth = 'Nostr ' + base64.b64encode(json.dumps(event.to_dict()).encode()).decode()

r = requests.post(
    url,
    data=body_bytes,
    headers={
        'Host': host,
        'Content-Type': 'application/json',
        'Authorization': auth,
    },
)
print(r.json()['url'])
PY
```

Share the printed `https://<host>.ngrok-free.app/invite/<code>` link with peers. When they open it and claim, they become relay members and can connect from the desktop or web client.

## Connecting the desktop app

1. Install Buzz desktop from the link on the invite page or from GitHub releases.
2. Open the app and choose **"Use an existing key"**.
3. Paste your owner **nsec** (from `/root/buzz/.env` as `OWNER_NSEC`).
4. When asked for the community URL, paste the relay WebSocket URL:
   ```
   wss://<host>.ngrok-free.app
   ```
5. The app connects. If it says `Load failed` / `not a relay member`, the desktop created a **new identity** instead of using the owner key. Find the new pubkey in the error or on the onboarding screen (e.g., `npub1...`) and add it from the server:
   ```bash
   cd deploy/compose
   ./run.sh add-member <desktop-pubkey-hex> --role member
   ```
   Then restart/refresh the desktop app.

## Where is my ACP agent in the desktop app?

The `hacky` agent built above is an **ACP agent**: it runs as a server-side process and responds to `@hacky` mentions in channels. It does **not** automatically appear in the desktop **Agents** page.

The desktop Agents page shows:

- Built-in default agents (`Fizz`, `Honey`, `Pollen`, `Welcome Team`).
- Agents created or saved through the desktop UI.
- Persona packs installed in the desktop app data directory.

To make `hacky` appear in the desktop app, follow step **7.7** and save the draft in Buzz Desktop → **Agents**.

## Troubleshooting

**Relay container fails with "invalid port number"**

Database or Redis passwords contained URL-unsafe characters (e.g., `/` from base64). The bootstrap script now generates hex secrets to avoid this.

**CLI commands fail with "no community is configured for this host"**

The relay seeds its community from the public `RELAY_URL` host. Use the public ngrok HTTPS URL in `BUZZ_RELAY_URL`, not `http://localhost:3000`.

**ACP says "discovered 0 channel(s)"**

The agent pubkey must be a member of the channel before `buzz-acp` starts. Add it with `buzz channels add-member`, then restart the harness.

**Agent does not respond to mentions**

- Confirm `buzz-acp` is subscribed to the channel in its logs.
- Confirm your message includes a `--mention <AGENT_PUBKEY>` tag.
- Confirm `--respond-to` is set to a mode that includes your pubkey (`owner-only` requires `--agent-owner`).
- Check `/tmp/buzz-acp.log` for LLM errors or MCP tool failures.

**Agent replies but the HackerNews data looks wrong**

- Verify `web_fetch` returned real JSON from `https://hacker-news.firebaseio.com/v0/topstories.json`.
- The LLM may hallucinate titles/URLs if the prompt is ambiguous. Make the system prompt explicit about parsing the JSON array and fetching each item.

## See also

- `deploy/compose/README.md`
- `crates/buzz-cli/TESTING.md`
- `crates/buzz-acp/src/config.rs` for all ACP environment variables
