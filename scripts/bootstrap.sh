#!/usr/bin/env bash
# First-time terraform-core bring-up, in the order the dependencies demand:
#   1. network + database + identities (targeted apply)
#   2. database bootstrap (bastion + db-init) — schemas must exist before any service boots
#   3. push the six Java images (deploy.sh push) — real images must exist before the probes run
#   4. full apply
set -euo pipefail
cd "$(dirname "$0")/.."

WORKSPACE="${1:-prod}"

if grep -q "CHANGE-ME" backend.tf variables.tf; then
  echo "✗ backend.tf / variables.tf still carry the placeholder bucket name." >&2
  exit 1
fi

terraform init -input=false
terraform workspace select "${WORKSPACE}" 2>/dev/null || terraform workspace new "${WORKSPACE}"

echo "→ phase 1: network, database, identities"
terraform apply -input=false \
  -target=module.network \
  -target=module.cloudsql \
  -target=module.auth_sa -target=module.gateway_sa -target=module.core_sa \
  -target=module.lms_sa -target=module.support_sa -target=module.network_sa \
  -target=module.web_sa -target=module.relay_sa \
  -target=google_service_account.bastion \
  -target=google_compute_firewall.bastion_iap_ssh \
  -target=google_compute_instance.bastion \
  -target=google_secret_manager_secret_iam_member.bastion_pg_password

cat <<'MSG'

→ phase 2 (manual, once):
    scripts/bastion.sh up
    scripts/db-init.sh
→ phase 3 (manual, once): fill terraform.tfvars with the pushed images, after:
    scripts/deploy.sh push all
→ phase 4:
    terraform apply
MSG
