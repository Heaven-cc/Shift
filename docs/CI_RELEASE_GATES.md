# SHIFT Flutter CI and release gates

The `flutter-ci.yml` workflow resolves packages, runs `flutter analyze` and `flutter test` in one job, and builds a debug Android APK in another. It publishes a 7-day artifact. The Flutter stable channel and JDK 25 are used because SHIFT currently requests Flutter >=3.44 and Gradle runs on JDK 25.

The app has never been shown passing this workflow in the current engineering session. A committed workflow is **not** evidence of a green build. Check GitHub Actions for the actual result and repair failures before release.

Never put a Supabase secret key, service-role key, Groq/Brave token, Google OAuth client secret, Meta token, or Play signing keystore in a mobile build or public CI artifact.

Production release gates:
- Resolve dependencies and commit a tested `pubspec.lock`.
- Analyze, unit/widget tests, Android release signing and device tests pass.
- Verify two-user RLS access isolation, auth callback flows, Google/Meta OAuth once provisioned, offline sync/restart and data deletion.
- Confirm no publishing background worker is enabled until provider authorization and account-specific policy consent have been verified.
