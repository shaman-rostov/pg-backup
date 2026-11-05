#!/usr/bin/env bash
# Integration test for one PostgreSQL major: dump a live server, restore into an empty one, compare,
# check the file layout, the healthcheck, the scheduler and the failure path.
#   test/run.sh 16 [image]
set -euo pipefail

PG=${1:?postgres major}
IMAGE=${2:-pg-backup:test-$PG}
NET=pgb-test-$PG-$$
DIR=$(mktemp -d)
# dumps are root-owned with mode 600, as in production: read and clean them up from a container
in_dir() { docker run --rm -v "$DIR:/backups" --entrypoint sh "$IMAGE" -c "$1"; }
cleanup() {
  docker rm -f "$NET-db" "$NET-restore" "$NET-sched" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  in_dir 'rm -rf /backups/*' 2>/dev/null || true; rmdir "$DIR" 2>/dev/null || true
}
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

[ "$IMAGE" != "pg-backup:test-$PG" ] || docker build -q -f "$PG/Dockerfile" -t "$IMAGE" . >/dev/null
docker network create "$NET" >/dev/null
db() { docker run -d --name "$1" --network "$NET" -e POSTGRES_USER=app -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=app \
         "postgres:$PG-alpine" >/dev/null; until docker exec "$1" pg_isready -U app -d app >/dev/null 2>&1; do sleep 1; done; sleep 2; }
psql_in() { docker exec -i "$1" psql -U app -d app -v ON_ERROR_STOP=1 -Atq "${@:2}"; }
backup() { docker run --rm --network "$NET" -v "$DIR:/backups" -e POSTGRES_HOST="$NET-db" -e POSTGRES_DB=app \
             -e POSTGRES_USER=app -e POSTGRES_PASSWORD="${PW:-secret}" "$@"; }

db "$NET-db"
psql_in "$NET-db" -c "create table t(id int primary key, v text); insert into t select g, md5(g::text) from generate_series(1,5000) g;"
want=$(psql_in "$NET-db" -c "select count(*)||':'||md5(string_agg(v, ',' order by id)) from t")

backup --entrypoint /backup.sh "$IMAGE" | grep -q "SQL backup created successfully" || fail "backup run"
in_dir 'set -e; last=$(find /backups/last -type f -name "app-*.sql.gz" | head -1); [ -n "$last" ]
  [ "$(stat -c %a "$last")" = 600 ]
  for d in daily weekly monthly; do f=$(find /backups/$d -type f -name "app-*.sql.gz" | head -1)
    [ -n "$f" ] && [ "$f" -ef "$last" ] && [ -L /backups/$d/app-latest.sql.gz ] && [ -e /backups/$d/app-latest.sql.gz ]; done
  [ -L /backups/last/app-latest.sql.gz ] && [ -z "$(find /backups -name "*.tmp")" ]' || fail "file layout"

db "$NET-restore"
in_dir 'gunzip -c /backups/last/app-latest.sql.gz' | psql_in "$NET-restore" >/dev/null
got=$(psql_in "$NET-restore" -c "select count(*)||':'||md5(string_agg(v, ',' order by id)) from t")
[ "$got" = "$want" ] || fail "restored data differs ($got vs $want)"

# failure path: wrong password -> non-zero exit, no new file, no temp file
count() { in_dir 'find /backups/last -type f -name "*.sql.gz" | wc -l'; }
before=$(count)
if PW=wrong backup --entrypoint /backup.sh "$IMAGE" >/dev/null 2>&1; then fail "backup with a wrong password succeeded"; fi
[ "$(count)" = "$before" ] || fail "failed run left a dump"
[ -z "$(in_dir 'find /backups -name "*.tmp"')" ] || fail "failed run left a temp file"

# scheduler + healthcheck: BACKUP_ON_START runs once, state ok, container healthy
backup -d --name "$NET-sched" -e BACKUP_ON_START=TRUE -e BACKUP_TIME=03:30 "$IMAGE" >/dev/null
for _ in $(seq 30); do [ "$(docker exec "$NET-sched" cat /tmp/backup-state 2>/dev/null)" = ok ] && break; sleep 1; done
[ "$(docker exec "$NET-sched" cat /tmp/backup-state)" = ok ] || fail "scheduler state"
docker exec "$NET-sched" /healthcheck.sh || fail "healthcheck"
docker logs "$NET-sched" 2>&1 | grep -q "next backup at 03:30 UTC" || fail "schedule message"
docker run --rm -e SCHEDULE="0 3 * * *" -e POSTGRES_HOST=x -e POSTGRES_DB=x -e POSTGRES_USER=x -e POSTGRES_PASSWORD=x \
  "$IMAGE" >/dev/null 2>&1 && fail "unsupported SCHEDULE accepted"

echo "PASS postgres $PG: $want"
