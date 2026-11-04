# SHIFT Flutter CI and release gates

The `flutter-ci.yml` workflow resolves packages, runs `flutter analyze` and `flutter test` in one job, and builds a debug Android APK in another. It publishes a 7-day artifact. The Flutter CI toolchain is pinned to Flutter 3.47.9, JDK 17, Android Gradle Plugin 8.11.1, Gradle 8.14 and Kotlin 2.2.20. The Gradle daemon JVM must also be 17 to avoid Kotlin JavaVersion.parse failures.

The app has never been shown passing this workflow in the current engineering session. A committed workflow is **not** evidence of a green build. Check GitHub Actions for the actual result and repair failures before release.

Never put a Supabase secret key, service-role key, Groq/Brave token, Google OAuth client secret, Meta token, or Play signing keystore in a mobile build or public CI artifact.

Production release gates:
- Use the committed `pubspec.lock` and verify `flutter pub get --enforce-lockfile` with the pinned Flutter toolchain.
- Analyze, unit/widget tests, Android release signing and device tests pass.
- Verify two-user RLS access isolation, auth callback flows, Google/Meta OAuth once provisioned, offline sync/restart and data deletion.
- Confirm no publishing background worker is enabled until provider authorization and account-specific policy consent have been verified.
