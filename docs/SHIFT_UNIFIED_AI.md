# Unified SHIFT AI — one assistant, automatic routing

SHIFT has a single user-facing AI workspace. Users describe the task; they **do not select a provider or model**.

## Supported capabilities

The authenticated Supabase function `shift-unified` is the router for AI Workspace and Studio:

| Intent detected in the user's instruction | Server-side capability |
|---|---|
| Ideas, content strategy, campaign and calendar proposals | `shift-ai` with configured text generation |
| Captions and editing in Create/Studio | `shift-generate-text` through the same router |
| Explicit live research / competitor research | `shift-ai`; requires configured web-search provider |
| Search saved research | `shift-nemotron` embeddings, only if configured |
| Create images/posters/visuals | `shift-nvidia`, first configured image role |
| Edit an attached photograph | `shift-nvidia`, first configured image-edit role |
| Voiceovers / spoken audio | `shift-nvidia`, first configured voice role |

The server checks available NVIDIA slots using the private `SHIFT_NVIDIA_API_KEY` or per-slot override, exact model IDs, and valid NVIDIA HTTPS endpoints. Nonconfigured capabilities are **not displayed** in Flutter. The registry remains in backend source code so adding another credential later does not require rebuilding all adapters.

**Configured is not verified.** A configured NVIDIA model might still fail due to access, API schema, licensing, quota, or provider latency. The UI explicitly says successful inference must be tested. The prior Mistral Large 4 timeouts have not been proven resolved by routing alone.

## Text model fallback

For `shift-ai` tasks using NVIDIA, the selected text model is attempted first. If it fails with a network, invalid-request, malformed-response or timeout error, SHIFT can automatically try the *other* NVIDIA text role (Mistral or Kimi) **only if it has a configured key and model ID**. It will not retry on credential rejection or provider rate limits, and it will not call unconfigured models. Retry budgets are bounded.

## Security and behavior

- Model selection and keys stay entirely on the SHIFT Supabase backend; user input cannot set an arbitrary model ID or inference endpoint.
- The router forwards the authenticated user's JWT to the existing dedicated, ownership-checked SHIFT functions. Their authorization, rate limits and approval logic stay intact.
- An AI-generated calendar proposal is not a post publication. Accepting creates an unapproved draft; publishing requires separate action.
- The autonomous publishing/AI worker remains paused; existing manually approved social scheduling is untouched.
- Existing older mobile app versions can still call the prior functions directly for compatibility.
- No changes to TREXVEN repositories or Supabase.

## Deployment / verification

Deploy `supabase/functions/shift-unified/index.ts` with JWT verification and the modified `shift-ai` function. Build Flutter and confirm the unified workspace and Studio both use the new router. Test configured-only status, task detection, authenticated `job_status`, optional image/voice routing, and at least one real provider inference when credentials and an authenticated user are available.

Use the same `SHIFT_NVIDIA_API_KEY`, `SHIFT_AI_PROVIDER` and per-slot `SHIFT_NVIDIA_<SLOT>_MODEL` backend secrets already configured. No additional secret is required for the router.
