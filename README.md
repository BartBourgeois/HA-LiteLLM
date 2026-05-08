# HA-LiteLLM

Home Assistant add-on for [LiteLLM Proxy](https://docs.litellm.ai/docs/proxy/quick_start) — a unified API gateway that lets you call 100+ LLM providers using the OpenAI API format.

## Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**
2. Click the **⋮** menu (top-right) → **Repositories**
3. Add this repository URL:
   ```
   https://github.com/BartBourgeois/HA-LiteLLM
   ```
4. Find **LiteLLM Proxy** in the add-on store and click **Install**

## Configuration

### Add-on Options

| Option       | Description                                | Default |
|--------------|--------------------------------------------|---------|
| `port`       | Port for the LiteLLM proxy API             | `4000`  |
| `master_key` | Master API key to protect your proxy       | (empty) |

### Model Configuration

After first start, edit the LiteLLM config file at:

```
/config/litellm/config.yaml
```

Add your models and API keys there. See [litellm_config.yaml](LiteLLM/litellm_config.yaml) for examples. Restart the add-on after editing.

## Usage

Once running, the LiteLLM proxy is available at `http://homeassistant.local:4000` (or your HA IP). Use it as an OpenAI-compatible endpoint in any application.

```bash
curl http://homeassistant.local:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_MASTER_KEY" \
  -d '{"model": "gpt-4", "messages": [{"role": "user", "content": "Hello!"}]}'
```
