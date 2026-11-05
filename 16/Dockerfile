# PostgreSQL 16 client: pg_dump must be at least the server's major version.
FROM postgres:16-alpine@sha256:0cefaabd882e42bcb2a2f3dc56d3ce4770560ba62fd7f197f1a2e008fd5731ab
# security: the distribution's fixed packages at build time (the weekly rebuild picks up new ones)
RUN apk upgrade --no-cache
COPY backup.sh run.sh healthcheck.sh /
HEALTHCHECK --interval=5m --timeout=10s --start-period=1m CMD ["/healthcheck.sh"]
ENTRYPOINT ["/run.sh"]
