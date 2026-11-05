# SHIFT AI orchestration and backend-only credentials

## Active design
The new `shift-ai` Supabase Edge Function provides user-initiated research, competitor research, analysis of saved source leads, content ideas, brand strategy, improvement recommendations, and calendar proposal generation. The Flutter UI is at **SHIFT AI Workspace** (Home, Discover, Settings). User identity is verified by Supabase Auth. The backend selects the correct owner's workspace and loads the saved brand name, description, audience, niche, market, language, guidelines, interests and AI preferences for each request.

**No connection to TREXVEN or TREXVEN Supabase.** All operations use the existing dedicated SHIFT Supabase project.

## Configure your AI key in Supabase (backend only)
Go to the SHIFT project's **Edge Functions → Secrets** screen. Configure:
- `SHIFT_AI_PROVIDER` = one of `openai`, `gemini`, `groq`, `openai-compatible`.
- `SHIFT_AI_API_KEY` = the provider API key. Never paste it into Flutter or commit it.
- `SHIFT_AI_MODEL` = an enabled model ID for that provider, compatible with the selected endpoint.
- `SHIFT_AI_BASE_URL` = optional explicit HTTPS **chat completions endpoint** for `openai-compatible` only. It must not target a private/local host.

**Groq is optional** and not a hardcoded default. The legacy `shift-generate-text` feature still uses its existing `GROQ_API_KEY` and `GROQ_MODEL` until migrated or retired; its settings are separate from the new independent `shift-ai` service. The new AI Workspace does not consume the legacy Groq key.

The backend reports only the selected provider, model, and whether credentials are present; it never returns the API key.

## Web research access
An ordinary text-model key does **not** automatically grant internet access. The backend supports two grounded web research routes:
1. Set `SHIFT_BRAVE_SEARCH_API_KEY` in Supabase secrets to use Brave Search regardless of chosen AI text provider.
2. If the configured AI provider is `openai`, use OpenAI's Responses API with `web_search` for live research without a separate Brave key, provided the selected model/account supports this tool.

With no supported search route, research/competitor modes return `research_provider_not_configured`; strategy and ideation from existing brand information can still work. Research saves source leads in the generation result but **does not claim that search snippets are independently fact-checked**. The previous Discover search pipeline remains intact.

## Data and approval workflow
AI tasks use the existing `shift_request_text_generation` RPC and its per-user request rate limits and idempotency key. The resulting JSON and citations are persisted in `shift_generation_jobs` scoped to the authenticated workspace.

Calendar mode validates dates (at least one hour in the future, at most 90 days), platforms and text, and stores proposals in `shift_ai_plan_items`. This table is protected by owner-scoped RLS and does not allow direct client inserts or updates.

Only the authenticated workspace owner can explicitly invoke `shift_accept_ai_plan` to create a **new cloud draft** with its planning date. Acceptance does **not** authorize publishing, create a provider job, or bypass review. Users may select individual ideas. The existing calendar and approval workflow remain authoritative.

No model inference is initiated on a schedule; AI autopilot remains paused. Postiz is preserved for VPS activation later.

## Deployment and test requirements
- Migration: `shift_ai_plan_queue` under `supabase/migrations/`.
- Edge Function: `supabase/functions/shift-ai/index.ts`, `verify_jwt=true`.
- Flutter: `mobile/lib/features/ai/ai_workspace_screen.dart`, and navigation links.
- Test authenticated status, missing-key response, provider selection, search citation rules, rate limits, workspace isolation, generating 5 valid calendar items, and individual draft acceptance. Live provider tests require an API key and an actual signed-in account.

**Not supported:** AI image/video output, continuous autonomous trend monitoring, automatic publishing, verified social analytics without connected accounts, or direct entering of provider secrets in the mobile app.
