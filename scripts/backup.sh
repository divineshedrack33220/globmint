#!/usr/bin/env bash
#
# Globmint database backup.
#
# Dumps the Postgres database and keeps N daily / weekly / rolling monthly
# copies in a backup dir. Intended to be run from cron.
#
# The database usually runs in Docker (globmint-postgres). If host pg_dump is
# missing, the script runs pg_dump inside the container automatically and
# streams the archive to the host.
#
# Usage:
#   GLOBMINT_DATABASE_URL=postgres://... scripts/backup.sh [/path/to/backups]
#
# Env:
#   GLOBMINT_DATABASE_URL      required. postgres://user:pass@host:port/db
#   GLOBMINT_DB_CONTAINER      container name for in-container pg_dump
#                              (default globmint-postgres)
#   GLOBMINT_BACKUP_DIR        default backup directory (overridden by $1)
#   GLOBMINT_BACKUP_KEEP_DAILY   (default 14)
#   GLOBMINT_BACKUP_KEEP_WEEKLY  (default 8)
#   GLOBMINT_BACKUP_KEEP_MONTHLY (default 6)
#
# Cron example (daily 02:00):
#   0 2 * * *  GLOBMINT_DATABASE_URL=postgres://globmint:...@127.0.0.1:5434/globmint /home/divine/Desktop/globe\\ mint/scripts/backup.sh /var/backups/globmint >> /var/log/globmint-backup.log 2>&1
#
set -euo pipefail

DB_URL="${GLOBMINT_DATABASE_URL:-}"
BACKUP_DIR="${1:-${GLOBMINT_BACKUP_DIR:-./backups}}"
KEEP_DAILY="${GLOBMINT_BACKUP_KEEP_DAILY:-14}"
KEEP_WEEKLY="${GLOBMINT_BACKUP_KEEP_WEEKLY:-8}"
KEEP_MONTHLY="${GLOBMINT_BACKUP_KEEP_MONTHLY:-6}"

if [[ -z "${DB_URL}" ]]; then
  echo "error: GLOBMINT_DATABASE_URL is required" >&2
  exit 1
fi

USE_DOCKER=0
if ! command -v pg_dump >/dev/null 2>&1; then
  DB_CONTAINER="${GLOBMINT_DB_CONTAINER:-globmint-postgres}"
  if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -qx "${DB_CONTAINER}"; then
    echo "info: using pg_dump from docker container ${DB_CONTAINER}"
    USE_DOCKER=1
  else
    echo "error: pg_dump not found and container ${DB_CONTAINER} is not running" >&2
    exit 1
  fi
fi

mkdir -p "${BACKUP_DIR}/daily" "${BACKUP_DIR}/weekly" "${BACKUP_DIR}/monthly"

STAMP="$(date +%Y%m%d_%H%M%S)"
DAILY="${BACKUP_DIR}/daily/globmint_${STAMP}.sql.gz"

if [[ "${USE_DOCKER}" == "1" ]]; then
  # Inside the container the app DB is on localhost:5432. Stream the archive
  # from the container to the host, then validate it in-container.
  DB_NAME="${DB_URL##*/}"
  DB_NAME="${DB_NAME%%\?*}"
  docker exec -i "${DB_CONTAINER}" pg_dump -U globmint -d "${DB_NAME}" \
    --format=custom --compress=0 | gzip -9 > "${DAILY}"
  docker exec -i "${DB_CONTAINER}" sh -c 'gunzip > /tmp/bak_check.dump && pg_restore --list /tmp/bak_check.dump >/dev/null && rm -f /tmp/bak_check.dump' \
    < "${DAILY}" || { echo "error: container integrity check failed" >&2; rm -f "${DAILY}"; exit 1; }
else
  pg_dump "${DB_URL}" --format=custom --compress=9 --file="${DAILY}"
  pg_restore --list "${DAILY}" >/dev/null || { echo "error: backup failed integrity check" >&2; rm -f "${DAILY}"; exit 1; }
fi

echo "backup ok: ${DAILY} ($(du -h "${DAILY}" | cut -f1))"

# Retention: a snapshot on Sundays is kept as weekly, one on the 1st as
# monthly; prune the oldest beyond the retention limits.
if [[ "$(date +%u)" == "7" ]]; then
  cp -p "${DAILY}" "${BACKUP_DIR}/weekly/globmint_week_${STAMP}.sql.gz"
fi
if [[ "$(date +%d)" == "01" ]]; then
  cp -p "${DAILY}" "${BACKUP_DIR}/monthly/globmint_month_${STAMP}.sql.gz"
fi

prune() {
  local kind="$1" keep="$2"
  ls -1t "${BACKUP_DIR}/${kind}"/*.sql.gz 2>/dev/null | tail -n +"$((keep+1))" | xargs -r rm -f
}
prune daily   "${KEEP_DAILY}"
prune weekly  "${KEEP_WEEKLY}"
prune monthly "${KEEP_MONTHLY}"