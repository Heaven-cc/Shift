# SHIFT registration configuration fix — 2026-11-03

## Root cause

The Flutter app loaded its Supabase publishable key exclusively with
`String.fromEnvironment('SHIFT_SUPABASE_PUBLISHABLE_KEY')`.
Without `--dart-define`, its value was empty, `ShiftCloud.initialize()`
returned early and the registration screen showed "cloud authentication is not configured".

## Change

`mobile/lib/core/cloud/shift_cloud.dart` now uses the **active SHIFT-project publishable key**
as a default while preserving optional `--dart-define` overrides.
This is a public client key intended for distribution in a mobile application;
**never** put `sb_secret_...`, `service_role` or third-party OAuth secrets in the app.
The project URL remains `https://axgzpbtnqhuytlsanyto.supabase.co`, completely
separate from TREXVEN's backend.

## Build and verify

```sh
cd mobile
flutter pub get
flutter analyze
flutter build apk --release
```

Install the newly built APK on your phone. An already installed old APK will
still show the missing-key message because it contains the previous configuration.

Verify opening the registration screen no longer shows a missing-key notice;
register with a valid email, check email confirmation and sign in.
If you encounter a new error about email rate limits, mail delivery, redirect URLs,
account provisioning or authorization, diagnose it separately using Supabase logs
and Auth settings. Those cannot be proved merely by configuring this key.

Flutter compilation/device tests were not run in this connector session.
