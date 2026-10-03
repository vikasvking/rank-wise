# Lakshyank mobile app (Flutter)

One app for students and teachers. After sign-in it opens the student screens
(Home, Tests, Practice, Ranks, Me) or the teacher screens (Tests, Questions, Me).
It talks to the Lakshyank website's JSON API at `/api/v1` (apply the Rails API patch first).

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

## Look and theme

- Colours come from the website (`lib/core/palette.dart`, `lib/core/theme.dart`): students and visitors burgundy (rose),
  teachers indigo, admins emerald, on slate greys; test cards use the same Strict (red) / PIN (sky) / Open (emerald)
  badges and exam colours as the site.
- Light / Dark / System: the sun / moon button in each tab's top bar, or Me → Appearance. Saved on the phone;
  System (the default) follows the phone.

## Retaking tests

A submitted test can be retaken as often as the student likes (needs the Rails side from `rankwise-retakes.patch`).
Tests with a closing time can be retaken only after they close. Retakes are practice: only the first attempt is ranked.

## Push notifications (Firebase)

Students get: new tests from their teachers / for their exams, "Results are out" when a strict test closes,
and an evening reminder if today's 25 questions are not done. Each can be switched off under Me → Notifications.
The server side is `PushNotifier` in the Rails app. Without Firebase set up, the app runs normally with notifications off.

One-time setup:
1. Create a project at https://console.firebase.google.com
2. `flutter pub add firebase_core firebase_messaging`
3. `dart pub global activate flutterfire_cli`, then `flutterfire configure` in this folder (pick the project,
   Android and iOS). It adds `google-services.json` and the Gradle plugin.
4. On the server (Render): Firebase → Project settings → Service accounts → Generate new private key,
   and paste the whole JSON file into the `FIREBASE_CREDENTIALS` environment variable.

**App ID `com.lakshyank.app`** (Android and iOS). Firebase ties each app to its ID, so after the ID changed:
run `flutterfire configure` again, pick the same project (rankwise-9e100), tick Android and iOS. It registers
`com.lakshyank.app`, then rewrites `google-services.json`, `GoogleService-Info.plist` and `lib/firebase_options.dart`.
Until then the Android build stops with "No matching client found for package name 'com.lakshyank.app'".

Test it: sign in as a student on a real phone (or an emulator with Google Play), allow notifications,
then have a teacher create an open test for that student's exam; it arrives about a minute later.
