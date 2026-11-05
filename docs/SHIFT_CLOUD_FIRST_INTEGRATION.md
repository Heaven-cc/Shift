# SHIFT cloud-first workflow — November 2026

## What is connected

- Profile, creator brand, AI preferences, drafts, version history, and research bookmarks sync to the user's authenticated SHIFT Supabase workspace.
- Avatar and brand logo images are uploaded to private SHIFT Storage; only their remote paths are stored in database fields.
- Offline workspace is still supported but does not silently import data into signed-in accounts. Use the existing explicit import action.
- Onboarding saves to the current workspace and can load back signed-in data.
- Calendar combines real Supabase direct publishing jobs with planned posts, with explicit reschedule and cancel actions for queued jobs. Planning dates do **not** publish.
- In-app notifications use owner-scoped Supabase records (push remains unconfigured).
- Studio invokes the existing Groq text-generation function, using stored brand voice, guidelines, and audience. Generated content stays a reviewable draft.
- Discover invokes the server-side Brave Search function and persists research history. Server queries now include the saved brand niche and primary market; sources are **not independently verified**.

## Required external setup

To activate AI text generation, configure `GROQ_API_KEY` and `GROQ_MODEL` in SHIFT Supabase Edge Function secrets. To activate live web research, configure `SHIFT_BRAVE_SEARCH_API_KEY`. Do not commit API keys or paste them into Flutter settings.

Account linking currently supports a direct Bluesky app-password workflow only. Instagram and Facebook Pages need a Meta developer application, approved permissions, OAuth client credentials and redirect URIs; TikTok, LinkedIn, Threads, YouTube, X and Pinterest require their own developer/API setup. Provider requirements and app review vary.

## Social SDK implementation

The actual `@opencoredev/social-sdk@0.5.0` package is pinned in `integrations/social-sdk/package.json`. Its source exports `createSocial`, platform adapters and OAuth provider modules. SHIFT's **deployed Supabase `shift-direct` Edge Function** uses its real Bluesky adapter for the provider publishing call. An authenticated zero-job dispatcher invocation returned HTTP 200. Real post delivery hasn't been tested because there are no connected social accounts.

The published SDK declares Node.js/Bun runtime support; Supabase Deno can load npm dependencies but compatibility beyond the deployed zero-job path and real account publishing still needs verification. Other OAuth adapters cannot be activated without developer credentials and platform review.

Postiz files, tables and Edge Function are retained but its controls are hidden while self-hosted Postiz is unavailable. Do not remove this integration when improving Supabase scheduling.

## Remaining caveats

- Signed-in cloud saves rely on the existing Supabase row-level access policies. Cross-table preferences saves are sequential; a future atomic server-side transaction can strengthen consistency.
- Live social scheduling currently supports direct Bluesky text only; other platforms are previews until real OAuth and publishing logic is configured.
- The calendar displays the direct backend's first 100 server jobs. Filtering, server pagination, and robust notification delivery require further work at scale.
- A Flutter CI workflow was added; do not claim Android/iOS runtime correctness until it passes and a device build is tested.
- Supabase Cron/Edge Function usage may incur cloud charges, even though no VPS is needed.
