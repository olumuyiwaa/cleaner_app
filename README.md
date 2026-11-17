# Tod Cleaning – Cleaner app

Flutter app for cleaners of Tod Cleaning Services. It talks to the same backend
as the web cleaner portal (`olumuyiwaa/lady`).

**Features:** sign-in (with 2FA and workplace choice), today / upcoming / past jobs,
job detail (access notes, navigate, call), "on my way", GPS check-in and complete,
checklist, before/after photos (with thumbnails), customer chat, earnings,
availability, time off, documents, Stripe payout setup, password reset, change
password, two-factor setup, push notifications, English and Dutch.

**Works offline:** "on my way", check-in, checklist ticks, photos and "complete" are
saved on the phone when there is no signal and sent in order once it returns
(a banner shows what is waiting). If the server refuses a saved change, the
cleaner is told.

## First-time setup

This repo contains the Dart code only, so generate the native projects first:

```bash
flutter create --org nl.todcleaning --project-name cleaner_app --platforms android,ios .
python3 tool/apply_platform_config.py   # permissions for location, camera, links
flutter pub get
flutter analyze
flutter test
```

Needs Flutter 3.27 or newer. Then, once, for the icon and launch screen
(the source image is `assets/images/logo_mark.png`; swap in a 1024x1024 version for sharper icons):

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

CI (`.github/workflows/ci.yml`) generates the platform folders, then runs
`flutter analyze` and `flutter test` on every push.

## Run

```bash
flutter run --dart-define=API_BASE_URL=https://YOUR-API.onrender.com/api/v1
```

| Define | Default | Purpose |
| --- | --- | --- |
| `API_BASE_URL` | `http://10.0.2.2:8000/api/v1` | Backend URL including `/api/v1` (Android emulator → host). On the iOS simulator use `http://localhost:8000/api/v1`. |
| `STRIPE_RETURN_URL` | web portal profile page | https page Stripe returns to after payout onboarding. |

## Push notifications (optional)

Add `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
from your Firebase project (and the Google Services Gradle plugin on Android).
Without them the app still works; it just does not register for push.

## Notes and limits

- This code was written without access to a Flutter toolchain, so it has **not been
  compiled or run yet**. Expect to fix a few small analyzer errors on first build.
- Job photo thumbnails need the backend change that returns `viewUrl` for each photo
  (already in `olumuyiwaa/lady` main).
- Location is best effort: if GPS is off or denied, check-in still goes to the
  server, which decides whether that is acceptable.
- While a job is in progress the phone sends its position about once a minute, also
  with the app in the background (Android shows a notification while it does;
  iOS shows the blue location indicator). It stops when the job is completed.
- An action whose reply was lost in transit may be sent twice when the queue
  replays; the server rejects the duplicate and the cleaner sees that message.
- Password reset uses the emailed link, which opens the web reset page.

## Structure

```
lib/core        config, API client (token refresh), router, theme, l10n, push
lib/features    auth, jobs, earnings, profile
test            strings, models and offline queue tests
tool            platform permission script
```
