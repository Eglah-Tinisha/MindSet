# Complete Project Summary

MindSet is a Flutter application built around private reflection journaling and AI-assisted emotion analysis. Users authenticate with Firebase, land on a themed dashboard, and can write reflections as typed text or transcript text. The app sends that text to a local FastAPI service backed by a BERT classifier, receives an emotion result with confidence and valence metadata, and saves the analyzed entry to Firestore under the signed-in user.

The app is organized around a small but clear architecture: `main.dart` initializes Firebase and routes to either the auth flow or the main shell. `AuthFlow` handles welcome, login, and sign-up progression. `MindSetShell` is the authenticated container and owns the loaded entry list, settings, and tab navigation. The domain is represented by compact serializable models, while services handle Firebase auth, Firestore journals, local preferences, analytics, and remote AI calls.

The UI emphasizes calm, card-based Material 3 design with sage/green accents in light mode and a muted dark palette in dark mode. The dashboard summarizes journal health, the journal page handles analysis and save actions, the insights page visualizes mood patterns, the reports page turns analytics into exportable text, and the settings page controls theme, AI endpoint, and account actions.

On the AI side, the repository contains a complete training and inference toolchain. The Python code can train a BERT emotion classifier from CSV data, save model artifacts, reload them for inference, and serve predictions over HTTP. The Flutter client is resilient to a few response-shape variations and falls back across several localhost-style endpoints during development.

The project is currently more of a private journaling and emotion-insight platform than a generic productivity app. The data model, analytics, and UI all reinforce a single theme: capture a reflection, analyze the emotional signal, store it safely, and present gentle, actionable patterns back to the user.

