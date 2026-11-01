# SHIFT Supabase backend

## Environment
Dedicated SHIFT Supabase project: `axgzpbtnqhuytlsanyto` (not TREXVEN).
Project URL: `https://axgzpbtnqhuytlsanyto.supabase.co`
Flutter frontend root: `mobile/`.

Migrations are committed under `supabase/migrations/` and already applied to the SHIFT project.
Cloud-capabilities function is deployed at `/functions/v1/shift-capabilities` with JWT validation enabled.

## Data model
- `shift_profiles`: one profile per Auth user.
- `shift_workspaces`: one owner-only workspace per Auth user.
- `shift_brands`, `shift_preferences`, `shift_automation_policies`: onboarding, brand identity, and automation preferences; cloud automation cannot be enabled by the Flutter client.
- `shift_content_posts`, `shift_content_versions`: drafts, immutable revisions, plan date, and workflow status.
- `shift_approval_requests`: review of an exact content version.
- `shift_research_bookmarks`: saved HTTPS source links and notes.
- `shift_social_accounts`: metadata only, never OAuth tokens.
- `shift_media_assets` and private `shift-media` Storage bucket.
- `shift_research_jobs`, `shift_generation_jobs`: reserved for future AI services.
- `shift_publish_jobs`: reserved for server-controlled delivery, not client-writable.
- `shift_analytics_daily`, `shift_notifications`, `shift_activity_events`: provider-backed insights, notifications and audit events.

All 17 public application tables have RLS enabled. Owner checks use `auth.uid()`, not user-editable metadata. The platform-managed signup trigger provisions a profile, workspace, brand, preferences and disabled automation policy. User writes are restricted by column grants and ownership policies. Do not create social accounts or publish jobs in the client as a proxy for a real OAuth or publishing connection.

## Connect the Flutter app (not yet connected)
Install and pin a compatible `supabase_flutter` release in `mobile/pubspec.yaml` and commit the resulting `pubspec.lock`.
Initialize from environment/build variables with the project URL above and a **publishable** key from the SHIFT Supabase dashboard; never add a secret/service-role key to mobile code or Git.

Before replacing the existing local-first flows:
1. Authenticate using Supabase Auth and restore the session at app startup. Account users must not be identified using the current `Workspace.entered` flag.
2. Read the current workspace: `shift_workspaces.select().eq('owner_id', user.id).single()`. Auth provisioning creates it.
3. Map profile, brand, preferences and interests to their corresponding tables.
4. Map existing `LocalPost` IDs to server UUIDs; preserve versions. Client inserts a post with `workspace_id`, then inserts sequential `shift_content_versions` rows with `version_number` 1, 2, ...
5. Submit reviews using `rpc('shift_submit_for_review', params: {'p_post_id': postId})`.
6. Decide reviews using `rpc('shift_decide_review', params: {'p_review_id': id, 'p_approve': true/false, 'p_comment': note})`. Changes to content automatically invalidate approval and return the post to draft.
7. `shift_content_posts.planned_at` is **a planning date only**; it does not cause a publish job to execute.
8. Upload media to private bucket `shift-media` using a key beginning with `<authenticated user UUID>/`, retain its Storage key, and render using authenticated download or signed URLs.
9. Subscribe to notifications or poll data only after a user is authenticated.
10. Local drafts remain on the device until the user explicitly opts into migration. Do not treat existing local review states as server-approved.

## Operations that are intentionally not live
No Google or other OAuth provider has been enabled through this migration, and Auth settings/email delivery require separate configuration and verification.
No AI model, web research provider, image generation model, Meta app approval, Instagram/Facebook OAuth, token vault, publishing worker, push service, or provider analytics sync has been configured.
The `shift-capabilities` function accurately reports those features as unavailable. No process runs continuously in the mobile app; real automation requires scheduled server workers, provider credentials, scoped account grants, idempotent dispatch, retry control, and auditable approvals.

## Safety and validation
Never place provider secrets in the Flutter app or `shift_social_accounts`. Keep actual OAuth refresh/access tokens in a private vault accessible to tightly-scoped server functions only. Complete the official Meta App Review before using permissions to publish.
Do not grant authenticated clients INSERT/UPDATE rights to `shift_publish_jobs`, `shift_analytics_daily`, or `shift_social_accounts`.
The two deliberately callable SECURITY DEFINER review RPCs are restricted to `authenticated`, derive identity from `auth.uid()`, and check owner/current version/status inside the transaction. Supabase security advisors flag this intentional design for manual review.
Check `get_advisors` periodically. Run authenticated cross-user RLS tests and Flutter/device tests before enabling production sync.
