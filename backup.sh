#!/bin/sh
# One backup run: a gzip-compressed plain SQL dump per database, kept as hard links in last/ daily/ weekly/ monthly/
# with <db>-latest symlinks. File names, layout and settings match prodrigestivill/postgres-backup-local, so the
# existing off-site copy, restore drills and `docker exec <container> /backup.sh` keep working.
set -euo pipefail

: "${POSTGRES_HOST:?}" "${POSTGRES_USER:?}"
DBS=${POSTGRES_DB:?}
BACKUP_DIR=${BACKUP_DIR:-/backups}
SUFFIX=.sql.gz
KEEP_MINS=${BACKUP_KEEP_MINS:-1440}
KEEP_DAYS=${BACKUP_KEEP_DAYS:-7}
KEEP_WEEKS=$(( ${BACKUP_KEEP_WEEKS:-4} * 7 + 1 ))
KEEP_MONTHS=$(( ${BACKUP_KEEP_MONTHS:-6} * 31 + 1 ))

export PGHOST=$POSTGRES_HOST PGPORT=${POSTGRES_PORT:-5432} PGUSER=$POSTGRES_USER
if [ -n "${POSTGRES_PASSWORD_FILE:-}" ]; then PGPASSWORD=$(cat "$POSTGRES_PASSWORD_FILE"); else PGPASSWORD=${POSTGRES_PASSWORD:?}; fi
export PGPASSWORD

mkdir -p "$BACKUP_DIR/last" "$BACKUP_DIR/daily" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly"
umask 077

for db in $(echo "$DBS" | tr ',' ' '); do
  name=$db-$(date +%Y%m%d-%H%M%S)$SUFFIX
  file=$BACKUP_DIR/last/$name
  echo "Creating dump of $db database from $PGHOST..."
  # temp file + integrity check + rename: an interrupted or failed dump never replaces a good one
  pg_dump -d "$db" --no-password | gzip -1 > "$file.tmp"
  gzip -t "$file.tmp"
  mv "$file.tmp" "$file"

  for period in daily:%Y%m%d weekly:%G%V monthly:%Y%m; do
    dir=${period%%:*}
    ln -f "$file" "$BACKUP_DIR/$dir/$db-$(date +"${period#*:}")$SUFFIX"
  done
  ln -sf "$name" "$BACKUP_DIR/last/$db-latest$SUFFIX"
  for period in daily:%Y%m%d weekly:%G%V monthly:%Y%m; do
    dir=${period%%:*}
    ln -sf "$db-$(date +"${period#*:}")$SUFFIX" "$BACKUP_DIR/$dir/$db-latest$SUFFIX"
  done

  echo "Cleaning older files for $db..."
  find "$BACKUP_DIR/last" -maxdepth 1 -type f -mmin "+$KEEP_MINS" -name "$db-*$SUFFIX" -delete
  find "$BACKUP_DIR/daily" -maxdepth 1 -type f -mtime "+$KEEP_DAYS" -name "$db-*$SUFFIX" -delete
  find "$BACKUP_DIR/weekly" -maxdepth 1 -type f -mtime "+$KEEP_WEEKS" -name "$db-*$SUFFIX" -delete
  find "$BACKUP_DIR/monthly" -maxdepth 1 -type f -mtime "+$KEEP_MONTHS" -name "$db-*$SUFFIX" -delete
  echo "$(date -u +%FT%TZ) $name $(stat -c %s "$file") bytes"
done

echo "SQL backup created successfully"
