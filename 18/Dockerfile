# PostgreSQL 18 client: pg_dump must be at least the server's major version.
FROM postgres:18-alpine@sha256:10a5c69a83035ab5239f5620d708520e8b28f5aa1f2b20143e6024532edadfb5
# security: the distribution's fixed packages at build time (the weekly rebuild picks up new ones)
RUN apk upgrade --no-cache
COPY backup.sh run.sh healthcheck.sh /
HEALTHCHECK --interval=5m --timeout=10s --start-period=1m CMD ["/healthcheck.sh"]
ENTRYPOINT ["/run.sh"]
