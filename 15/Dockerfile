# PostgreSQL 15 client: pg_dump must be at least the server's major version.
FROM postgres:15-alpine@sha256:54e0dd8e8cddcdbb9156c2486eed5a43eccb7214d7c6828097d41ce049fb3984
# security: the distribution's fixed packages at build time (the weekly rebuild picks up new ones)
# gosu (the server entrypoint's privilege drop, built with Go 1.24.6) is unused: the backup runs its own entrypoint
RUN apk upgrade --no-cache && rm -f /usr/local/bin/gosu
COPY backup.sh run.sh healthcheck.sh /
HEALTHCHECK --interval=5m --timeout=10s --start-period=1m CMD ["/healthcheck.sh"]
ENTRYPOINT ["/run.sh"]
