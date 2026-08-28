# Dependencies

## Dart Dependencies
- `flutter`: UI framework
- `cupertino_icons`: iOS-style icon set
- `http`: REST calls from Flutter to the local AI API
- `shared_preferences`: local settings storage
- `firebase_core`: Firebase initialization
- `firebase_auth`: authentication and profile access
- `cloud_firestore`: journal and profile persistence

## Dev Dependencies
- `flutter_test`: widget testing
- `flutter_lints`: lint rules

## Python Dependencies
- `fastapi`: local API server
- `uvicorn`: ASGI server
- `torch`: model runtime
- `transformers`: BERT tokenizer and classifier
- `pydantic`: request/response models
- `scikit-learn`: label encoding and metrics
- `joblib`: artifact compatibility
- `pandas`: dataset loading
- `numpy`: numeric operations

## Where They Are Used
- `firebase_auth` and `firebase_core` are used in `lib/main.dart`, `lib/services/auth_service.dart`, and `lib/screens/settings_page.dart`.
- `cloud_firestore` is used in `lib/services/auth_service.dart` and `lib/services/journal_store.dart`.
- `shared_preferences` is used in `lib/services/local_store.dart`.
- `http` is used in `lib/services/emotion_analyzer.dart`.
- Python ML libraries are used across `understanding_ai/bert_train.py`, `understanding_ai/bert_predict.py`, and `understanding_ai/api.py`.

## Notes
- The Flutter app assumes a local inference service rather than direct on-device ML.
- There is no bloc state-management dependency, no local database package, and no map SDK in the current repository.

