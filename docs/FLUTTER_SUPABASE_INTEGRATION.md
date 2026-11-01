# SHIFT Flutter ↔ Supabase integration (phase 1)

Implemented on `mobile/`:
- Email/password registration, sign-in, password recovery, verification-email resend.
- Startup restoration of Supabase persisted authentication.
- Signed-in workspace, profile, brand and preferences load/save.
- Cloud text draft creation, version history and planning-date storage.
- Cloud approval submission and approval/rejection through owner-checked database RPCs.
- Cloud sign-out, isolated device-only workspace retained.
- Client ID migration enables device-generated post identifiers without pretending they are UUIDs.
- Local workspace remains separately accessible without account setup.
- Google sign-in, social OAuth, media syncing, AI and scheduling intentionally remain unavailable.

## Required local build configuration
Use a publishable key (never a secret or service_role key) from the SHIFT Supabase dashboard.

```sh
cd mobile
flutter pub get
flutter analyze
flutter run --dart-define=SHIFT_SUPABASE_PUBLISHABLE_KEY=YOUR_SHIFT_PUBLISHABLE_KEY
```

Do **not** commit keys into the repository. For release builds pass the same Dart define in CI as a protected configuration value.
The project URL is `https://axgzpbtnqhuytlsanyto.supabase.co`.
The repository currently does not contain `pubspec.lock`; generate it using Flutter and commit it after dependency resolution.

## Important boundaries
Existing local posts/photos are **not** migrated automatically. No remote change overwrites the stored local workspace, and local review decisions are not imported as cloud approvals.
Cloud post text/version history can sync. Referenced image paths and media files remain local until a secure storage upload implementation is added.
Research bookmarks currently remain local and should not be assumed cloud-backed. Data deletion for signed-in cloud drafts is disabled until the explicit cloud delete flow is implemented.
Publishing and autopilot are still disabled and there is no social provider authorization or server worker.

## Verification still required
This implementation was made through GitHub and Supabase connectors. There is no Flutter/Dart SDK in the available execution environment, so dependencies could not be resolved and no compile, device test or automated Flutter test was executed.
Run the commands above on a machine with the repo's compatible Flutter/Android toolchains.
Manually verify: registration with email confirmation, password reset email, sign-in and restart, sign-out and re-login, onboarding, cross-user isolation, cloud version edits and stale review rejection, offline retry, and local data preservation.
