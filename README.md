# Tod Cleaning – Cleaner app

Flutter app for cleaners of Tod Cleaning Services. It talks to the same backend
as the web cleaner portal (`olumuyiwaa/lady`).

**Features:** sign-in (with 2FA and workplace choice), today / upcoming / past jobs,
job detail (access notes, navigate, call), "on my way", GPS check-in and complete,
checklist, before/after photos, customer chat, earnings, availability, time off,
documents, Stripe payout setup, push notifications, English and Dutch.

## First-time setup

This repo contains the Dart code only, so generate the native projects first:

```bash
flutter create --org nl.todcleaning --project-name cleaner_app --platforms android,ios .
python3 tool/apply_platform_config.py   # permissions for location, camera, links
flutter pub get
flutter analyze
flutter test
```

Needs Flutter 3.27 or newer.

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
- The API does not give cleaners image URLs for job photos, so only photos added
  in the current visit show as thumbnails; the count is always accurate.
- Location is best effort: if GPS is off or denied, check-in still goes to the
  server, which decides whether that is acceptable.
- Live location pings (every 60 s) only run while the job screen is open and the
  job is in progress.

## Structure

```
lib/core        config, API client (token refresh), router, theme, l10n, push
lib/features    auth, jobs, earnings, profile
test            strings and model tests
tool            platform permission script
```
