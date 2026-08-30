#!/usr/bin/env bash
# One-shot database bootstrap through the bastion tunnel: schemas, ownership, the append-only
# audit table and the relay grants (scripts/sql/db-init.sql, idempotent). Role creation is NOT
# here — Terraform's google_sql_user owns the roles and their Secret Manager passwords.
#
# Prereq: scripts/bastion.sh up
set -euo pipefail
cd "$(dirname "$0")/.."

WORKSPACE="${WORKSPACE:-prod}"
LOCAL_PORT="${LOCAL_PORT:-15432}"

echo "→ fetching the postgres password from Secret Manager"
PGPASSWORD="$(gcloud secrets versions access latest --secret="s360-${WORKSPACE}-postgres-password")"
export PGPASSWORD

echo "→ running db-init.sql against localhost:${LOCAL_PORT}"
psql -v ON_ERROR_STOP=1 -h localhost -p "${LOCAL_PORT}" -U postgres -d student360 -f scripts/sql/db-init.sql
echo "✓ database bootstrapped"
