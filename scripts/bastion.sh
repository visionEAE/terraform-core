#!/usr/bin/env bash
# The only human path to the private database.
#   scripts/bastion.sh up      start the VM, open a tunnel on localhost:15432
#   scripts/bastion.sh down    close the tunnel, stop the VM
#   scripts/bastion.sh status  VM + tunnel state
# 15432 (not 5432) so it never collides with a local docker-compose Postgres.
set -euo pipefail
cd "$(dirname "$0")/.."

WORKSPACE="${WORKSPACE:-prod}"
LOCAL_PORT="${LOCAL_PORT:-15432}"

BASTION="$(terraform output -raw bastion_name)"
ZONE="$(terraform output -raw bastion_zone)"
DB_IP="$(terraform output -raw db_private_ip)"
PIDFILE="/tmp/s360-${WORKSPACE}-bastion-tunnel.pid"
LOGFILE="/tmp/s360-${WORKSPACE}-bastion-tunnel.log"

case "${1:-}" in
  up)
    echo "→ starting ${BASTION}"
    gcloud compute instances start "${BASTION}" --zone "${ZONE}" --quiet
    echo "→ waiting for SSH through IAP"
    for i in $(seq 1 12); do
      gcloud compute ssh "${BASTION}" --zone "${ZONE}" --tunnel-through-iap --command true --quiet 2>/dev/null && break
      [ "$i" = 12 ] && { echo "✗ SSH never came up" >&2; exit 1; }
      sleep 5
    done
    echo "→ opening tunnel localhost:${LOCAL_PORT} → ${DB_IP}:5432"
    nohup gcloud compute ssh "${BASTION}" --zone "${ZONE}" --tunnel-through-iap --quiet \
      -- -N -L "${LOCAL_PORT}:${DB_IP}:5432" >"${LOGFILE}" 2>&1 &
    echo $! >"${PIDFILE}"
    sleep 3
    echo "✓ tunnel up (pid $(cat "${PIDFILE}"))."
    echo "  psql: PGPASSWORD=\$(gcloud secrets versions access latest --secret=s360-${WORKSPACE}-postgres-password) \\"
    echo "        psql -h localhost -p ${LOCAL_PORT} -U postgres -d student360"
    ;;
  down)
    [ -f "${PIDFILE}" ] && kill "$(cat "${PIDFILE}")" 2>/dev/null && rm -f "${PIDFILE}" && echo "✓ tunnel closed"
    gcloud compute instances stop "${BASTION}" --zone "${ZONE}" --quiet
    echo "✓ ${BASTION} stopped"
    ;;
  status)
    gcloud compute instances describe "${BASTION}" --zone "${ZONE}" --format='value(status)'
    if [ -f "${PIDFILE}" ] && kill -0 "$(cat "${PIDFILE}")" 2>/dev/null; then
      echo "tunnel: up on localhost:${LOCAL_PORT} (pid $(cat "${PIDFILE}"))"
    else
      echo "tunnel: down"
    fi
    ;;
  *)
    echo "usage: $0 {up|down|status}" >&2
    exit 1
    ;;
esac
