# PostgreSQL 16 client: pg_dump must be at least the server's major version.
FROM postgres:16-alpine@sha256:aa6cb33cf4c19c765cefcf48d96176258800870a9a1e930ad126200f9d825139
# security: the distribution's fixed packages at build time (the weekly rebuild picks up new ones)
# gosu (the server entrypoint's privilege drop, built with Go 1.24.6) is unused: the backup runs its own entrypoint
RUN apk upgrade --no-cache && rm -f /usr/local/bin/gosu
COPY backup.sh run.sh healthcheck.sh /
HEALTHCHECK --interval=5m --timeout=10s --start-period=1m CMD ["/healthcheck.sh"]
ENTRYPOINT ["/run.sh"]
