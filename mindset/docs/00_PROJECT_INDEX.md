# Project Index

## What this project is
MindSet is a Flutter mental wellness and journal reflection app backed by Firebase Authentication and Cloud Firestore, with a local FastAPI service that runs a BERT-based emotion classifier.

## Purpose
The app lets a signed-in user:
- create an account and log in with Firebase Auth
- write text or transcript-based reflections
- send reflection text to a local AI endpoint for emotion analysis
- save analyzed entries to Firestore
- inspect dashboard summaries, insights, and reports
- manage local settings such as dark mode and the AI endpoint URL

## Core Technologies
- Flutter / Dart
- Firebase Auth
- Cloud Firestore
- shared_preferences
- HTTP
- FastAPI
- PyTorch / Transformers / scikit-learn

## Folder Map
- `lib/`: Flutter app source
- `understanding_ai/`: local BERT training, prediction, and API server
- `android/`, `ios/`, `macos/`, `linux/`: platform shells
- `firestore.rules`, `firebase.json`: Firebase config
- `pubspec.yaml`: Dart package configuration

## Documentation Map
- [01_COMPLETE_DIRECTORY_STRUCTURE.md](./01_COMPLETE_DIRECTORY_STRUCTURE.md)
- [02_ARCHITECTURE.md](./02_ARCHITECTURE.md)
- [03_DEPENDENCIES.md](./03_DEPENDENCIES.md)
- [04_APPLICATION_FLOW.md](./04_APPLICATION_FLOW.md)
- [05_SCREEN_DOCUMENTATION.md](./05_SCREEN_DOCUMENTATION.md)
- [06_WIDGET_DOCUMENTATION.md](./06_WIDGET_DOCUMENTATION.md)
- [07_DART_FILES.md](./07_DART_FILES.md)
- [08_CLASS_REFERENCE.md](./08_CLASS_REFERENCE.md)
- [09_DATA_FLOW.md](./09_DATA_FLOW.md)
- [10_DATABASE_AND_FIREBASE.md](./10_DATABASE_AND_FIREBASE.md)
- [11_MAP_SYSTEM.md](./11_MAP_SYSTEM.md)
- [12_AI_SYSTEM.md](./12_AI_SYSTEM.md)
- [13_NETWORKING.md](./13_NETWORKING.md)
- [14_ANDROID_NATIVE.md](./14_ANDROID_NATIVE.md)
- [15_CONFIGURATION.md](./15_CONFIGURATION.md)
- [16_ASSETS.md](./16_ASSETS.md)
- [17_SECURITY.md](./17_SECURITY.md)
- [18_KNOWN_ISSUES.md](./18_KNOWN_ISSUES.md)
- [19_SOURCE_CODE_INDEX.md](./19_SOURCE_CODE_INDEX.md)
- [20_SOURCE_CODE_EXPORT.md](./20_SOURCE_CODE_EXPORT.md)
- [21_AI_MEMORY.md](./21_AI_MEMORY.md)
- [22_AI_PROMPTS.md](./22_AI_PROMPTS.md)
- [23_COMPLETE_PROJECT_SUMMARY.md](./23_COMPLETE_PROJECT_SUMMARY.md)

## Reading Order
1. [00_PROJECT_INDEX.md](./00_PROJECT_INDEX.md)
2. [01_COMPLETE_DIRECTORY_STRUCTURE.md](./01_COMPLETE_DIRECTORY_STRUCTURE.md)
3. [02_ARCHITECTURE.md](./02_ARCHITECTURE.md)
4. [04_APPLICATION_FLOW.md](./04_APPLICATION_FLOW.md)
5. [09_DATA_FLOW.md](./09_DATA_FLOW.md)
6. [10_DATABASE_AND_FIREBASE.md](./10_DATABASE_AND_FIREBASE.md)
7. [12_AI_SYSTEM.md](./12_AI_SYSTEM.md)
8. [19_SOURCE_CODE_INDEX.md](./19_SOURCE_CODE_INDEX.md)
9. [21_AI_MEMORY.md](./21_AI_MEMORY.md)
10. [23_COMPLETE_PROJECT_SUMMARY.md](./23_COMPLETE_PROJECT_SUMMARY.md)

## Cross References
- App entry point: `lib/main.dart`
- Firebase setup: `lib/firebase_options.dart`
- Journal persistence: `lib/services/journal_store.dart`
- Local AI client: `lib/services/emotion_analyzer.dart`
- Local AI server: `understanding_ai/api.py`
