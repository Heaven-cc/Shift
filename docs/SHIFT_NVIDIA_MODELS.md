# NVIDIA multi-model AI for SHIFT

## Purpose

SHIFT can use **NVIDIA API Catalog / NIM hosted inference** for text, image creation, image editing and voice while keeping every API key in the dedicated SHIFT Supabase project's Edge Function secrets. No API keys enter Flutter, Git, browser local storage, or a user-readable database column.

The existing AI research and Studio caption workflows now support NVIDIA inference with `SHIFT_AI_PROVIDER` optional (defaults to NVIDIA). The independent `shift-nvidia` Edge Function offers model status, private media generation, image editing and voice generation. It does not replace the existing approval system, Supabase Cron, or preserved Postiz integration.

## Backend configuration (Supabase → Edge Functions → Secrets)

The **required NVIDIA text configuration** for AI Workspace research/planning and Studio caption generation:

| Secret | Example / description |
|---|---|
| `SHIFT_AI_PROVIDER` | Optional. The backend defaults to NVIDIA if omitted. |
| `SHIFT_NVIDIA_API_KEY` | Shared NVIDIA API Catalog key; optional if each active role has its own key |
| `SHIFT_NVIDIA_TEXT_ROLE` | Optional: `mistral` (default) or `glm` for internal priority; users never select models. |
| `SHIFT_NVIDIA_MISTRAL_MODEL` | Exact model ID shown by NVIDIA for Mistral Large 4 |
| `SHIFT_NVIDIA_GLM_MODEL` | `z-ai/glm-5.3`, when enabled for your NVIDIA account |
| `SHIFT_BRAVE_SEARCH_API_KEY` | Separate Brave Search key, required for current NVIDIA live web research |

Text requests use `https://integrate.api.nvidia.com/v1/chat/completions`. **Do not guess model identifiers**: copy each ID from your NVIDIA Build model's API reference. Text model IDs are separate from API keys.

### Optional per-model overrides

For any slot, set `SHIFT_NVIDIA_<SLOT>_API_KEY` to override the shared `SHIFT_NVIDIA_API_KEY`. Set `SHIFT_NVIDIA_<SLOT>_MODEL` for the NVIDIA API model identifier and `SHIFT_NVIDIA_<SLOT>_ENDPOINT` for its exact **NVIDIA HTTPS inference endpoint**. Keys are never returned to Flutter. Do not paste keys into ChatGPT, GitHub, or the Flutter project.

| Slot | Model from your list | Secret prefix |
|---|---|---|
| mistral | Mistral Large 4 | `SHIFT_NVIDIA_MISTRAL_` |
| glm | GLM 5.3 | `SHIFT_NVIDIA_GLM_` |
| flux_klein | FLUX 3 Image Klein | `SHIFT_NVIDIA_FLUX_KLEIN_` |
| qwen_image | Qwen Image | `SHIFT_NVIDIA_QWEN_IMAGE_` |
| sd35 | Stable Diffusion 3.5 Large | `SHIFT_NVIDIA_SD35_` |
| qwen_edit | Qwen Image Edit NVPCB | `SHIFT_NVIDIA_QWEN_EDIT_` |
| flux_kontext | FLUX.1 Kontext Dev | `SHIFT_NVIDIA_FLUX_KONTEXT_` |
| magpie | Magpie TTS Multilingual | `SHIFT_NVIDIA_MAGPIE_` |
| chatterbox | Chatterbox Multilingual TTS | `SHIFT_NVIDIA_CHATTERBOX_` |

**Example for an image model:**

```text
SHIFT_NVIDIA_QWEN_IMAGE_MODEL=<exact NVIDIA model ID>
SHIFT_NVIDIA_QWEN_IMAGE_ENDPOINT=<NVIDIA HTTPS image-generation endpoint>
```

All nine slots exist independently in `shift-nvidia` (including the Nemotron embedding slot). Model statuses show **configured (not tested)** only when a key, model ID, and allowed endpoint are present. An unhosted, preview-only or non-compatible model will remain unusable until NVIDIA provides a callable endpoint that supports its assigned protocol.

## Different API protocols

- **Text:** OpenAI-compatible Chat Completions via NVIDIA's `integrate.api.nvidia.com` gateway. Selected through `SHIFT_NVIDIA_TEXT_ROLE`.
- **Image generation:** Model-specific NVIDIA HTTPS image endpoint; the current generic adapter sends a JSON prompt and expects base64 output. Check exact request/response schema from NVIDIA. It intentionally rejects URLs as an output source and does not fetch arbitrary images.
- **Image editing:** Model-specific NVIDIA HTTPS JSON image endpoint, receives a private user-uploaded image encoded on the server. It is not a generic text/chat model.
- **Multilingual TTS:** Needs a compatible NVIDIA speech inference endpoint. Speech NIM protocol is different from ordinary Chat Completions, so a TTS key or text endpoint alone is insufficient.

**Important:** Not all NVIDIA models expose the same public hosted API or accept the same schema. This integration is a protected, configurable backend adapter—not a verified production integration for all nine models. Confirm specific model availability, paid/free quotas, output encoding, and commercial licensing before enabling each slot. `Qwen Image Edit NVPCB` is specialized for PCB imagery and is a poor default for everyday marketing-photo edits.

## Flutter workflow

Go to **Home → SHIFT AI**. The NVIDIA model list shows per-role setup state. Generate images, edit a private uploaded photo, or request voice output from configured models. Results are uploaded into SHIFT's existing **private `shift-media` bucket** with short-lived signed URLs, and metadata is saved in `shift_nvidia_media`.

Media history belongs to the authenticated user's workspace. The table has read-only RLS policies. The function checks Supabase Auth, workspace ownership, the existing AI rate limiter, private source image paths, output byte limits and allowed NVIDIA HTTPS hostnames. AI-generated media is **not automatically published**.

For live research with NVIDIA text models, set `SHIFT_BRAVE_SEARCH_API_KEY` since NVIDIA's OpenAI-compatible chat inference doesn't itself supply search indexing. SHIFT searches the web, presents source leads to the model and saves generated recommendations and drafts.

## Tests remaining

- Enter at least one **actual NVIDIA key** via Supabase Edge Function secrets and an exact model ID.
- Use a signed-in SHIFT account to test text completion, private image generation, image editing and TTS against **each specific model's** documented request and response format.
- Verify signed media URLs, quotas, retry/recovery, provider error handling and licensing.
- Run Flutter analyzer/CI and an Android device smoke test.

**Safe defaults:** Unconfigured models are disabled, no secrets are visible in the app, no automatic publishing and no separate always-on worker. No TREXVEN backend or credentials are used.

## GLM 5.3 — minimal setup

Add `SHIFT_NVIDIA_GLM_MODEL=z-ai/glm-5.3` and `SHIFT_NVIDIA_GLM_API_KEY=<secret>` in SHIFT Supabase Edge Function secrets. If you already configured `SHIFT_NVIDIA_API_KEY`, GLM can reuse that shared key, and only its model value is new. `SHIFT_AI_PROVIDER` and `SHIFT_NVIDIA_TEXT_ROLE` are not required. The server defaults to NVIDIA and uses Mistral first, then GLM; if only GLM is configured it becomes the active text model automatically. GLM and Mistral model names remain hidden from the Flutter UI. This assumes the key has authorized access to the model through NVIDIA; the deployment does not prove a live model invocation succeeds.
