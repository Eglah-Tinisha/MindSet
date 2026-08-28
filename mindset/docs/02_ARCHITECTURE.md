# Architecture

## Overall Shape
MindSet uses a straightforward layered Flutter architecture:
- presentation layer in `lib/screens` and `lib/widgets`
- domain/data models in `lib/models`
- service layer in `lib/services`
- theme system in `lib/theme`
- local AI inference via a separate Python FastAPI service

## Flutter Structure
- `main.dart` initializes Firebase and chooses the authenticated or unauthenticated shell.
- `AuthFlow` controls the welcome/login/signup state.
- `MindSetShell` owns authenticated navigation with an `IndexedStack` and a bottom `NavigationBar`.
- Screens are mostly stateful where they manage form input or page-local interaction, but app-wide state is lifted to `MindSetApp` and `MindSetShell`.

## State Management
- No Bloc/Cubit package is present.
- State is managed with `StatefulWidget`, callbacks, and service classes.
- Shared app state includes:
  - dark mode
  - sign-in state
  - loaded journal entries
  - local settings
  - pending entry open/reset requests

## Layering
- UI widgets render and collect user input.
- Services perform persistence, auth, analytics, and API calls.
- Models carry serialized journal and emotion analysis data.
- Firebase is the primary remote persistence and identity layer.
- The Python API is the local AI intelligence layer.

## Design Decisions
- Firestore data is user-scoped under `users/{uid}`.
- Journal entries are stored per user in `users/{uid}/entries`.
- Settings are device-local in SharedPreferences, not Firestore.
- The AI endpoint defaults to a local development address and can be overridden in Settings.
- The app favors a calm, card-based Material 3 interface with semantic color coding for mood states.

## Lifecycle
- `main()` initializes Flutter bindings and Firebase.
- `MindSetApp` checks `FirebaseAuth.instance.currentUser` for immediate shell selection.
- `MindSetShell` ensures the user profile exists, loads settings, loads journal entries, then subscribes to live updates.
- `JournalPage` sends text to the AI API and optionally saves results immediately.

