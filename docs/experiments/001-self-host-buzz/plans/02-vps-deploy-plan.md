---
title: "vps-deploy-plan"
experiment: 001-self-host-buzz
created: "2026-08-19 12:59 UTC"
---

# Buzz VPS self-host deployment plan

## Goal

Deploy Buzz from `/root/buzz` on the Contabo VPS and expose it through a public HTTPS link via ngrok.

## Current state

- VPS: Ubuntu 24.04 LTS, x86_64, 11 GB RAM, 193 GB disk, root shell.
- Public IP: `169.58.204.20`.
- Repo: `/root/buzz` present.
- **Docker and Docker Compose are not installed.**
- **ngrok is not installed.**
- No `deploy/compose/.env` exists yet.
- No Nostr keypair generated yet.

## Deployment shape

- Single community, single-node.
- Use `deploy/compose/compose.yml` directly (no Caddy TLS overlay).
- Relay serves plain HTTP on `localhost:3000`.
- ngrok terminates HTTPS and forwards to `localhost:3000`.
- `RELAY_URL`, `BUZZ_MEDIA_BASE_URL`, and `BUZZ_CORS_ORIGINS` must point at the ngrok tunnel hostname before the relay starts.

## Blocker before execution

**An ngrok authtoken is required.** Provide it when asked; the rest of the work can proceed only after the token is configured.

## Phases

### Phase 1 — Install prerequisites

1. Update apt and remove any conflicting docker packages.
2. Add Docker's official apt repository for Ubuntu 24.04.
3. Install `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`.
4. Enable and start `docker` service.
5. Verify with `docker --version`, `docker compose version`, `docker run hello-world`.
6. Download ngrok v3 Linux amd64 tarball to `/usr/local/bin`.
7. Add ngrok authtoken via `ngrok config add-authtoken <TOKEN>`.
8. Verify with `ngrok version`.
9. Install a lightweight Nostr pubkey tool (`nak` or `coincurve`) for deriving the owner pubkey.

### Phase 2 — Bootstrap configuration

1. Copy `deploy/compose/.env.example` to `.env`.
2. Generate stable 64-hex relay private key and derive `RELAY_OWNER_PUBKEY`.
3. Generate random secrets for Postgres, Redis, S3, git HMAC.
4. Set `BUZZ_IMAGE=ghcr.io/block/buzz:main` (acceptable for this demo; for production pin to a SHA or semver tag).
5. Run a throwaway ngrok tunnel once to discover the public URL, then:
   - `BUZZ_DOMAIN=<ngrok-host>`
   - `RELAY_URL=wss://<ngrok-host>`
   - `BUZZ_MEDIA_BASE_URL=https://<ngrok-host>/media`
   - `BUZZ_CORS_ORIGINS=https://<ngrok-host>`
6. Render config with `./run.sh config` to validate no `CHANGE_ME` placeholders remain.
7. Print and persist secrets for backup.

### Phase 3 — Start Buzz stack

1. `./run.sh start`.
2. Wait for all services healthy (`relay`, `postgres`, `redis`, `minio`, `minio-init`).
3. Check `/_liveness` and `/_readiness`.

### Phase 4 — Public tunnel

1. Start `ngrok http 3000` (or `ngrok http --url=<static> 3000` if a static domain is available).
2. Capture the public URL from `http://127.0.0.1:4040/api/tunnels`.
3. Share the public `wss://...` and `https://...` links with the user.

### Phase 5 — Validation

1. `curl -fsS https://<ngrok>/_liveness` returns 200.
2. `curl -fsS -H "Accept: application/nostr+json" https://<ngrok>/` returns NIP-11 JSON.
3. WebSocket smoke test with `websocat` or `wscat` to `wss://<ngrok>`.
4. Verify `buzz-cli` can connect and run a read-only command (e.g., `channels list`).
5. Verify media upload endpoint responds (auth may be needed; at least confirm the route is reachable).
6. Verify git Smart HTTP endpoint presence.

### Phase 6 — Handover

1. Provide the public relay URL.
2. Provide the owner pubkey and private key backup.
3. Provide `.env` backup contents.
4. Document how to stop/start (`./run.sh stop`, `./run.sh start`).
5. Document how to re-create the ngrok link after a reboot or tunnel restart.

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Dynamic ngrok URL changes on restart | Use a static ngrok domain if available; otherwise document that the link is ephemeral. |
| `RELAY_URL` mismatch breaks NIP-42 AUTH / NIP-11 | Always set `RELAY_URL` to the public tunnel URL before starting the relay. |
| ngrok rewrites `Host` to `localhost:3000` | ngrok normally preserves the public hostname; if not, seed `localhost:3000` community or use `--host-header=rewrite <host>`. |
| Relay membership required before first user | Use `./run.sh add-member` with owner/admin pubkey; use invite flow for additional users. |
| CORS blocks browser requests | Include the ngrok origin in `BUZZ_CORS_ORIGINS`. |
| Secrets lost on rebuild | Back up `.env` and the owner private key immediately. |

## Sub-agent assignments

- **Agent A — prerequisites**: produce exact apt + Docker + ngrok install commands. *(completed)*
- **Agent B — relay env mapping**: confirm how `RELAY_URL`, media, CORS, and host seeding work. *(completed)*
- **Agent C — bootstrap script**: produce `deploy/compose/bootstrap.sh` for secrets + ngrok URL wiring. *(completed)*
- **Agent D — validation checklist**: produce exact health/WebSocket/CLI/media/git verification commands. *(to be regenerated)*

## Verification success criteria

- All Compose services show `healthy`.
- `curl https://<ngrok>/_liveness` returns 200.
- NIP-11 JSON served at `GET /`.
- `wss://<ngrok>` accepts a WebSocket upgrade.
- `buzz-cli` can list channels against the public URL.

## Next action

Ask the user for the ngrok authtoken, then begin Phase 1.
