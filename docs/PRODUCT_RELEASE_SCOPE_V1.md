# SHIFT v1 — scope and acceptance (engineering baseline)

Status: Proposed implementation baseline, pending owner's release approval.
SHIFT is a native Flutter app (Android first in the engineering pipeline; iOS remains supported source but no Apple distribution decision has been made), backed by its dedicated Supabase project. It is not a website, does not rely on the app staying open, and must not import TREXVEN users or secrets.

## Core promise
A user can define their brand, research original content ideas with attributable sources, create text and images, review the exact revision intended for publication, and schedule or publish to explicitly connected, supported social destinations. Offline editing is allowed but **no content may be falsely marked synced, authorized or published**.

## Actors and tenancy
- Individual creator: one personal workspace, their own media and connected destinations.
- Influencer/freelancer: individual workspace with professional brand settings.
- Business/brand: one owner workspace with business voice and eligible social accounts.
- Agency and teams: v1 uses separate accounts with no implied access to client accounts. Multi-workspace delegation and collaborator permissions are postponed until explicit server-side role design.
Every workspace is owned by an authenticated Supabase user. No role inferred from user-editable metadata.

## Required release workflows
1. Register with verification, sign in, recover password, sign out, delete account and export data.
2. Onboard brand and preferences, create/edit/restore draft versions, attach private images, review exact version.
3. Conduct live research with source URLs, timestamps, provenance labels and cautious summaries.
4. Generate original drafts with selected AI provider on the **server only**. Keep texts editable and user-controlled; no unfounded performance or source claims.
5. Connect an eligible Instagram professional account or Facebook Page using official provider OAuth. Use least privilege and a token vault.
6. Queue approval-authorized scheduled content, dispatch through server while device is closed, verify provider response, retry safely, show failures and allow emergency stop.
7. Show provider-sourced analytics with clearly distinguished missing data.
8. Enforce budgets, ownership, audit events, privacy, tests and recovery controls.

## Deliberate exclusions until independently authorized
- No scraping private social accounts, bypassing platform permissions, personal Instagram publishing, purchased followers, mass unsolicited interactions or engagement manipulation.
- No autonomous publishing without user opt-in and verified destination permissions.
- No AI output presented as verified journalism or evidence-backed analytics unless supported by retrieved sources.
- No multi-user agency delegation until a tested roles and consent model exists.
- No subscriptions or paid trials until applicable app-store payment rules are implemented and verified.
- No continuous on-device workers claiming guaranteed delivery; durable work runs on a server.

## Release gates
G01 clean CI/release build and device boot; G02 authenticated account lifecycle; G03 tenant isolation; G04 cloud content; G05 exact revision review; G06 AI/research quality; G07 official social authorization; G08 provider-confirmed background publish; G09 failure and duplicate defense; G10 pause/consent; G11 privacy/security/account deletion; G12 store compliance; G13 operating recovery.

Each gate needs a dated CI/run ID, test evidence, exact code SHA and owner review. A deployed SQL migration is not proof of app functionality.
