# SHIFT AI workspace — text and planning tools

## Available code paths

SHIFT's Flutter Studio invokes the workspace-scoped `shift-generate-text` Supabase Edge Function. This backend now uses the chosen server-side `SHIFT_AI_PROVIDER`, `SHIFT_AI_MODEL` and `SHIFT_AI_API_KEY` secrets. Groq remains optional, not required. Neither key nor secret belongs in the mobile application.

Studio now supports:
- Original caption/headline/hashtag generation
- Rewrite a draft
- Change tone to the selected tone and the saved brand voice
- Shorten or expand while preserving factual qualifications
- Suggest headline hooks and relevant hashtags
- Generate five brand-aware content ideas, selected explicitly by the user
- Build a brand-aware strategy (positioning, content pillars, cadence, and experiments)

AI text operations use the existing authenticated, rate-limited generation job flow. They read the *authoritative online workspace* brand name, description, tone, guidelines, niche, audience, market, interests, preferred language, and AI preferences. Content ideas, strategies, and editing results are saved as AI job results in Supabase; they are **not** automatically added to the calendar or published.

The editing controls show a preview for approval; selecting **Apply suggestion** changes the unsaved local editor draft and causes the usual explicit cloud-save/review flow. Generating ideas only sets instructions after selection. Existing publishing approvals are not bypassed. Suggestions do not establish evidence or live social performance.

Discover calls `shift-research`, which uses `SHIFT_BRAVE_SEARCH_API_KEY` stored only in Supabase and saves source history under the authenticated workspace. It uses brand niche, market, language and interests to contextualize the search. Research results are source leads, not verified claims. Saving a source to the library and generating from it does not guarantee the factual accuracy of its claims.

## What the user needs to configure

Only if not already set in the **SHIFT** Supabase Edge Function secrets:
- `GROQ_API_KEY`
- `GROQ_MODEL` (a model enabled for Groq JSON-mode chat completions)
- `SHIFT_BRAVE_SEARCH_API_KEY` for live research

Never put provider secrets in Flutter, Git, or conversations.

## Not yet implemented

- AI image generation: requires selection of a supported image model/provider and credentials. Its button must not pretend to produce images.
- Automatic trend monitoring/research while the app is closed; AI autopilot is paused intentionally.
- Provider-derived performance recommendations while no eligible connected social accounts and analytics data exist.
- Fully automated content calendar generation or approval-free publishing.
- End-to-end provider model tests, which require a configured provider and authenticated user.

## Verification

Run Flutter CI, static analysis and widget tests. Deploy `shift-generate-text` from this branch. Test draft, rewrite, hooks, ideas, strategy using a signed-in test account with a real Groq model. Confirm only the correct workspace's brand information is used and generated drafts still require human review.
