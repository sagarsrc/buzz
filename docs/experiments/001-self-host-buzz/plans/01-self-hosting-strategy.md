---
title: "self-hosting-strategy"
experiment: 001-self-host-buzz
created: "2026-08-19 09:41 UTC"
---

# Buzz self-hosting strategy

## Goal

Figure out practical path to offer Buzz as self-hosted product on VPS, based on current repo state.

## Executive take

Yes, self-hosting support exists now.

Best current path:
- **Single-community, single-node VPS**
- **Docker Compose bundle in `deploy/compose/`**
- **Desktop-first product surface**
- **CLI/agent support included**
- **Web surface limited; not full browser workspace yet**

Do **not** position current repo as polished multi-tenant hosted SaaS or compliance-heavy enterprise platform without extra work.

## What exists today

### Deployment artifacts

- **Prod-ish VPS bundle:** `deploy/compose/README.md`, `deploy/compose/compose.yml`, `deploy/compose/run.sh`
- **Optional TLS via Caddy:** `deploy/compose/compose.caddy.yml`, `deploy/compose/Caddyfile`
- **Kubernetes/Helm path:** `deploy/charts/buzz/README.md`
- **Public relay image:** `Dockerfile`, released as `ghcr.io/block/buzz:<tag>` per `RELEASING.md`
- **Dev-only compose:** root `docker-compose.yml`

### Product surfaces

- **Desktop app = primary full UX today** (`README.md`, `VISION.md`)
- **`buzz-cli` = usable agent/operator surface**
- **ACP/agent harness = usable**
- **Web = repo browser + invite flows, not full workspace parity**
- **Mobile = active development, not parity surface yet**

## Required runtime dependencies

Current Buzz is not single-binary-only in practice. Self-host needs:

- **Buzz relay container**
- **PostgreSQL**
- **Redis**
- **S3-compatible object store** (bundled MinIO in Compose)
- **Persistent git data volume**
- **Domain + TLS** for real deployment

Key config/secrets:
- `RELAY_URL`
- `BUZZ_RELAY_PRIVATE_KEY`
- `RELAY_OWNER_PUBKEY`
- `BUZZ_GIT_HOOK_HMAC_SECRET`
- Postgres creds
- Redis password
- S3/MinIO creds

Refs:
- `deploy/compose/.env.example`
- `deploy/compose/compose.yml`
- `ARCHITECTURE.md`

## Docker support

Yes.

### Available now

- **Dockerfile** builds production relay image with:
  - `buzz-relay`
  - `buzz-admin`
  - `buzz-pair-relay`
  - bundled web UI + admin web UI
  - `git`
- **Compose VPS bundle** for single-node deployment
- **Helm chart** for more serious/prod K8s deployments

### Important nuance

- Root `docker-compose.yml` = **dev only**
- `deploy/compose/` = **real self-host/VPS path**
- Compose bundle hard-wires bundled MinIO/path-style S3; external S3 needs Helm or custom Compose

## Recommended offering shape

### Phase 1 — realistic MVP

Sell Buzz as:
- **Self-hosted team workspace on one VPS**
- **One community per deployment**
- **Desktop-first app**
- **CLI + agent automation available**
- **Optional repo browser + invite flow via web**

Target user:
- small technical team
- willing to install desktop app
- comfortable with keys/ops
- okay with early-production posture

### Avoid promising in Phase 1

- full browser workspace parity
- mature mobile experience
- polished multi-tenant hosting
- enterprise-grade workflow approvals
- strong built-in abuse/rate limiting
- compliance-grade audit guarantees

## Deployment plan

### Option A — fastest path: single VPS via Compose

Use when:
- one customer/team per stack
- lowest ops complexity
- fastest launch

Plan:
1. Provision VPS
2. Set DNS: `buzz.customer-domain.com`
3. Install Docker Compose v2.24.4+
4. Copy `deploy/compose/.env.example` to `.env`
5. Generate stable secrets + owner keypair
6. Enable TLS with Caddy (`BUZZ_COMPOSE_TLS=true`)
7. Start with `deploy/compose/run.sh start`
8. Validate relay health, invite flow, desktop connection, media, git, CLI
9. Back up Postgres + MinIO + git volume + `.env` + owner key
10. Pin image to immutable tag, not `:main`

Pros:
- already supported by repo
- least engineering work
- easiest customer story

Cons:
- single-node only
- bundled infra
- weaker external service flexibility

### Option B — more serious prod path: Helm + managed services

Use when:
- want managed Postgres/Redis/S3
- want HA path later
- want GitOps/K8s ops model

Plan:
1. Use `deploy/charts/buzz/`
2. Supply external Postgres/Redis/S3
3. Use `secrets.existingSecret`
4. Expose `relayUrl` with real ingress/TLS
5. Keep one community per environment first
6. Add monitoring, backup, secret rotation, immutable upgrades

Pros:
- cleaner prod posture
- easier external infra integration
- better path to scale

Cons:
- more ops work
- not VPS-simple

## Operator workflow needed

### Bootstrap

- generate owner keypair
- set `RELAY_OWNER_PUBKEY`
- set stable `BUZZ_RELAY_PRIVATE_KEY`
- run migrations (`BUZZ_AUTO_MIGRATE=true` or `buzz-admin migrate`)
- add members with `buzz-admin`
- create invites for user onboarding

### Ongoing ops

- member admin via `buzz-admin`
- secret backup
- DB/object/git backups
- image upgrades
- relay health + metrics monitoring
- restore testing

## Product caveats / gaps

### Hard gaps

- Workflow approval gates incomplete
- Some workflow actions stubbed (`send_dm`, `set_channel_topic`)
- No real rate-limiting implementation
- Web not full workspace client
- Mobile not parity-ready

### Operational risks

- Mutable default image tag in Compose (`:main`)
- No LTS/support model beyond active `main`
- Backup/restore runbook thin
- TLS/proxy correctness left to operator
- Admin dashboard auth weak for managed ops
- Key management friction high

## What must be built before broad commercial self-host push

Priority order:

1. **Harden VPS install story**
   - bootstrap script for secret/key generation
   - better install docs
   - opinionated validation script

2. **Release discipline**
   - stable version pinning guidance
   - tested upgrade path
   - restore runbook

3. **Security hardening**
   - real rate limiting
   - front-door reverse-proxy guidance
   - admin surface auth story

4. **Operator UX**
   - easier onboarding/invite/member admin
   - maybe minimal operator console

5. **Product clarity**
   - explicit “desktop-first” self-host docs
   - explicit “single-community” docs

## Suggested go-to-market sequencing

### Stage 1

Offer:
- managed installation on customer VPS
- one domain
- one team/community
- desktop app required
- optional agent setup

### Stage 2

After hardening:
- managed object store support outside bundled MinIO
- stronger monitoring/backups
- cleaner onboarding
- better operator/admin UX

### Stage 3

Only after proof:
- multi-community hosting
- stronger enterprise posture
- browser-heavy usage story

## Verification checklist for first self-host pilot

- relay boots from immutable image tag
- desktop app connects over TLS
- invite claim works
- closed-membership mode works
- media upload/download works
- git clone/push works
- `buzz-cli` auth works
- ACP/agent auth works
- backup + restore tested
- upgrade tested on staging clone

## Bottom line

**Can Buzz be self-hosted on VPS today?** Yes.

**Best current answer:** use `deploy/compose/` for single-community, single-node, desktop-first deployments.

**Best product framing:** early self-host offering for technical teams, not broad polished SaaS replacement yet.

## Key source files

- `README.md`
- `VISION.md`
- `VISION_SOVEREIGN.md`
- `ARCHITECTURE.md`
- `RELEASING.md`
- `deploy/compose/README.md`
- `deploy/compose/compose.yml`
- `deploy/compose/.env.example`
- `deploy/charts/buzz/README.md`
- `Dockerfile`
