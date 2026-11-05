# Postiz integration for SHIFT

**Status:** integration code ready for configuration. SHIFT's own publishing worker, autopilot and cloud scheduler stay paused. Postiz itself must be hosted and running to publish scheduled posts.

## Architecture

- Flutter calls the authenticated `shift-postiz` Supabase Edge Function.
- Postiz OAuth starts in a browser and ends at the Edge Function callback. It grants access to one Postiz workspace (not an unrestricted pool of social accounts).
- Access tokens are encrypted with AES-GCM and saved in `shift_postiz_connections`, which grants no client access.
- Posts can be submitted only after server-verified approval of their current saved version. Media and platform-specific posting modes are currently not enabled.
- Postiz runs its own scheduled publishing infrastructure; SHIFT does not run a publishing worker.

## Setup to activate

1. Deploy Postiz on a server with public HTTPS, following https://docs.postiz.com/ . Configure its database, Redis, app URL, API, worker and each desired social provider's developer credentials. Self-hosting alone does not provide pre-approved Instagram/Facebook/TikTok/X developer access.
2. In Postiz, under Settings → Developers, create an OAuth app and configure the exact callback URL:
   `https://axgzpbtnqhuytlsanyto.supabase.co/functions/v1/shift-postiz?action=callback`
3. Store the following in **SHIFT Supabase Edge Function secrets** (never in Flutter, README, or Git):
   - `SHIFT_POSTIZ_WEB_URL`: HTTPS root of the Postiz web UI
   - `SHIFT_POSTIZ_API_URL`: HTTPS URL ending in `/api/public/v1`
   - `SHIFT_POSTIZ_CLIENT_ID`
   - `SHIFT_POSTIZ_CLIENT_SECRET`
   - `SHIFT_POSTIZ_CALLBACK_URL`: exact callback URL above
   - `SHIFT_POSTIZ_ENCRYPTION_KEY_HEX`: randomly generated 32-byte secret encoded as 64 hex characters; back up securely (losing it makes existing tokens undecryptable)
   - Supabase standard `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` are normally injected by Supabase.
4. Deploy the `shift-postiz` Edge Function with gateway `verify_jwt=false` **only** because the OAuth callback cannot include user JWT. All non-callback requests explicitly call `auth.getUser` before accessing workspace data.
5. Deploy the database migration and inspect RLS. Do not enable a separate SHIFT publishing worker.
6. On a signed-in SHIFT account, open Social Accounts → Connect with Postiz → approve your Postiz workspace; add channels in Postiz and refresh SHIFT.
7. Approve a cloud-synced draft, choose a connected text-capable destination, and manually submit a future scheduled time. Check the Postiz dashboard for queue state; ambiguous results must never be retried automatically.

## Limitations

- The pinned published `@opencoredev/social-sdk@0.5.0` does **not** expose `/cloud/postiz`; the current Postiz bridge uses Postiz's official public REST API alongside that pinned package. Do not claim that the newer unreleased adapter is installed.
- No provider credentials or Postiz instance have been configured by this repository change.
- Text-only manual scheduling is guarded to X, LinkedIn, Facebook Pages, Threads, Bluesky and other supported text providers. Instagram, TikTok, YouTube, Pinterest, media uploads, cancellations and remote-status reconciliation need separate provider-specific handling and validation.
- This starter bridge is for controlled integration; before general release, add stronger error reconciliation/status polling, media workflows, and a production security review.
- The Postiz self-hosted service **does** need to stay running for scheduled publication; pausing SHIFT's own worker does not pause Postiz scheduled posts.
