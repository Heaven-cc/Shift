# SHIFT — Native Flutter App

SHIFT is a native-first Android/iOS social media manager. The retired Next.js web prototype is not the product.

## Mobile frontend
- `mobile/lib/main.dart` — mobile dashboard, Discover, Create, Calendar, Analytics and Settings
- `mobile/lib/welcome.dart` — onboarding preview
- `mobile/lib/feature_hub.dart` — approvals, social accounts, brand profile, automation controls and notifications
- `mobile/lib/shift_models.dart` — typed content and workspace models
- `mobile/lib/shift_repository.dart` — data repository contract and in-memory demo implementation
- `mobile/lib/ui_components.dart` — reusable glass UI components

## Status
This repository contains Flutter application source and configuration. Android/iOS platform runners still need to be generated with Flutter tooling. It has not been compiled or tested in this session. The UI currently uses demo data and local session state, not real accounts or live publishing.

## Preparing native builds
Run `flutter create . --platforms=android,ios` from the `mobile` directory with a Flutter SDK installed, followed by `flutter pub get` and `flutter run`. Building iOS requires supported Apple build tooling.

## Cloud architecture
The eventual always-on research and publishing workers will run independently of the phone, with dedicated SHIFT Supabase services. No TREXVEN infrastructure is shared.

## Safety
Do not use production social credentials in the demo. No real posting, AI generation or OAuth is currently implemented.
