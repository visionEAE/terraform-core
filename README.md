# terraform-core

The **disposable** half of the Student 360° infrastructure: Cloud Run services, Cloud SQL,
networking, the DWH feed and the bastion. Everything here can be destroyed and rebuilt from zero
against [`terraform-backend`](https://github.com/visionEAE/terraform-backend)'s outputs, consumed
through remote state as a published contract.

## Shape

- **7 Cloud Run services** (`s360-auth`, `s360-gateway`, `s360-core`, `s360-lms`, `s360-support`,
  `s360-network`, `s360-web`) + **1 job** (`s360-relay`). Terraform owns the *shape* — env,
  secrets, probes, scaling, identity; the pipelines own *which build is live*
  (`ignore_changes` on the image).
- **Privacy by IAM, not ingress**: only gateway, auth and web carry `allUsers`; every internal
  service lists its callers as `run.invoker` members. `ingress=internal` was rejected — it would
  force all-traffic VPC egress on the callers (Cloud NAT money) and break direct egress to AuraDB.
- **No URL cycles**: every service's deterministic URL
  (`https://<name>-<project-number>.<region>.run.app`) is computed in `locals.run_url`, so the
  gateway gets its five downstream URLs — and each callee its own audience — at creation.
- **Cloud SQL** PG16, private IP only, reached via Direct VPC egress (no connector, no NAT). One
  instance, one schema per service, the same layout `student360-infra/infra/init-db` creates
  locally. Roles are Terraform (`google_sql_user`, passwords from Secret Manager); schemas,
  ownership and the append-only audit table are `scripts/sql/db-init.sql`, run once through the
  bastion.
- **DWH feed**: outbox → `s360-relay` (Cloud Run job, Cloud Scheduler every 5 min) → Pub/Sub
  `student360-events` → BigQuery subscription → `student360_dwh.outbox_events` (dataset lives in
  terraform-backend: accumulated events are irrecoverable).
- **Bastion**: stopped-by-default e2-micro, no external IP, IAP-only SSH, tunnel on
  `localhost:15432`.

## Scripts

```bash
scripts/bootstrap.sh [ws]      # first bring-up: targeted apply → prompts for db-init → full apply
scripts/bastion.sh up|down|status
scripts/db-init.sh             # schemas + audit table + relay grants (idempotent)
scripts/deploy.sh push|roll|all [svc…]   # workstation build+push+roll BY DIGEST (bootstrap/emergencies)
```

## First-apply asymmetry

The six Java images must be **real** before the first full apply (a placeholder fails the
`/actuator/health` startup probe and aborts); `s360-web` and `s360-relay` start from Google's
`hello` image — web's real bundle needs the gateway URL this very apply creates, and nothing
probes the relay. Their own pipelines roll the real images right after.
