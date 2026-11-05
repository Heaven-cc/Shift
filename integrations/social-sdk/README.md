# SHIFT Social SDK — paused cloud execution

This directory establishes a **server-side, offline-only** integration foundation for `@opencoredev/social-sdk@0.5.0`. It **does not** connect social accounts, publish real posts, run a scheduler, create a worker or deploy anything. SHIFT's dedicated Supabase project and Flutter app are unchanged.

## Verify locally

Use Node.js 22.12+:

```bash
cd integrations/social-sdk
npm install
npm run check
npm run smoke
```

The smoke script uses the SDK's deterministic mock backend. It does not need credentials and cannot publish to real accounts.

## Current policy

- Cloud publishing worker: **paused / not deployed**.
- Background scheduler, recurring jobs and autopilot: **paused**.
- Live social API publishing and OAuth: **not connected**.
- No platform access tokens or provider credentials may be stored in Flutter or committed to Git.
- A manual live publishing route must not be enabled until server-side authentication, ownership checks, account token custody, consent, rate limits, idempotency, delivery reconciliation and audit logs are in place.
- Calendar planning, local drafts, and manual review can continue independently of automated execution.

## Resume later

When explicitly approved, implement a secured API service with account connection/OAuth, encrypted token handling, user/workspace authorization and manual publishing endpoints. Then separately implement scheduling and retry workers. Social SDK must run on a trusted Node.js 22.12+ or Bun runtime rather than in Flutter.

**Do not interpret this mock adapter as completion of social account integration or cloud automation.**

## Exposed in the Flutter UI

Social Accounts, onboarding, Studio destination preview and Insights now include Instagram, Facebook Pages, TikTok, LinkedIn, X, Threads, YouTube, Bluesky and Pinterest. Instagram/TikTok/LinkedIn/X/Threads/YouTube/Bluesky have direct SDK adapters; Facebook Pages and Pinterest require a separate API adapter or provider. All connection buttons currently open honest provider setup instructions, not a fake OAuth flow. No account is connected. The SDK mock validates the publishing contract without making live provider requests.

## Remaining for live manual posting

Provider developer registrations, OAuth scopes/verification, trusted Node-hosted REST service, secure tokens, Supabase ownership verification, account link/list/revoke, content and media validation, per-platform publish dispatch, outcome reconciliation and real platform integration tests. This branch does **not** implement live OAuth or publication. The cloud publishing worker and scheduled automation remain paused.
