---
title: "selfhost-offering-onepager"
experiment: 001-self-host-buzz
created: "2026-08-19 10:42 UTC"
---

# Buzz self-hosted offering — one-pager

## TL;DR

Buzz is self-hostable now.

**Best current path:** one community on one VPS using `deploy/compose/`.

Helm exists for Kubernetes and managed infra, but adds operational complexity and is better treated as L2.

## Verdict

Self-host Buzz now, but sell it as early technical offering — not polished multi-tenant SaaS.

Strongest current shape:
- single-community
- single-node VPS
- desktop-first
- CLI + agent surfaces included

## L0 → L2

### L0 — evaluate
- local `just setup && just relay`
- Railway-style eval path
- prove model, not production posture

### L1 — single VPS / core offering
- `deploy/compose/`
- Postgres + Redis + MinIO + git volume
- optional Caddy TLS
- best first commercial path

### L2 — Helm / managed infra / HA
- `deploy/charts/buzz/`
- external Postgres / Redis / S3
- GitOps / HA posture
- more ops complexity

## What is required to self-host Buzz

### Infra / services
- Buzz relay image
- PostgreSQL
- Redis
- S3-compatible object store / MinIO
- persistent git storage
- domain + TLS termination

### Secrets / identity
- `BUZZ_RELAY_PRIVATE_KEY`
- `RELAY_OWNER_PUBKEY`
- `BUZZ_GIT_HOOK_HMAC_SECRET`
- Postgres credentials
- Redis password
- S3 / MinIO credentials

### Operational actions
- pin immutable image tag (`sha-...` or semver), not `:main`
- run migrations (`BUZZ_AUTO_MIGRATE=true` or `buzz-admin migrate`)
- provision members / invites
- back up DB + object store + git data + secrets + owner key

## Recommended path

- L0: evaluate locally / quickly
- L1: launch first self-host offer on one VPS per team
- L2: move to Helm only when managed services / HA / GitOps are hard requirements

Why L1 first:
- fastest route to real deployment
- least engineering beyond current repo path
- simplest failure domain
- avoids overselling multi-community and browser parity

## Agentic customization surfaces

If multi-agent services are core offering, strongest customization is agent layer.

### Roles
What agents exist per client:
- research agent
- triage / support agent
- reviewer agent
- release agent
- knowledge agent
- incident agent

### Routing
When agents engage:
- mention-driven
- channel-scoped
- event-scoped
- workflow-triggered
- allowlist / ownership rules

### Capability
What agents can do:
- messaging
- workflow control
- repo operations
- canvas / memory actions
- relay / CLI actions through MCP + `buzz-cli`

### Agent surfaces available for customization
- **Persona layer:** names, role definitions, prompts, MCP config, packaged skills, team composition
- **Model layer:** provider, model, effort, timeout, token caps, heartbeat, memory
- **Routing layer:** mentions vs all events, channel filters, allowlists, owner-only vs anyone
- **Workflow layer:** trigger rules, webhook integrations, approvals, YAML automations, escalations
- **Tooling layer:** MCP sidecars, shell/file tools, repo policy commands, CLI surfaces
- **Core feature layer:** new event kinds / relay behavior — fork work

### Easy vs expensive
**Easy**
- custom personas
- prompts
- models
- channel routing
- allowlists
- seed workflows
- memory defaults

**Medium**
- client-specific tool bundles
- MCP sidecars
- tighter workflow orchestration
- admin/operator runbooks around agent use

**Hard**
- new native agent capabilities
- new relay event kinds
- deep admin/auth changes
- product forks

### Recommended first-client agent offering
Sell:
- custom agent teams
- prompts
- tool access
- workflows

Standardize:
- base agent runtime
- per-client persona pack
- per-client routing / channel ownership
- per-client workflow bundle
- documented line between config customization and fork requests

## Enterprise agent features clients will kill for

### Approval-gated autonomy
Example: **release agent** drafts rollout, human approves in-channel, agent ships with full audit trail.

### Scoped permissions
Example: **support agent** can triage customer issues, but cannot touch prod workflows or protected repos.

### Persistent memory
Example: **incident agent** answers “have we seen this before?” with prior root causes, fixes, and owners.

### Incident swarm
Example: **incident agent** gathers logs, **comms agent** drafts updates, **follow-up agent** tracks actions, **status agent** updates thread.

### Release team
Example: **reviewer agent** checks diffs, **notes agent** drafts changelog, **approval agent** gates production push.

### Support triage team
Example: **intake agent** classifies ticket, **dedupe agent** links history, **escalation agent** routes to right team.

## Known blockers / gaps

### Product / platform
- workflow approval gates not wired end-to-end
- `send_dm` and `set_channel_topic` workflow actions stubbed
- web is not full workspace client
- mobile still maturing

### Security / ops
- no real rate limiting implementation yet
- Compose defaults to mutable `:main` image tag
- no clear LTS model; security support centered on active `main`
- backup/restore story is still thin

### Scope boundaries
- do not frame current offer as compliance-grade or enterprise-ready
- do not promise multi-tenant productization from day one
- do not promise minimal-mode single-binary deployment — Redis + S3 are real deps today

### Sovereignty tradeoffs
- operator owns infra, TLS, backups, upgrades
- key loss = identity loss
- onboarding friction exists because Nostr keys are real

## Decision matrix

| Axis | L0 | L1 | L2 |
|---|---|---|---|
| Goal | Prove concept | Launch first real self-host offer | Harden for ops scale |
| Infra | local / eval | bundled Postgres + Redis + MinIO + git volume | external Postgres + Redis + S3 + K8s |
| HA | no | no | yes |
| Best fit | founders exploring | small technical team, desktop-first | GitOps / platform-heavy org |
| Main caution | not production proof | must pin version + own backups | more moving parts than many early users need |

## Bottom line

Yes, Buzz can be self-hosted today.

Best current path:
- one community
- one VPS
- `deploy/compose/`
- custom agent teams / workflows as services layer

Do not lead with:
- generic “chat with AI”
- undifferentiated hosted-agent story
- custom core feature forks as default offer
