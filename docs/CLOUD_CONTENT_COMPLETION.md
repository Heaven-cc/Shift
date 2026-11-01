# SHIFT cloud content completion

Implemented in this change:
- Authenticated research bookmark create/list/delete. Cloud bookmarks load when signing in.
- Private image uploads to the existing SHIFT `shift-media` bucket with user-prefixed object paths, 10 MB limit and media metadata.
- Image restoration from private Storage into an app-local cache when loading cloud posts.
- Cloud draft deletion restricted to drafts; deletion failures leave the current UI intact.
- Explicit **Import device drafts to SHIFT Cloud** in Settings > Privacy & security. Original device text, images, and local review state remain unchanged. Imported content defaults to draft and never imports local approval authority.
- No social publishing or AI jobs are enabled.

## Attention before production
Cloud image upload and download code requires Flutter runtime integration testing. A missing image on the device causes upload to fail rather than silently mark that image as safely backed up. Image downloads are cached locally, and clearing app files removes that cache.
The existing codebase does not have a committed Flutter lockfile, and Flutter/Dart are not installed in the current execution environment; therefore compilation and device verification are **not** claimed.
To build:
```
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=SHIFT_SUPABASE_PUBLISHABLE_KEY=YOUR_SHIFT_PUBLISHABLE_KEY
```
Do not store any service-role keys or social provider tokens in the Flutter app. OAuth, research/generation provider credentials, publishing accounts, production schedule workers, and push notifications still need external integrations and testing.
