# Data Flow

## Primary Path
UI input -> `EmotionAnalyzer` -> local FastAPI API -> prediction JSON -> `EmotionResult` -> `JournalEntry` -> Firestore -> live stream back to UI

## Auth Flow
- User credentials are handled by Firebase Auth.
- `AuthService.ensureUserProfile()` writes a mirrored profile document under `users/{uid}`.
- Firestore security rules restrict access to the authenticated owner.

## Journal Flow
- `JournalPage` collects text.
- `EmotionAnalyzer` posts JSON to `/predict`.
- The result is attached to a `JournalEntry`.
- `JournalStore.saveEntry()` persists the journal to `users/{uid}/entries/{entryId}`.
- `JournalStore.watchEntries()` keeps the app synchronized.

## Settings Flow
- `SettingsPage` writes `AppSettings` to SharedPreferences.
- The AI endpoint URL is used by `EmotionAnalyzer`.

## Analytics Flow
- `JournalAnalytics` derives streaks, average valence, dominant emotion, report notes, and export text entirely from loaded entries.

