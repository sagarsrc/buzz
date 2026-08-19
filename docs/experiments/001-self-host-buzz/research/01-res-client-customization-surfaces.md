---
topic: "client-customization-surfaces"
experiment: 001-self-host-buzz
created: "2026-08-19 10:23 UTC"
---

# Buzz — non-frontend customization surfaces for client-specific self-hosted offering

## Executive summary

Client customization is possible today mostly through:
- deployment topology
- relay policy/config
- membership/provisioning model
- agent/persona/workflow layer
- operator/admin surfaces

Best first-client customization scope is **not UI theming**. Best scope is:
- dedicated deployment shape
- client-specific policy and onboarding
- client-specific agent personas/prompts/workflows
- storage/auth/ops posture

Deep feature customization exists, but quickly becomes fork-level work.

## 1) Customization surfaces

### A. Deployment topology

**Single-node / VPS Compose**
- `deploy/compose/compose.yml`
- `deploy/compose/compose.caddy.yml`
- `deploy/compose/run.sh`
- `deploy/compose/README.md`

Good for:
- one client / one deployment
- simpler ops
- fastest launch

**Helm / Kubernetes / GitOps**
- `deploy/charts/buzz/values.yaml`
- `deploy/charts/buzz/README.md`
- `deploy/charts/buzz/examples/*`

Good for:
- external Postgres / Redis / S3
- HA
- GitOps-managed clients
- more serious production posture

**Optional push gateway**
- `deploy/charts/buzz-push-gateway/*`
- `docs/push-gateway-deployment.md`

Only needed if client needs iOS push delivery.

---

### B. Relay behavior / policy

Primary evidence:
- `.env.example`
- `crates/buzz-relay/src/config.rs`

Configurable surfaces include:
- auth / admission mode
  - `BUZZ_REQUIRE_AUTH_TOKEN`
  - `BUZZ_REQUIRE_RELAY_MEMBERSHIP`
  - `BUZZ_PUBKEY_ALLOWLIST`
  - `BUZZ_ALLOW_NIP_OA_AUTH`
  - `RELAY_OWNER_PUBKEY`
- legal / join policy docs
  - `BUZZ_TERMS_OF_SERVICE_MARKDOWN`
  - `BUZZ_PRIVACY_POLICY_MARKDOWN`
  - `BUZZ_AGE_ATTESTATION_REQUIRED`
- rate limits
  - `BUZZ_RATE_LIMIT_HUMAN_*`
  - `BUZZ_RATE_LIMIT_AGENT_*`
- media policy
  - `BUZZ_MAX_FILE_BYTES`
  - `BUZZ_MEDIA_*`
  - `BUZZ_S3_*`
- git hosting policy / limits
  - `BUZZ_GIT_MAX_PACK_BYTES`
  - `BUZZ_GIT_MAX_REPO_BYTES`
  - `BUZZ_GIT_MAX_REPOS_PER_PUBKEY`
- ephemeral channel policy
  - `BUZZ_EPHEMERAL_TTL_OVERRIDE`
  - `BUZZ_REAPER_INTERVAL_SECS`
- observability / audit
  - `RUST_LOG`
  - `BUZZ_OTEL_FILTER`
  - `OTEL_EXPORTER_OTLP_ENDPOINT`
  - `BUZZ_STORAGE_METRICS`
  - `BUZZ_AUDIT_ENABLED`
- huddle availability
  - `BUZZ_HUDDLE_AUDIO_AVAILABLE`

Also operational branding exists via workspace profile update event:
- `crates/buzz-core/src/kind.rs` (`RELAY_ADMIN_SET_WORKSPACE_PROFILE`, kind 9033)
- `crates/buzz-relay/src/nip11.rs`

This affects relay identity/name/icon, not deep product theming.

---

### C. Auth / provisioning / membership model

**Operator / community provisioning API**
- `crates/buzz-relay/src/api/operator.rs`
- `crates/buzz-relay/src/router.rs`
- `docs/multi-tenant-relay.md`
- `docs/multi-tenant-conformance.md`

Surfaces:
- provision community
- archive / unarchive / transfer
- host availability
- operator-controlled multi-community management

**Invites / claim flow**
- `crates/buzz-relay/src/api/invites.rs`
- `crates/buzz-relay/src/api/invite_token.rs`

Surfaces:
- invite-based onboarding
- invite TTL / usage controls
- join-policy acceptance

**Membership admin**
- `crates/buzz-admin/src/main.rs`
- kind 9030–9032 / kind 13534 roster model

Surfaces:
- owner/admin/member admission
- allowlist / closed relay posture

---

### D. Agent surfaces

Biggest client-specific leverage.

**ACP harness**
- `crates/buzz-acp/*`
- `.env.example` ACP section

Configurable via many `BUZZ_ACP_*` env vars:
- agent binary
- model choice
- system prompt / prompt file
- subscription mode
- channel scoping
- respond-to allowlists
- heartbeat / timeout / effort level
- memory on/off
- MCP sidecar

**buzz-agent**
- provider / model / prompt / caps
- `VISION_AGENT.md`

**Persona packs**
- `crates/buzz-persona/src/pack.rs`
- persona pack directories with prompts, MCP config, skills

**Workflows**
- `crates/buzz-workflow/*`
- `buzz-cli` workflow commands
- webhook triggers / YAML-as-code

Practical customization for clients:
- custom agent team
- custom prompts
- client-specific workflow automation
- scoped agent permissions and channels

---

### E. Operator / admin surfaces

**Admin dashboard**
- `docs/admin/README.md`
- `crates/buzz-relay/src/api/admin/*`
- `admin-web/*`

Current role:
- read-only moderation / feedback dashboard
- private ingress / private host pattern

**Operator CLI / admin CLI**
- `crates/buzz-admin/src/main.rs`
- `crates/buzz-cli/README.md`

Practical customization:
- member operations
- migrations
- deletions / cleanup
- repo protections
- workflow / channel / memory automation via CLI

## 2) Config-level vs deployment-level vs code-level

| Layer | What fits here | Evidence |
|---|---|---|
| Config-level | auth mode, join policy docs, media limits, git limits, audit, OTel, agent prompts/personas, workflow YAML, feature flags | `.env.example`, `crates/buzz-relay/src/config.rs`, `deploy/charts/buzz/values.yaml` |
| Deployment-level | Compose vs Helm, single-node vs HA, bundled vs external PG/Redis/S3, ingress/TLS, private admin ingress, operator pubkeys, backup model, push gateway inclusion | `deploy/compose/README.md`, `deploy/charts/buzz/README.md`, `docs/push-gateway-deployment.md` |
| Code-level | new event kinds, new relay features, changed auth model, new admin model, mobile/web/desktop feature work, multi-pod huddle audio, deep multi-tenant productization | `AGENTS.md`, `docs/admin/README.md`, `buzz-core/src/kind.rs` |

## 3) Easy / Medium / Hard matrix

| Customization | Effort | Why |
|---|---|---|
| Relay name/icon/join policy docs | Easy | config or workspace-profile event |
| Closed membership + invites | Easy | built-in relay/admin flows |
| Media / rate / git limit tuning | Easy | env-only |
| Client agent personas/models/prompts | Easy | `BUZZ_ACP_*`, persona packs |
| Client workflows / automations | Easy | YAML + webhook / CLI |
| External S3 / PG / Redis / TLS / backups | Medium | infra + runbooks |
| Per-client community on shared relay | Medium | operator API + DNS/host mapping |
| Admin dashboard setup | Medium | private ingress + host routing |
| Push notifications / push gateway | Medium-Hard | extra service, Apple credentials, key management |
| New event kinds / new relay capabilities | Hard | code + migrations + client sync |
| Per-operator authenticated admin surface | Hard | current design does not provide this |
| Multi-pod huddle audio / SFU path | Hard | not built |

## 4) Recommended scope for first client offering

### Recommended
1. **Dedicated deployment per client**
   - Helm production tier for serious clients
   - Compose for smaller/simple clients
2. **Policy + onboarding customization**
   - closed membership
   - invite flow
   - join policy / privacy / ToS text
3. **Agent/workflow customization**
   - custom persona pack
   - custom prompts
   - client-specific agent team
   - seed workflows
4. **Ops bundle**
   - backups
   - monitoring / OTel
   - `buzz-admin` runbooks
   - pinned image tags
5. **Workspace identity**
   - relay name / description / icon

### Defer initially
- shared multi-tenant relay across many clients
- push gateway unless clearly required
- admin dashboard as compliance-grade control plane
- feature forks / new event kinds
- mobile-heavy customization

## 5) Risks and hidden costs

### Multi-tenant maturity risk
- `docs/multi-tenant-relay.md` is still marked `draft`
- isolation model is serious, but operational posture for commercial shared-hosting is still young

### Identity / key risk
- relay private key rotation changes relay identity
- owner transfer is real operator operation, not lightweight setting
- this needs explicit handoff/runbook

### Compose limitations
- Compose bundle is opinionated around bundled MinIO/path-style addressing
- external object-store shape cleaner in Helm than stock Compose

### Migration / upgrade discipline
- `BUZZ_AUTO_MIGRATE` exists, but client upgrade ordering still matters
- Helm pre-upgrade migration job path should be used for controlled environments

### Push gateway overhead
- Apple App Attest, AEAD keyrings, dedicated DB, rotation discipline
- only worth it if client truly needs iOS push

### Admin trust boundary gap
- admin dashboard today is private-ingress style, not full per-operator audited control plane
- some clients will demand stronger accountability

### Kind-registry coupling
- code-level feature forks require synced event-kind definitions across relay, desktop, and mobile
- drift cost rises quickly

### Operational fine print
- same-second member-add collisions documented in `buzz-admin`
- huddle audio currently single-pod oriented
- deploy reconnect behavior needs tuning (`drainJitterMs`) for smoother rolling deploys

## Bottom line

For client-specific self-hosted Buzz, strongest customization surfaces today are:
- deployment model
- relay policy / provisioning
- agent personas / prompts / workflows
- operator controls and infra posture

Weakest current area for client customization is **deep product feature branching**. That turns into forked Rust + client sync work quickly.

Best first offer:
- one client, one deployment
- client-specific policy + onboarding
- client-specific agents/workflows
- pinned release + real ops runbook
