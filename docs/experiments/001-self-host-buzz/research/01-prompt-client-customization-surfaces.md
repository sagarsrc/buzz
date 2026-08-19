---
topic: "client-customization-surfaces"
experiment: 001-self-host-buzz
created: "2026-08-19 10:23 UTC"
---

# Research prompt

Identify non-frontend customization surfaces for a client-specific self-hosted Buzz offering.

Scope:
- focus on capabilities, features, policies, deployment model, auth/provisioning, agent surfaces, admin/operator surfaces
- avoid visual/theming customization focus except where operationally relevant
- distinguish config-level vs deployment-level vs code-level customization
- produce practical guidance for first client offering

Primary sources:
- `README.md`
- `ARCHITECTURE.md`
- `VISION*.md` where relevant
- `deploy/compose/*`
- `deploy/charts/buzz/*`
- `docs/admin/README.md`
- relay env/config docs
- invite/admin/operator APIs
- `crates/buzz-cli/README.md` and agent-related crates if needed

Expected output:
1. customization surfaces
2. config vs deployment vs code split
3. easy / medium / hard matrix
4. recommended scope for first client offering
5. risks and hidden costs
