#!/bin/sh
# Unhealthy when the last scheduled run failed, or when dumps exist but none is younger than 26 h.
# A fresh container with no dumps yet is healthy until its first run.
set -eu
last=${BACKUP_DIR:-/backups}/last
[ "$(cat /tmp/backup-state 2>/dev/null)" != failed ] || { echo "last backup failed"; exit 1; }
[ -z "$(find "$last" -maxdepth 1 -type f -name '*.sql.gz' 2>/dev/null | head -1)" ] && exit 0
[ -n "$(find "$last" -maxdepth 1 -type f -name '*.sql.gz' -mmin -1560 | head -1)" ] || { echo "no dump in the last 26 h"; exit 1; }
