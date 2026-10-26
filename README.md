# Friend Pager

Open-source, best-effort private group paging without exchanging phone numbers.

## Current scope

The app joins one password-protected group, registers this installation with a required non-unique display name and device label, restores its session, saves its receiving preference, and sends/receives live local pages. The backend enforces access rules and supports administrator revocation and password-protected rejoin.

**Local live paging is implemented for running clients.** Send Alert and slide to confirm submit a standard alert with the server-side sender name. Other eligible installations display it and play a bundled sound; the sending installation stays silent. Admin dashboard UI, ongoing heartbeats, OS background notifications, and FCM remain future work. Do not rely on the prototype for urgent or emergency communication.

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

The public local group password is **`local-group-password`**. Local synthetic admin credentials are **`local-admin@example.test` / `local-admin-password`**. These are disposable test fixtures, never production credentials. The admin account can authenticate against local Supabase Auth; the admin screen is not implemented yet. The bootstrap provisions it through the local admin API and a private database allowlist. A database Auth hook blocks public email signup while leaving admin password login enabled. No ordinary user can create an administrator, including through user-editable Auth metadata.

`.local/config.json` contains only the local URL and public API key. The bootstrap obtains the service-role key in memory from the local CLI; it is never placed in app configuration. Group passwords are checked against a private bcrypt hash and never stored by the app. Supabase Flutter persists the installation's Auth session in its platform preferences; clearing app/browser data creates a new installation identity.

For an **Android emulator**, copy `.local/config.json` to `.local/config.android.json` and change the URL host to `10.0.2.2`. For a physical Android device, use `adb reverse tcp:54321 tcp:54321` and the original loopback URL; no LAN port exposure is needed. Run with `--dart-define-from-file=.local/config.android.json`. Generated Android debug runners permit local HTTP; release runners have no cleartext exception and are compilation checks only.

## Local-only operation

App startup rejects hosted URLs and public addresses. The supported dev URLs are HTTP on loopback or private literal IPv4 addresses. There is no hosted fallback, external identity provider, push integration, SMTP provider, or SaaS project link. Keep credentials and local configs out of Git. This branch intentionally does not support connecting the app to production.

The wrapper binds backend ports to loopback using Supabase's supported bridge-network workflow. The app's HTTP transport rejects requests to any origin other than its configured local backend and does not follow redirects. Docker containers are not air-gapped; no external integration or analytics provider is configured. CLI telemetry and the stack's analytics service are disabled. Web builds use local CanvasKit resources and a bundled, licensed Roboto font; fallback fonts are requested only from the app origin. Unsupported glyphs may display as missing characters until more fonts are bundled. Dependency, SDK, CLI, and container-image installation still downloads build artifacts; application/test operations use the local stack. Launch Flutter web with `--no-web-resources-cdn` as shown above.

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

The local HTTP transport also has a unit test proving that public/metadata URLs and changed ports are rejected before any request is sent, and that redirects are disabled. CI asserts all stack ports are published only on loopback.

CI runs formatting, fatal static analysis, VM and Chrome widget tests, the existing 65% line-coverage floor, and Android/Windows/Linux/web release builds. Its additional **Local Supabase integration** job starts a disposable stack, resets migrations, provisions only synthetic fixtures, and runs the actual Dart client against Auth and PostgREST. It checks duplicate names, metadata validation, session restoration, receiving persistence, cross-device RLS, unauthorized writes, wrong-password throttling, admin role isolation, revocation with an existing token, and password-protected rejoin. No hosted Supabase/Firebase credentials are needed.

The join endpoint limits each Auth identity to five attempts per 15 minutes. Supabase Auth also limits anonymous signups per IP. This is a local foundation; production will need a reviewed IP-level abuse policy and anonymous-user retention strategy, not just per-identity throttling. Device metadata is supplied by the client and is informational, not trusted for authorization.

## Engineering and release limits

Never commit directly to main. Every change goes through a PR; never merge without explicit approval. All existing checks and `Local Supabase integration` should be required on main. Do not weaken tests or quality gates to make CI green.

Green CI verifies the tested behavior and compilation. Native installation/device interaction, physical audio output, OS background delivery, accessibility, platform-secure session storage, release signing, and hosted deployment remain unvalidated. The generated Android release APK currently uses debug signing. Runners remain generated for this local milestone; commit finalized platform projects before adding platform-specific notification/background configuration.

If you previously created the experimental internal network from an earlier PR revision, stop the stack, then remove that empty network with `docker network rm friend-pager-local` before starting this revision.

## Try the local paging loop

Start the stack and prepare fixtures using the setup above. To serve one build to two independent browser installations:

```sh
flutter build web --release --no-web-resources-cdn --dart-define-from-file=.local/config.json
python3 -m http.server 7357 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:7357` in a normal browser profile and in a private/incognito window or a different browser. Two tabs in the same profile share an installation session, so use independent profiles to simulate two devices. Join both, using the public local group password and any display names. On each receiver, select **Enable/test sound** once to check playback and satisfy browser autoplay requirements. Keep both apps open, then send and slide to confirm from one. The other receives a visual alert and sound; the sender receives only submission status. Turn receiving off on one installation to verify it stays silent while still being able to send.

On Linux, install GStreamer runtime/base plugins for audio; building also needs `libgstreamer1.0-dev` and `libgstreamer-plugins-base1.0-dev` alongside the existing Flutter Linux prerequisites. Check actual audio output and volume on each native platform. Browsers can still block audio, throttle background tabs, or suspend them; this local milestone is for running clients, not guaranteed background delivery. A playback failure is shown in the UI. Dismiss only clears the local presentation; it sends no acknowledgment.

Alerts expire **20 seconds after server submission**. Dispatch selects active, receiving-enabled installations and excludes the sender by installation identity (not display name). Postgres RLS and a final server-side validation enforce current recipient access and expiry before presentation. The client uses the server's remaining lifetime, subtracting request time, rather than trusting its wall clock. A short-lived delivery table supports Realtime; expired rows are hidden immediately and purged every minute by pg_cron. No alert history UI or receipt/acknowledgment tracking exists.

Subscriptions listen for INSERTs and establish a fresh server-clock boundary after each subscription. Deliveries created before that boundary are rejected, including delayed replication events. Startup/reconnect never fetches existing rows for replay; unavailable deliveries are dropped with no application-level retries. A failed or timed-out send can have an unknown outcome and is never retried automatically. Submitted means accepted by the backend, not delivered to another device. Duplicate received event IDs are suppressed in memory until expiry. These tests exercise both real Realtime transport and the same presentation controller used in the app, with a fake audio output to verify sound decisions. Hardware audio and browser autoplay still require manual validation.
