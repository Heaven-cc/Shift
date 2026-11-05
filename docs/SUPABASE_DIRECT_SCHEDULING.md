# SHIFT scheduling without a VPS

**Active scheduling path:** SHIFT Supabase (Cron + Edge Function + Postgres queue).  
**Preserved, inactive path:** Postiz; its code, database tables, Edge Function and Social SDK integration remain in the repository for a future VPS. No Postiz call is required by SHIFT's active scheduling controls.

## What is live now

- Supabase Cron job `shift-direct-publish-every-minute` runs every minute.
- `shift-direct` Edge Function is the authenticated API for users and the separately authenticated dispatcher endpoint.
- Every user action verifies the Supabase Auth JWT on the server and checks ownership of a SHIFT workspace.
- Direct account credentials are stored in Supabase Vault, with no client SELECT or INSERT grants to sensitive tables.
- Scheduling requires the exact approved cloud content version, an eligible connected account, a future time, and the workspace's daily limit.
- Due jobs are claimed atomically with `FOR UPDATE SKIP LOCKED`. A dispatched job is never automatically resubmitted after an uncertain provider response.
- Job states include `queued`, `processing`, `published`, `unknown`, `failed`, `canceled`. Cancelling is only permitted before dispatch.
- The dispatcher is invoked through `pg_net`; its random one-time authentication key is generated and kept in Supabase Vault and never committed to Git.

## Provider support

**Implemented first:** Bluesky text posts. Users connect a Bluesky account using a *dedicated app password*, which the server validates with Bluesky's official API before storing it in Vault. The mobile app exposes this under **Social Accounts → Supabase publishing**. Approved Bluesky text drafts can be scheduled from Post Details.

**Not yet connected through the direct backend:** Instagram, Facebook Pages, TikTok, YouTube, LinkedIn, Threads, X and Pinterest. Their Flutter preview cards remain visible, but they require developer app credentials, official OAuth, media format handling and publishing adapters before SHIFT can schedule them. Showing a platform in the interface is not proof of an active connection.

The existing `@opencoredev/social-sdk@0.5.0` is a **Node.js SDK**, not an automatic set of provider credentials or a Flutter package. It remains in the repository for supported integrations. Supabase Edge Functions use Deno; this limited direct Bluesky adapter calls its public API using `fetch` rather than pretending to run the Node SDK.

## Workflow

1. Sign into SHIFT (not local-only workspace).
2. Open Social Accounts. In **Supabase publishing**, enter a Bluesky handle and app password created in Bluesky account settings. Don't use your main Bluesky password.
3. Create a Bluesky text draft and save it to your cloud workspace.
4. Submit the exact saved revision for review and approve it in the cloud.
5. Open the post, select **Schedule with Supabase**, choose your connected Bluesky account and a future local time, and confirm.
6. The backend saves the UTC schedule. Supabase Cron checks every minute and sends due posts. The phone need not remain open.

A local calendar planning date is **not** a server schedule. The dedicated Schedule action creates the server queue record.

## Security and operational behavior

- No server/service-role API key is included in Flutter or the Git repository.
- The Cron secret is kept in Vault. The Edge Function explicitly verifies it against Vault through a service-role-only RPC. The gateway must have `verify_jwt=false` solely because the Cron request does not carry a user's JWT; regular actions call Supabase `auth.getUser` independently.
- The dispatcher cannot publish media posts, arbitrary client content, or unapproved content; every due job is revalidated against its locked approved revision.
- Bluesky currently supports text-only in this integration; posts longer than 300 UTF-8 bytes are rejected.
- Every outbound publish request may have an ambiguous outcome after a timeout. Those jobs are marked `unknown` and must be investigated manually, not retried automatically.
- Monitor `shift_direct_jobs`, Edge Function logs, and Supabase Cron Job History for failures. Daily rate limits and account expiry should be reviewed before scaling.
- Postiz scheduling is not activated by Cron. There is no VPS requirement for this direct Bluesky path.
- Future provider additions need secure OAuth callbacks, scoped storage of refresh tokens, token rotation, provider-specific validation, signed or authenticated webhooks where available, and end-to-end publication tests.
- Supabase costs, quotas and Cron/Edge Function limits still apply.

## Deployments

Migration `supabase/migrations/20261105112924_shift_direct_cron.sql` applied only to the existing SHIFT Supabase project.

Edge Function `supabase/functions/shift-direct/index.ts` deployed with `verify_jwt=false`; all non-Cron actions authenticate and authorize users in code.

**Do not** delete `supabase/functions/shift-postiz`, `integrations/social-sdk`, or the Postiz schema. These are retained for the VPS option.

## Validation

Database migration applied. Cron scheduled and active; read-only inspection confirmed the queue starts empty and secret storage is restricted. A no-due-jobs scheduler tick succeeded. Function deployed. **Live account OAuth, publishing, Flutter analyzer and device testing are not yet completed**; a real Bluesky app password and explicit schedule are needed for an end-to-end test.
