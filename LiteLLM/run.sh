#!/usr/bin/env bash
set -e

CONFIG_PATH="/data/options.json"
LITELLM_CONFIG_DIR="/config/litellm"
LITELLM_CONFIG="${LITELLM_CONFIG_DIR}/config.yaml"

# Read Home Assistant add-on options
PORT=$(python3 -c "import json; print(json.load(open('${CONFIG_PATH}')).get('port', 4000))")
MASTER_KEY=$(python3 -c "import json; print(json.load(open('${CONFIG_PATH}')).get('master_key', ''))")

# Create config directory if it doesn't exist
mkdir -p "${LITELLM_CONFIG_DIR}"

# Copy default config if user hasn't created one yet
if [ ! -f "${LITELLM_CONFIG}" ]; then
    echo "[INFO] No LiteLLM config found at ${LITELLM_CONFIG}, copying default..."
    cp /defaults/litellm_config.yaml "${LITELLM_CONFIG}"
    echo "[INFO] Edit /config/litellm/config.yaml to add your models and API keys."
fi

# Build command arguments
ARGS="--config ${LITELLM_CONFIG} --port ${PORT} --host 0.0.0.0"

# Set master key if provided
if [ -n "${MASTER_KEY}" ]; then
    export LITELLM_MASTER_KEY="${MASTER_KEY}"
fi

# Use SQLite in /data for persistence across restarts
export DATABASE_URL="sqlite:////data/litellm.db"

echo "============================================"
echo " LiteLLM Proxy - Home Assistant Add-on"
echo " Port: ${PORT}"
echo " Config: ${LITELLM_CONFIG}"
echo " Database: /data/litellm.db"
echo "============================================"

exec litellm ${ARGS}
