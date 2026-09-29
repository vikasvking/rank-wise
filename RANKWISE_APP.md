# Rankwise mobile app (Flutter)

One app for students and teachers. After sign-in it opens the student screens
(Home, Tests, Practice, Ranks, Me) or the teacher screens (Tests, Questions, Me).
It talks to the Rankwise website's JSON API at `/api/v1` (apply the Rails API patch first).

Needs Flutter 3.29 or newer (Dart 3.7+).

## Set up

```bash
flutter create rankwise_app --org com.rankwise --platforms android,ios
cd rankwise_app
rm lib/main.dart test/widget_test.dart          # replaced by the patch
git apply ~/Downloads/rankwise-flutter-app.patch
flutter pub add http shared_preferences url_launcher
dart format lib test
```

Allow internet access in Android release builds (debug builds already have it):

```bash
perl -0pi -e 's|(<manifest[^>]*>)|$1\n    <uses-permission android:name="android.permission.INTERNET"/>|' android/app/src/main/AndroidManifest.xml
```

Point the app at your site: change `defaultValue` in `lib/core/config.dart`, or pass it when running:

```bash
flutter run --dart-define=RANKWISE_URL=https://your-site.onrender.com
```

Check it:

```bash
flutter analyze
flutter test
```

## What is where

| Folder | What |
|---|---|
| `lib/core` | API client (`api.dart`), sign-in state (`session.dart`), JSON readers, formatting, site URL |
| `lib/widgets` | Shared pieces: loaders, errors, cards, pills |
| `lib/screens` | Sign-in, "finish your account on the website", Me tab, edit profile |
| `lib/student` | Dashboard, tests, test details, taking a test (strict mode), results, question bank, ranks, membership |
| `lib/teacher` | My tests, create/edit test, results, live view and reinstate, question bank, add/edit questions |

## Still on the website

Sign-up and parent consent, password reset, changing email or password, Excel uploads, batches,
joining schools, and all admin pages. The app opens the right website page for these.

## Strict tests in the app

While a strict test is open the app pings the server every 15 seconds. When the app goes to the
background (another app, home button, screen lock) and comes back, it reports how long it was away.
The server applies the same rules as the website: under 5 seconds is ignored, the first leave warns,
the second blocks. If the app is closed, the pings stop and the student is blocked after about 90 seconds.
