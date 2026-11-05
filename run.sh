#!/bin/sh
# Scheduler: runs /backup.sh once a day at BACKUP_TIME (UTC, HH:MM; default 00:00, like SCHEDULE=@daily before).
# The outcome of the last run is kept in $STATE for the healthcheck.
set -eu

SCHEDULE=${SCHEDULE:-@daily}
[ "$SCHEDULE" = "@daily" ] || { echo "only SCHEDULE=@daily is supported (got '$SCHEDULE'); set BACKUP_TIME" >&2; exit 1; }
TIME=${BACKUP_TIME:-00:00}
echo "$TIME" | grep -Eq '^([01][0-9]|2[0-3]):[0-5][0-9]$' || { echo "BACKUP_TIME must be HH:MM (UTC)" >&2; exit 1; }
STATE=/tmp/backup-state
echo pending > "$STATE"

trap 'exit 0' TERM INT

seconds_until() {
  now=$(date -u +%s)
  next=$(date -u -d "$(date -u +%F) $1:00" +%s)
  [ "$next" -gt "$now" ] || next=$((next + 86400))
  echo $((next - now))
}

[ "${BACKUP_ON_START:-FALSE}" = TRUE ] && { /backup.sh && echo ok > "$STATE" || echo failed > "$STATE"; }

while :; do
  wait_s=$(seconds_until "$TIME")
  echo "next backup at $TIME UTC (in ${wait_s}s)"
  sleep "$wait_s" & wait $!
  if /backup.sh; then echo ok > "$STATE"; else echo failed > "$STATE"; echo "backup FAILED" >&2; fi
done
