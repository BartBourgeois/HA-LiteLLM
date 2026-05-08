FROM ghcr.io/berriai/litellm:main-stable

# Install PostgreSQL
RUN apt-get update && \
    apt-get install -y --no-install-recommends postgresql postgresql-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Prepare PostgreSQL data directory (will be moved to /data on first run)
RUN mkdir -p /run/postgresql && chown postgres:postgres /run/postgresql

# Copy default LiteLLM model config and startup script
COPY litellm_config.yaml /defaults/litellm_config.yaml
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Override the image's default entrypoint
ENTRYPOINT []
CMD ["/bin/bash", "/run.sh"]
