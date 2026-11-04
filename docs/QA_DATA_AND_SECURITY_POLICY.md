# SHIFT — QA and test data policy

Never use real customer accounts, private posts or production OAuth tokens in automated tests. Production data must not be copied into a developer laptop, CI artifact, fixture or issue. Use fictitious emails with reserved example domains and generic stock-free text.

## Environment boundaries
- Production: Supabase `axgzpbtnqhuytlsanyto`, locked-down RLS, private Storage. Do not truncate or seed production for tests.
- QA: requires an independently created nonproduction project, separate database, keys, storage, OAuth redirect and test-mode provider accounts. Do not share the production service-role key.
- Local: ephemeral test DB or mocked clients, no secrets.
- CI: public Flutter publishable keys are acceptable only if clearly tied to intended environment; provider secrets should only be injected into protected jobs as masked secrets and never printed.

## Required fixtures
User A and User B with distinct workspaces; disjoint drafts, images, research records, one approved revision and one pending approval. Seed fake provider accounts as metadata **only** without pretending they are connected for real dispatch. Include SQL injection strings, Unicode, very large prompts, malformed URLs, account switching, deleted assets, duplicate idempotency tokens and backdated schedules.

## Negative tests
- User B cannot read/modify User A's records or storage paths, including privileged RPC calls.
- Anonymous clients cannot list posts, profiles or attachments.
- Direct client writes to publish queue, analytics sync, social account status and private usage counters fail.
- Edited approved posts lose approval, older versions cannot be approved, and failed uploads do not report cloud success.
- Disabled/expired Autopilot and disconnected provider credentials prevent dispatch even when old jobs remain queued.
- Consecutive request replay does not create duplicate versions or posts.

## Validation and reporting
Document test name, code SHA, environment/project identifier, test user identifiers (non-sensitive surrogate IDs), expected outcome, actual outcome, timestamps and an attached redacted log. Do not label checks done until passed. Re-run complete suite after every security-sensitive migration.
