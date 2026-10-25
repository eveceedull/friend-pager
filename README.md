# Friend Pager

Open-source, best-effort private group paging without exchanging phone numbers.

## Current scope

The app joins one password-protected group, registers this installation with a required non-unique display name and device label, restores its session, and saves its receiving preference. The backend enforces access rules and supports administrator revocation and password-protected rejoin.

**Sending is still a labeled demo. No real alerts or notifications are sent.** Admin dashboard UI, ongoing heartbeats, Realtime alert distribution, and FCM are future work. Do not rely on the prototype for urgent or emergency communication.

Targets: Android, Windows, Linux, and web. iOS and macOS remain deferred.

## Local setup (Windows and Linux)

Prerequisites: Flutter 3.47.8 (revision `737ba8f885dc774b53b442759999a312c9461e4e`), Docker Desktop/OrbStack or a compatible Docker Engine, Supabase CLI **2.122.0**, Python 3, and Bash (Git Bash on Windows). Use `python3` in the commands below; configure that command for your Python installation if needed.

```sh
export SUPABASE_TELEMETRY_DISABLED=1 DO_NOT_TRACK=1
flutter config --no-analytics
bash tool/supabase.sh start
python3 tool/prepare-local.py
bash tool/generate-runners.sh
flutter pub get --enforce-lockfile
flutter run -d chrome --no-web-resources-cdn --dart-define-from-file=.local/config.json
```

Run runner generation once; it refuses to overwrite existing platform folders. It preserves application sources and dependency locks. Run Windows or Linux using `flutter run -d windows` / `-d linux` with the same config argument.

The public local group password is **`local-group-password`**. Local synthetic admin credentials are **`local-admin@example.test` / `local-admin-password`**. These are disposable test fixtures, never production credentials. The admin account can authenticate against local Supabase Auth; the admin screen is not implemented yet. The bootstrap provisions it through the local admin API and a private database allowlist. No ordinary user can create an administrator, including through user-editable Auth metadata.

`.local/config.json` contains only the local URL and public API key. The bootstrap obtains the service-role key in memory from the local CLI; it is never placed in app configuration. Group passwords are checked against a private bcrypt hash and never stored by the app. Supabase Flutter persists the installation's Auth session in its platform preferences; clearing app/browser data creates a new installation identity.

For an **Android emulator**, copy `.local/config.json` to `.local/config.android.json` and change the URL host to `10.0.2.2`. For a physical Android device, use the development computer's private LAN IPv4 address and allow the local port through its firewall. Run with `--dart-define-from-file=.local/config.android.json`. Generated Android debug runners permit local HTTP; release runners have no cleartext exception and are compilation checks only.

## Local-only operation

App startup rejects hosted URLs and public addresses. The supported dev URLs are HTTP on loopback or private literal IPv4 addresses. There is no hosted fallback, external identity provider, push integration, SMTP provider, or SaaS project link. Keep credentials and local configs out of Git. This branch intentionally does not support connecting the app to production.

The wrapper creates an **internal Docker network** to prevent stack containers from reaching external services. CLI telemetry and the stack's analytics service are disabled. Web builds use local CanvasKit resources and a bundled, licensed Roboto font; fallback fonts are requested only from the app origin. Unsupported glyphs may display as missing characters until more fonts are bundled. Dependency, SDK, CLI, and container-image installation still downloads build artifacts; application/test operations use the local stack. Launch Flutter web with `--no-web-resources-cdn` as shown above.

Local service ports: API 54321, PostgreSQL 54322, Studio 54323, test email inbox 54324. Treat these as development services with public fixture credentials. The local bootstrap requires loopback API access; it will reject a remote URL.

```sh
# Rebuild ONLY the local DB, applying migrations and public synthetic seed data.
# This deletes local development registrations and Auth users.
bash tool/supabase.sh reset
python3 tool/prepare-local.py

# Stop without deleting development data.
bash tool/supabase.sh stop
```

## Testing

```sh
flutter test --coverage
flutter test --platform chrome
flutter analyze --fatal-infos
# Against the real Docker stack (after starting/resetting and preparing it):
flutter test --dart-define-from-file=.local/config.json test_backend
```

CI runs formatting, fatal static analysis, VM and Chrome widget tests, the existing 65% line-coverage floor, and Android/Windows/Linux/web release builds. Its additional **Local Supabase integration** job starts a disposable stack, resets migrations, provisions only synthetic fixtures, and runs the actual Dart client against Auth and PostgREST. It checks duplicate names, metadata validation, session restoration, receiving persistence, cross-device RLS, unauthorized writes, wrong-password throttling, admin role isolation, revocation with an existing token, and password-protected rejoin. No hosted Supabase/Firebase credentials are needed.

The join endpoint limits each Auth identity to five attempts per 15 minutes. Supabase Auth also limits anonymous signups per IP. This is a local foundation; production will need a reviewed IP-level abuse policy and anonymous-user retention strategy, not just per-identity throttling. Device metadata is supplied by the client and is informational, not trusted for authorization.

## Engineering and release limits

Never commit directly to main. Every change goes through a PR; never merge without explicit approval. All existing checks and `Local Supabase integration` should be required on main. Do not weaken tests or quality gates to make CI green.

Green CI verifies the tested behavior and compilation. Native installation/device interaction, background operation, delivery, accessibility, platform-secure session storage, release signing, and hosted deployment remain unvalidated. The generated Android release APK currently uses debug signing. Before adding native integrations, commit finalized platform runners rather than regenerating them.
