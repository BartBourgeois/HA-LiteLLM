# HA-LiteLLM

Home Assistant add-on that runs the [LiteLLM Proxy](https://docs.litellm.ai/docs/proxy/quick_start) — a unified, OpenAI-compatible API gateway for 100+ LLM providers (OpenAI, Anthropic, Azure, Bedrock, Gemini, Ollama, vLLM, …).

Point any OpenAI-compatible client (including Home Assistant's [OpenAI Conversation](https://www.home-assistant.io/integrations/openai_conversation/) integration, [Extended OpenAI Conversation](https://github.com/jekalmin/extended_openai_conversation), or third-party tools like LibreChat, Continue.dev, Open WebUI, etc.) at the proxy and switch models with a config edit instead of reconfiguring every client.

## Features

- **One endpoint, many providers** — call any supported LLM through a single OpenAI-format URL.
- **Bundled PostgreSQL** — virtual keys, spend tracking, budgets, and request logging persist across restarts (no external DB required).
- **Master key auth** — protect the proxy with a single shared secret, or issue per-client virtual keys via the LiteLLM API/UI.
- **Multi-arch** — `amd64` and `aarch64` images (Raspberry Pi 4/5, Home Assistant Yellow/Green, generic x86).
- **Persistent config** — model list lives at `/config/litellm/config.yaml` and survives add-on updates.
- **Built on `ghcr.io/berriai/litellm:main-stable`** — tracks the upstream stable channel.

## Installation

1. In Home Assistant, open **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** menu (top-right) → **Repositories**.
3. Add the repository URL:
   ```
   https://github.com/BartBourgeois/HA-LiteLLM
   ```
4. Find **LiteLLM Proxy** in the store and click **Install**.
5. Start the add-on. On first boot it initializes PostgreSQL under `/data/postgres` and seeds a default config at `/config/litellm/config.yaml`.

[![Add repository to my Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2FBartBourgeois%2FHA-LiteLLM)

## Configuration

### Add-on options

| Option       | Type   | Default | Description                                                                  |
|--------------|--------|---------|------------------------------------------------------------------------------|
| `port`       | port   | `4000`  | TCP port the proxy listens on (mapped to the host).                          |
| `master_key` | string | `""`    | Shared secret. Clients must send `Authorization: Bearer <master_key>`. Leave empty to disable auth (not recommended). |

The master key is exported to the container as `LITELLM_MASTER_KEY` and referenced from `litellm_config.yaml` via `os.environ/LITELLM_MASTER_KEY`.

### Model configuration

Models are defined in:

```
/config/litellm/config.yaml
```

The first time the add-on starts it copies a commented template there. Edit it from the Home Assistant **File editor** / **Studio Code Server** add-on, then restart **LiteLLM Proxy** to apply.

Minimal example:

```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: "sk-..."

  - model_name: claude-sonnet-4-6
    litellm_params:
      model: anthropic/claude-sonnet-4-6
      api_key: "sk-ant-..."

  - model_name: llama3
    litellm_params:
      model: ollama/llama3
      api_base: "http://homeassistant.local:11434"

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
```

Full provider/parameter reference: <https://docs.litellm.ai/docs/proxy/configs>.

## Usage

Once running, the proxy is reachable at:

```
http://homeassistant.local:4000
```

(or your HA host's IP). Test it from a shell:

```bash
curl http://homeassistant.local:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Use it from Home Assistant

Configure the **OpenAI Conversation** (or Extended OpenAI Conversation) integration with:

- **Base URL**: `http://<ha-host>:4000/v1`
- **API key**: your `master_key`
- **Model**: any `model_name` from your `litellm_config.yaml`

### Admin UI

LiteLLM ships an admin UI for managing virtual keys, teams, budgets, and viewing spend:

```
http://homeassistant.local:4000/ui
```

Log in with the master key.

## Storage layout

| Path                            | Purpose                                                |
|---------------------------------|--------------------------------------------------------|
| `/config/litellm/config.yaml`   | User-editable model list (persisted via HA `config`).  |
| `/data/postgres/`               | PostgreSQL data directory (persisted per add-on).      |
| `/data/options.json`            | HA add-on options (read-only at runtime).              |

`/config` survives add-on uninstall/reinstall; `/data` does not.

## Upgrading

The add-on follows upstream `litellm:main-stable`. To pull a newer LiteLLM:

1. Bump `version:` in [LiteLLM/config.yaml](LiteLLM/config.yaml).
2. Reinstall / update from the HA add-on store.

Your model config and database are preserved.

## Troubleshooting

- **Add-on log shows `password authentication failed` / Postgres won't start** — delete `/data/postgres` (via the SSH/Terminal add-on) and restart; it will reinitialize.
- **`Model not found` from a client** — `model` in the request must match a `model_name` (not the upstream `litellm_params.model`) from `config.yaml`.
- **401 Unauthorized** — confirm the client sends `Authorization: Bearer <master_key>` and that the key matches the add-on option.
- **Changes to `config.yaml` not applied** — the proxy reads config at startup; restart the add-on after edits.

## Architecture

```
┌─────────────────────────────────────────────┐
│ Home Assistant Add-on Container             │
│                                             │
│  ┌─────────────┐      ┌──────────────────┐  │
│  │  LiteLLM    │◀────▶│  PostgreSQL 16   │  │
│  │  Proxy      │      │  (127.0.0.1)     │  │
│  │  :4000      │      │  /data/postgres  │  │
│  └──────┬──────┘      └──────────────────┘  │
│         │                                   │
│         ▼  /config/litellm/config.yaml      │
└─────────┼───────────────────────────────────┘
          │
          ▼
   OpenAI / Anthropic / Ollama / Azure / …
```

Base image: [`ghcr.io/berriai/litellm:main-stable`](https://github.com/BerriAI/litellm/pkgs/container/litellm). PostgreSQL is added on top so the add-on is fully self-contained.

## Links

- LiteLLM proxy docs: <https://docs.litellm.ai/docs/proxy/quick_start>
- Supported providers: <https://docs.litellm.ai/docs/providers>
- LiteLLM repo: <https://github.com/BerriAI/litellm>
- Home Assistant add-on docs: <https://developers.home-assistant.io/docs/add-ons>

## License

This add-on packaging is provided as-is. LiteLLM itself is licensed by [BerriAI](https://github.com/BerriAI/litellm/blob/main/LICENSE).
