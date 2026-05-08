FROM ghcr.io/berriai/litellm:main-stable

# Install PostgreSQL and nginx (Alpine-based image)
RUN apk add --no-cache postgresql postgresql-client bash nginx

# Create postgres user/group and prepare runtime directories
RUN addgroup -S postgres 2>/dev/null || true && \
    adduser -S -G postgres -h /var/lib/postgresql -s /bin/sh postgres 2>/dev/null || true && \
    mkdir -p /run/postgresql /run/nginx && chown postgres:postgres /run/postgresql

# Copy default LiteLLM model config, nginx ingress config, and startup script
COPY litellm_config.yaml /defaults/litellm_config.yaml
COPY nginx_ingress.conf /etc/nginx/nginx.conf
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Override the image's default entrypoint
ENTRYPOINT []
CMD ["/bin/bash", "/run.sh"]
