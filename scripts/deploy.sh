#!/usr/bin/env bash
# Workstation build + push + roll, used for the FIRST deployment (the Java services must have
# real images before terraform apply can pass their startup probes) and as the manual escape
# hatch. Steady state belongs to the GitHub pipelines, which do the same thing keylessly.
#
#   scripts/deploy.sh push  [svc…|all]   build jars + images, push content-tagged (no roll)
#   scripts/deploy.sh roll  [svc…|all]   roll the running service to the freshly pushed digest
#   scripts/deploy.sh all   [svc…|all]   push + roll
#
# Deploy by digest, not by tag: a tag can be moved, and a revision that cannot name exactly what
# it is running cannot be rolled back with confidence.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-all}"; shift || true
REQUESTED=("${@:-all}")

REGISTRY="$(terraform output -raw artifact_registry_repo_url)"
REGION="${REGISTRY%%-docker.pkg.dev*}"
ROOT="$(cd .. && pwd)"

declare -A SERVICES=(
  [s360-auth]=student360-auth-service
  [s360-gateway]=student360-gateway
  [s360-core]=student360-core-service
  [s360-lms]=student360-lms-service
  [s360-support]=student360-support-service
  [s360-network]=student360-network-service
)

targets=()
if [ "${REQUESTED[0]}" = "all" ]; then
  targets=("${!SERVICES[@]}")
else
  targets=("${REQUESTED[@]}")
fi

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

echo "→ installing student360-common into ~/.m2"
mvn -q -f "${ROOT}/student360-common/pom.xml" -DskipTests install

declare -A DIGESTS=()
for svc in "${targets[@]}"; do
  repo="${SERVICES[$svc]:?unknown service ${svc}}"
  dir="${ROOT}/${repo}"
  tag="content-$( (cd "${dir}" && git rev-parse --short=12 HEAD) )-local"
  image="${REGISTRY}/${svc}"

  if [ "${MODE}" != "roll" ]; then
    echo "── ${svc}: building ${repo}"
    mvn -q -f "${dir}/pom.xml" -DskipTests package
    docker build -q -t "${image}:${tag}" -t "${image}:latest" "${dir}"
    docker push -q "${image}:${tag}"
    docker push -q "${image}:latest"
  fi
  digest="$(docker inspect --format='{{index .RepoDigests 0}}' "${image}:${tag}" 2>/dev/null || true)"
  [ -z "${digest}" ] && digest="$(gcloud artifacts docker images describe "${image}:${tag}" --format='value(image_summary.digest)' | sed "s|^|${image}@|")"
  DIGESTS[$svc]="${digest}"
  echo "   ${digest}"
done

if [ "${MODE}" != "push" ]; then
  for svc in "${targets[@]}"; do
    echo "── rolling ${svc}"
    gcloud run services update "${svc}" --region="${REGION}" --image="${DIGESTS[$svc]}" --quiet
  done
fi
echo "✓ done"
