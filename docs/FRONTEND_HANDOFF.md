# SHIFT frontend handoff

## Authorized scope
Only the native mobile frontend was implemented. Existing Flutter concepts and monochrome direction were carried forward into a feature-first source layout. No backend was created, configured or deployed. No AI/MCP/server configuration belongs in the consumer settings UI.

The original mobile path is preserved to avoid a duplicate project. Previous sample posts, fake pending approvals and sample notifications have been removed. Legacy demo components, repository and its demo-only test were retired because all production navigation now uses typed local content and a persistent workspace controller.

## Screen and action inventory
| Area | Frontend behavior |
| --- | --- |
| Welcome / auth | Welcome and validated Register, Sign In, password reset, verification and Google actions. Auth requests show service-unavailable messaging; no credentials are saved or submitted. Local workspace is a separately labeled action. |
| Startup | Local workspace and theme restored before runApp; no transient login screen for returning local users. This is not Supabase session restoration. |
| Onboarding | Six steps: purpose, custom interests, brand identity, unavailable social connections, publishing preference, confirmed summary. Progress inputs persist on Continue. No automation is activated. |
| Home | Local draft/review counts, local plans, quick navigation, actual local activity; unavailable server metrics and grounded empty recommendations. |
| Discover | Search/filter UI, interest chips, saved HTTPS source URLs and notes, external browser links, source details, remove source and create-from-source. Sources are unverified bookmarks, not fetched research. |
| Studio | Instructions, goals, tone, audience, language, length, output preference, CTA, caption, hook, hashtags, device images, platform preview, autosave, explicit saves, new draft and local review submission. AI requests display unavailable states and preserve edits. |
| Drafts / details | Search/status filters, 30-at-a-time loading, image/caption previews, version history, restore as new version, edit, copy caption, feedback, delete, local planning dates and cancel local plan. |
| Approvals | Exact local versions can enter review, be approved locally or rejected to drafts. Editing or restoring content invalidates local review. These decisions carry no cloud publishing authority. |
| Calendar | Month grid with markers, weekly date strip, daily agenda, sorted list, date picker, previous/next/today, status filters and local plan details. |
| Insights | Period/platform filters, unavailable metrics, chart empty states, account-management link and honest unavailable sync. No sample performance values. |
| Accounts | Instagram Professional and Facebook Pages eligibility/capability descriptions; actual frontend state is disconnected. Other providers are marked planned. Connect actions explain unavailable OAuth. No false reconnect/disconnect controls are shown for nonexistent accounts. |
| Automation | Manual, approval and inactive Autopilot preferences; daily/weekly limits, categories, blocked topics, tone, generated-image/source requirements, weekdays, posting window and expiry. Autopilot preference requires explicit confirmation and remains inactive. Local pause is recorded; cloud activation/run-now are unavailable. |
| Settings | Profile/avatar, contact email, language, IANA timezone preference, full brand/logo/guidelines, AI preferences, light/dark/system, notification categories, local data reset, leave workspace, sessions/deletion unavailable states, FAQ and licenses. |
| Notifications | Empty server inbox and a separate real local activity timeline with navigation to relevant routes. Notification preference changes persist locally. |

## Local data and permissions
SharedPreferences stores non-secret preferences, bookmark metadata and versioned draft text. This is local storage, not a cloud backup or a transactional server database. Photos are copied into the app documents directory. Clearing the local workspace removes copied photos as well as text/preferences. Deleting an individual draft retains copied media until local data is cleared so older references are not accidentally destroyed.

Auth passwords, provider keys and social tokens are not persisted or logged. There are no service-role credentials. Secure storage and Supabase/FCM SDK integration should be added with actual authentication/push wiring, not as unused dependencies.

Autosave is debounced with an additional save on lifecycle pause. An immediate process kill or storage failure can still lose unsaved changes. Storage failures appear in the workspace and explicit save results. A failed restore does not silently overwrite the previous stored copy.

Local planning dates preserve a UTC instant plus a device timezone label. Profile timezone is a future server preference; this edition does not reinterpret plans into arbitrary IANA timezones or claim recurrence execution. Weekly posting preferences are saved but no recurring job exists.

No production seed data exists. Local review states must never be imported as trusted cloud approvals.

## Native configuration
- Provisional application/bundle ID: com.odt.shift. Confirm ownership before store release.
- Android: Kotlin FlutterActivity, Gradle Kotlin DSL, official Gradle wrapper, Android photo picker through image_picker, Internet permission, backups disabled, monochrome vector icon/launch surface.
- iOS: Swift FlutterAppDelegate, Xcode project/workspace/scheme, CocoaPods hooks, iOS 15 target, photo permission description, icon catalog and launch storyboard.
- iOS project scaffolding derives from Flutter's BSD-licensed templates; Gradle wrapper retains its upstream license. See docs/third_party.
- Machine-specific Flutter config, plugin registrants, CocoaPods output, local.properties and release signing files are intentionally generated locally/ignored.
- No Firebase files, push entitlements, OAuth redirect schemes or signing keys are invented.

## Next steps before launch
1. Run dependency resolution and Dart analysis using the selected Flutter SDK, format source, resolve compatibility issues and commit pubspec.lock.
2. Compile and visually review Android and iOS; exercise keyboard layout, large text, reduced motion, photo permissions, process restart, back navigation and storage errors.
3. Confirm identifiers, keystores, Apple team, provisioning and release privacy declarations.
4. Create the dedicated SHIFT Supabase backend in a later authorized phase. Add authenticated repository interfaces and typed server DTOs for workspace/profile/brand/content/research/approvals/schedules/notifications/analytics.
5. Replace local workspace access with real persisted Supabase session restoration and onboarding redirects. Migrate local drafts only after explicit user consent and conflict handling.
6. Wire AI/research/image APIs, official Meta OAuth, authorized destinations, server approval/version checks and durable scheduling. Add service-side validation, RLS and idempotency.
7. Connect FCM/APNs and server notifications/deep links; then display real job activity and available provider analytics.
8. Verify end-to-end cloud execution independently of the phone before enabling any automatic publishing.

## Deployment report
Supabase migrations/functions: none required or deployed by this frontend-only change.
Connected AI services: none.
Operational social publishing providers: none.
Missing: dedicated backend, provider credentials/approvals, push configuration, release signing and runtime verification.
Do not describe this edition as production ready.
