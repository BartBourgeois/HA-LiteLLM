#!/usr/bin/env bash
set -e

CONFIG_PATH="/data/options.json"
LITELLM_CONFIG_DIR="/config/litellm"
LITELLM_CONFIG="${LITELLM_CONFIG_DIR}/config.yaml"
PG_DATA="/data/postgres"
PG_RUN="/run/postgresql"

# Read Home Assistant add-on options
PORT=$(python3 -c "import json; print(json.load(open('${CONFIG_PATH}')).get('port', 4000))")
MASTER_KEY=$(python3 -c "import json; print(json.load(open('${CONFIG_PATH}')).get('master_key', ''))")

# ============================================
# PostgreSQL setup
# ============================================
echo "[INFO] Starting PostgreSQL..."

mkdir -p "${PG_RUN}"
chown postgres:postgres "${PG_RUN}"

# Initialize database if first run
if [ ! -d "${PG_DATA}" ]; then
    echo "[INFO] Initializing PostgreSQL database..."
    mkdir -p "${PG_DATA}"
    chown postgres:postgres "${PG_DATA}"
    su postgres -c "initdb -D ${PG_DATA}"
    # Configure to listen on localhost only
    echo "listen_addresses = '127.0.0.1'" >> "${PG_DATA}/postgresql.conf"
    echo "port = 5432" >> "${PG_DATA}/postgresql.conf"
    # Allow local connections without password
    echo "local all all trust" > "${PG_DATA}/pg_hba.conf"
    echo "host all all 127.0.0.1/32 trust" >> "${PG_DATA}/pg_hba.conf"
fi

# Ensure postgres owns its data directory
chown -R postgres:postgres "${PG_DATA}"

# Start PostgreSQL in background (log inside PG_DATA to avoid permission issues)
su postgres -c "pg_ctl start -D ${PG_DATA} -l ${PG_DATA}/postgresql.log -w"

# Create litellm database if it doesn't exist
su postgres -c "psql -h 127.0.0.1 -tc \"SELECT 1 FROM pg_database WHERE datname = 'litellm'\"" | grep -q 1 || \
    su postgres -c "createdb -h 127.0.0.1 litellm"

echo "[INFO] PostgreSQL is ready."

# ============================================
# LiteLLM setup
# ============================================

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

# Use PostgreSQL for persistence
export DATABASE_URL="postgresql://postgres@127.0.0.1:5432/litellm"
export STORE_MODEL_IN_DB="True"

# Restrict uvicorn's X-Forwarded-* trust to the supervisor bridge + loopback.
# Supervisor ingress proxies from 172.30.32.2 and adds X-Forwarded-For (but not
# X-Forwarded-Proto). This is defense-in-depth, not load-bearing for ingress.
export FORWARDED_ALLOW_IPS="172.30.32.2,127.0.0.1"

# Discover this add-on's ingress URL from the supervisor and feed it to
# LiteLLM as SERVER_ROOT_PATH. LiteLLM uses it to (a) set FastAPI's root_path
# and (b) rewrite the hardcoded "/litellm-asset-prefix" string baked into the
# Next.js UI bundle so CSS/JS load under the dynamic ingress prefix.
SERVER_ROOT_PATH=""
if [ -n "${SUPERVISOR_TOKEN:-}" ]; then
    INGRESS_URL=$(curl -sSf -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        http://supervisor/addons/self/info 2>/dev/null \
        | python3 -c "import json,sys; print((json.load(sys.stdin).get('data') or {}).get('ingress_url') or '')" \
        2>/dev/null || true)
    # Supervisor returns "/api/hassio_ingress/<token>/" with a trailing slash;
    # LiteLLM does literal string substitution against "/litellm-asset-prefix"
    # (no trailing slash), and FastAPI's root_path convention is no-trailing-
    # slash, so strip it.
    SERVER_ROOT_PATH="${INGRESS_URL%/}"
fi

if [ -n "${SERVER_ROOT_PATH}" ]; then
    export SERVER_ROOT_PATH
    echo "[INFO] Discovered ingress URL: ${SERVER_ROOT_PATH}"

    # The HA panel iframe lands on the ingress URL root ("/"). LiteLLM's default
    # behavior is to serve the FastAPI Swagger docs page at "/", which (a) is
    # not the dashboard the user wants and (b) ships broken in the upstream
    # main-stable image (its /swagger/swagger-ui.css and -bundle.js 404).
    #
    # Disable docs (NO_DOCS=true makes _get_docs_url() return None, which
    # satisfies LiteLLM's "docs_url != '/'" guard around ROOT_REDIRECT_URL)
    # and redirect "/" to the dashboard at "<ingress>/ui/".
    export NO_DOCS="true"
    export NO_REDOC="true"
    export ROOT_REDIRECT_URL="${SERVER_ROOT_PATH}/ui/"
else
    echo "[WARN] Ingress URL not assigned by supervisor (response was empty or null)."
    echo "[WARN] LiteLLM panel UI will be broken under HA ingress on this start."
    echo "[WARN] Restart the add-on once HA finishes registration; direct API on :${PORT} still works."
fi

echo "============================================"
echo " LiteLLM Proxy - Home Assistant Add-on"
echo " Port: ${PORT}"
echo " Server Root Path: ${SERVER_ROOT_PATH:-<none>}"
echo " Config: ${LITELLM_CONFIG}"
echo " Database: PostgreSQL (local)"
echo "============================================"

# Trap to cleanly stop PostgreSQL on shutdown
cleanup() {
    echo "[INFO] Stopping PostgreSQL..."
    su postgres -c "pg_ctl stop -D ${PG_DATA} -m fast" || true
}
trap cleanup EXIT TERM INT

exec litellm ${ARGS}
