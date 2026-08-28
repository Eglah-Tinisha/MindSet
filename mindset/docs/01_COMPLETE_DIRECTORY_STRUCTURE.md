# Complete Directory Structure

## Top Level
- `lib/` Flutter application code
- `understanding_ai/` local BERT pipeline and API server
- `android/` Android native shell
- `ios/` iOS native shell
- `macos/` macOS native shell
- `linux/` Linux native shell
- `test/` Flutter tests
- `firestore.rules` Firestore security rules
- `firebase.json` Firebase project configuration
- `pubspec.yaml` Dart package manifest
- `analysis_options.yaml` Dart lints

## `lib/`
- `main.dart` app bootstrap, Firebase init, auth gate
- `firebase_options.dart` FlutterFire config
- `models/models.dart` app data models
- `services/`
  - `auth_service.dart` Firebase Auth and profile sync
  - `journal_store.dart` Firestore journal persistence
  - `local_store.dart` SharedPreferences settings storage
  - `journal_analytics.dart` derived stats and reports
  - `emotion_analyzer.dart` HTTP client to local AI API
  - `emotion_analyzer.dart` is the boundary between Flutter and the Python server
- `screens/`
  - `auth_flow.dart` welcome/login/signup state machine
  - `welcome_page.dart`
  - `login_page.dart`
  - `signup_page.dart`
  - `mindset_shell.dart` authenticated shell and navigation
  - `dashboard_page.dart`
  - `journal_page.dart`
  - `insights_page.dart`
  - `reports_page.dart`
  - `settings_page.dart`
- `widgets/`
  - `common_widgets.dart`
  - `journal_widgets.dart`
  - `insight_widgets.dart`
  - `settings_widgets.dart`
- `theme/`
  - `mindset_theme.dart`

## `understanding_ai/`
- `api.py` FastAPI app
- `bert_predict.py` inference and CLI helper
- `bert_train.py` training pipeline
- `compress.py` model size reduction helper
- `fix_label_encoder.py` label encoder regeneration
- `test_api.py` local API smoke test
- `requirements_api.txt` Python dependencies
- `model.pkl`, `label_encoder.pkl`, `vectorizer.pkl` serialized artifacts

## Platform Files
- Android manifests, Gradle files, Kotlin entrypoint
- iOS and macOS Xcode project files, Info.plist, AppDelegate, launch storyboards
- Linux CMake and runner files

## Importance Notes
- Highest importance: `lib/main.dart`, `lib/screens/mindset_shell.dart`, `lib/services/journal_store.dart`, `lib/services/emotion_analyzer.dart`, `understanding_ai/api.py`, `understanding_ai/bert_predict.py`
- Medium importance: screens, widgets, theme, analytics
- Support files: platform build files, test, config, assets

