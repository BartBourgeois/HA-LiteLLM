FROM ghcr.io/berriai/litellm:main-stable

# Copy default LiteLLM model config and startup script
COPY litellm_config.yaml /defaults/litellm_config.yaml
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Override the image's default entrypoint
ENTRYPOINT []
CMD ["/bin/bash", "/run.sh"]
