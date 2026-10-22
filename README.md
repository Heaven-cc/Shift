# SHIFT
Native Flutter Android/iOS social media workspace with a premium monochrome interface.

## Scope
This implementation is **frontend only**. No Supabase project, database, cloud function, AI provider, social connection, push service or publishing worker is configured or deployed. TREXVEN has not been touched.

The existing mobile directory is retained. The unused Next.js declaration and superseded demonstration screens are removed. There is no web application.

## Frontend
- Home, Discover, Create, Calendar and Insights in a state-preserving five-tab shell.
- Light, dark and system themes; shared design tokens and restrained glass panels.
- Welcome, Register, sign-in, reset and verification forms with honest unavailable-service states.
- Explicit local-workspace access and six-step setup, restored at launch.
- Persistent local draft editor, image selection, versions, review queue, local planning and caption export.
- Source bookmarks, public source links and source-to-editor workflow, clearly marked unverified.
- Calendar month, week, day and list views with local planning dates.
- Profile, brand, avatar/logo, AI preferences, accounts, automation boundaries, appearance, notification preferences, local activity, privacy controls and help.
- Native Android and iOS projects with launch surfaces and monochrome app icons.

Production-only operations report the missing service. They never fabricate account authentication, research, analytics, approval authority, schedules or publishing.

## Run
Use an existing Flutter SDK (Flutter 3.29 or newer; SDK/plugin compatibility must be checked on the chosen release), Android SDK and JDK 17:
```sh
cd mobile
flutter pub get
flutter run
```

iOS additionally requires macOS, Xcode and CocoaPods. Run flutter pub get, then pod install in mobile/ios and open Runner.xcworkspace. Choose a signing team and confirm the bundle identifier. Signing credentials are not included.

## Verification
Flutter and Dart were unavailable during implementation. No analyzer, Flutter tests, native builds, device run, accessibility run or visual runtime review was performed. Native XML, plist and YAML were parsed and local import paths were checked. These source checks do not establish compilation or runtime correctness.

See [frontend handoff](docs/FRONTEND_HANDOFF.md) for the screen/action inventory and remaining work.
