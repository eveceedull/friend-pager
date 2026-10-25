# Friend Pager

Best-effort private group paging without exchanging phone numbers.

## Status

**UI prototype only.** The demo has no backend, authentication, or notification delivery. Do not rely on it for urgent or emergency communication.

## MVP targets

Android, Windows, Linux, and web. iOS and macOS are deferred until Apple Developer enrollment.

## Architecture direction

Flutter for shared UI; Supabase for group membership, devices, heartbeats, and administration; FCM for Android push; Supabase Realtime for running desktop and browser clients.

## Engineering policy

- Never commit to `main`; submit feature branches via pull requests.
- Every PR must pass formatting, static analysis, automated tests, and target-platform builds.
- Green CI is a **necessary but not sufficient** release signal. Notification delivery, security, OS background behavior, signed binaries, and integration behavior require additional validation before a production release.
- Do not commit credentials or secrets.

## Local quick start

With Flutter installed:

```sh
flutter create --project-name friend_pager --platforms=android,windows,linux,web .
flutter pub get
flutter test
flutter analyze --fatal-infos
flutter run -d chrome
```

The native project runners are generated in CI until platform-specific integrations are introduced.
