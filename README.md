# pg-backup

Scheduled `pg_dump` for the projects on the oracle host. A drop-in replacement for
`prodrigestivill/postgres-backup-local`: same environment variables, same `/backups` layout
(`last/`, `daily/`, `weekly/`, `monthly/`, hard links, `<db>-latest.sql.gz` symlinks), same `/backup.sh`.

Image: `ghcr.io/shaman-rostov/pg-backup:<major>` (15, 16, 18), built on the official `postgres:<major>-alpine`
pinned by digest, with the distribution's fixed packages applied; rebuilt weekly. Use the major of the server.

| Variable | Default | |
|---|---|---|
| `POSTGRES_HOST`, `POSTGRES_DB` (comma-separated), `POSTGRES_USER` | — | required |
| `POSTGRES_PASSWORD` or `POSTGRES_PASSWORD_FILE` | — | required |
| `POSTGRES_PORT` | 5432 | |
| `SCHEDULE` | `@daily` | only `@daily`; the time is `BACKUP_TIME` |
| `BACKUP_TIME` | `00:00` | UTC, HH:MM |
| `BACKUP_KEEP_MINS` / `_DAYS` / `_WEEKS` / `_MONTHS` | 1440 / 7 / 4 / 6 | |
| `BACKUP_ON_START` | `FALSE` | |

Each dump is written to a temp file, checked with `gzip -t` and renamed, so a failed run never replaces a good dump.
Files are created with mode 600. The healthcheck fails when the last scheduled run failed or the newest dump is
older than 26 hours.

Test locally: `test/run.sh 16` (dumps a live server, restores into an empty one, compares the data).
