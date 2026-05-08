FROM ghcr.io/berriai/litellm:main-stable

# Install PostgreSQL + curl (curl is needed at startup to query the supervisor
# API for this add-on's ingress URL; not present in the wolfi base layer).
RUN apk add --no-cache postgresql postgresql-client bash curl

# Create postgres user/group and prepare runtime directory
RUN addgroup -S postgres 2>/dev/null || true && \
    adduser -S -G postgres -h /var/lib/postgresql -s /bin/sh postgres 2>/dev/null || true && \
    mkdir -p /run/postgresql && chown postgres:postgres /run/postgresql

# Copy default LiteLLM model config and startup script
COPY litellm_config.yaml /defaults/litellm_config.yaml
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Override the image's default entrypoint
ENTRYPOINT []
CMD ["/bin/bash", "/run.sh"]
