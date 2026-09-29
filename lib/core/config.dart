/// Where the Rankwise website runs. The app talks to its API at `<kSiteUrl>/api/v1`.
///
/// Change the default below, or pass it when building:
///   flutter run --dart-define=RANKWISE_URL=https://your-site.onrender.com
const String kSiteUrl = String.fromEnvironment(
  'RANKWISE_URL',
  defaultValue: 'https://upsc-questions.onrender.com',
);

/// Free Render servers sleep after 15 idle minutes and take up to about a minute to wake up.
const Duration kRequestTimeout = Duration(seconds: 75);
