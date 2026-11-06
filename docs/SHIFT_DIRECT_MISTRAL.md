# SHIFT AI — fixed NVIDIA Mistral text inference

SHIFT AI Workspace (`shift-ai`) and Studio (`shift-generate-text`) now use the same fixed server-side chat-completions configuration, following the simpler request structure used by TREXVEN Angel's Groq function.

- Endpoint: `https://integrate.api.nvidia.com/v1/chat/completions`
- Model: `mistralai/mistral-large-4-1t-a52b`
- `stream: false`; `Accept: application/json`
- `reasoning_effort: none`; `max_tokens: 4096`
- Timeout: 120 seconds per generation.
- Credentials: `SHIFT_NVIDIA_MISTRAL_API_KEY`, falling back to `SHIFT_NVIDIA_API_KEY`, exclusively in SHIFT Supabase Edge Function secrets.
- No GLM or other-model fallback for text. `SHIFT_AI_PROVIDER`, `SHIFT_AI_MODEL`, `SHIFT_AI_BASE_URL`, `SHIFT_NVIDIA_TEXT_ROLE`, and `SHIFT_NVIDIA_MISTRAL_MODEL` no longer select the text model.
- Media and semantic knowledge models remain separate and unchanged.

Only public model identifiers and endpoint are hard-coded. **Do not put the NVIDIA key in Flutter, GitHub, logs or this document.** The key must have NVIDIA Build access to this model; a model working in Playground is evidence the account can use it, not proof that the stored key has the same access.

Text requests still require a signed-in SHIFT account, workspace authorization, server-side rate limits and existing idempotent generation jobs. The response is a **reviewable draft**, never an automatic publication. Requests are routed by task (not model name); the frontend continues to display **SHIFT AI**.

For acceptance, sign in to the updated SHIFT app and generate a short content idea (Workspace and Studio separately). Check `shift_generation_jobs` for a `completed` record, verify the displayed content is populated, then check backend logs for `SHIFT AI Mistral completed` or `SHIFT Studio Mistral response completed`. Do not call it operational solely because code deployment is active. If it fails, distinguish HTTP status, empty visible content and timeout using the sanitized backend logs. Do not retry repeatedly or increase timeouts without isolating the failure.
