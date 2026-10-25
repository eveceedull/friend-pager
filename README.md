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

Use Flutter 3.47.8, revision `737ba8f885dc774b53b442759999a312c9461e4e`, matching the SDK pinned in `.github/actions/setup-flutter/action.yml`. With Flutter installed:

```sh
bash tool/generate-runners.sh
flutter pub get --enforce-lockfile
flutter test
flutter test --platform chrome
flutter analyze --fatal-infos
flutter run -d chrome
```

The platform runners are generated in CI until platform-specific integrations are introduced. Run the bootstrap script once from Bash (Git Bash on Windows); it creates temporary scaffolding and copies only platform folders, preserving application code and the lockfile. It refuses to overwrite existing runners.

## Validation limits

CI enforces Dart formatting, fatal static-analysis diagnostics, widget tests on the Flutter VM and Chrome, a 65% minimum line-coverage baseline, and release compilation for all four target platforms. The widget tests exercise actual slider gestures, cancellation, resetting, and sending with receiving disabled. The coverage percentage is a floor, not proof of behavioral correctness.

Native builds verify compilation only. Android currently uses the generated runner's debug signing configuration; these are not distribution-ready signed releases. Native device interaction, installation, background behavior, accessibility, and notification delivery still require validation. The prototype sends no real alerts.

Repository administrators should select `Flutter analysis and tests`, `Build web`, `Build android`, `Build linux`, and `Build windows` as required status checks on main. An enabled required-status-check rule with an empty check list does not enforce these jobs. CI changes must preserve full-SHA action pins, including any transitive actions.
