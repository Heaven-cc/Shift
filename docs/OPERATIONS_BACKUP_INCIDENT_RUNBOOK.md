# SHIFT — operational recovery, backup and incident response

Status: operational runbook draft; actual restore rehearsal and alert delivery remain to be tested.

## Recovery objectives (proposed, owner approval required)
Tier 1: account authentication, drafts and approvals — target RPO 24 hours, RTO 8 hours until PITR is purchased/validated; if tighter guarantees are required, provision backups/PITR before launch. Tier 2: analytics aggregates and reproducible research caches — RPO 48 hours, RTO 24 hours. These are engineering objectives, not Supabase service guarantees.

## Backup and restore
1. Identify the project, database migration version, code SHA, backup timestamp, provider outage and affected customers.
2. Suspend publishing via a server-side dispatch kill switch before schema rollback or credential rotation. Never assume hiding the mobile button stops an existing queue.
3. Export a production backup using an authorized service role or project backup service into encrypted storage with restricted access; maintain retention and integrity hashes.
4. Restore **only into a fresh nonproduction project** during rehearsal. Apply migration history, rotate QA credentials, verify table counts, auth metadata, RLS, storage and account ownership.
5. Measure actual RPO/RTO; record issues and owner sign-off. Do not claim restored production without validating data consistency and approvals.
6. For production recovery, reconcile provider-post IDs before retrying any scheduled job. An uncertain provider response is not a safe reason to repost.

## Unauthorized/bad post incident
1. Stop publisher and Autopilot at the backend; record timestamp and reason.
2. Revoke the affected destination tokens in provider controls and disable scheduled jobs for that account.
3. Preserve redacted audit evidence, job IDs, exact approved version fingerprints and provider response metadata.
4. Determine whether content was actually published before attempting remediation; avoid duplicate posts.
5. Notify affected user, follow applicable platform complaint/incident procedures, and implement safeguards.
6. Only re-enable after root-cause review, approval and regression tests.

## Provider outage
Classify errors: 401/403 -> reconnect; 429 -> honor provider rate limit and backoff; 500/503/timeouts -> bounded retry with idempotency safeguards; unknown outcome -> hold for reconciliation, not blind retry. Use alerts for queue age, claim leases, timeout frequency, quota spikes and publishing failures. Disable one provider without affecting another.

## Secrets rotation
Maintain inventory of environment secret identifiers (never plaintext values), owner, rotation date, dependent functions and rollback procedure. Rotate provider credentials, validate new token access in nonproduction, deploy and invalidate old credentials. Keep tokens out of Flutter and logs.

## Production sign-off
A real nonproduction restore, webhook/token expiry drill, pause test and metrics alert delivery test are mandatory before marking operations complete.
