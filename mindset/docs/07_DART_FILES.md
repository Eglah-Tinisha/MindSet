# Dart Files

## `lib/main.dart`
- Initializes Firebase and launches the app.
- Hosts `MindSetApp`, which owns theme and sign-in state.

## `lib/firebase_options.dart`
- FlutterFire-generated platform configuration.

## `lib/models/models.dart`
- Core domain objects:
  - `EmotionResult`
  - `EmotionScore`
  - `ValenceScore`
  - `MoodOption`
  - `WeeklyMoodItem`
  - `JournalEntry`
  - `FeatureItem`
  - `AppSettings`

## `lib/services/auth_service.dart`
- Firebase auth + user profile management.

## `lib/services/local_store.dart`
- SharedPreferences-backed settings storage.

## `lib/services/journal_store.dart`
- Firestore journal CRUD and stream subscription.

## `lib/services/journal_analytics.dart`
- Aggregated metrics and report text generation.

## `lib/services/emotion_analyzer.dart`
- HTTP client for the local FastAPI emotion API.

## `lib/theme/mindset_theme.dart`
- Light/dark theme definitions and mood palette.

## `lib/screens/*`
- `auth_flow.dart`: auth page router
- `welcome_page.dart`: landing screen
- `login_page.dart`: sign-in screen
- `signup_page.dart`: sign-up screen
- `mindset_shell.dart`: authenticated shell
- `dashboard_page.dart`: home screen
- `journal_page.dart`: journaling and analysis screen
- `insights_page.dart`: pattern insights screen
- `reports_page.dart`: report screen
- `settings_page.dart`: settings screen

## `lib/widgets/*`
- Shared UI primitives and page-specific widgets.

