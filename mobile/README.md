# SHIFT Mobile

Flutter-native Android/iOS frontend. The mobile app is the user interface; 24/7 research and publishing will run in cloud workers with a dedicated SHIFT Supabase backend.

## Start
1. Install Flutter.
2. From this folder run `flutter create . --platforms=android,ios` to generate platform runners (requires the relevant platform tooling).
3. Run `flutter pub get`, then `flutter run`.

This commit includes Flutter application source and project configuration, not generated Android/iOS runner directories. No cloud processing, authentication, AI or social publishing is connected. The existing Next.js prototype remains in the repository for now, unchanged.
