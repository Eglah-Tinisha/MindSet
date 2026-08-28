# Security

## Authentication
- Email/password sign-in through Firebase Auth.
- Signed-in state is read from `FirebaseAuth.instance.currentUser`.

## Firestore Rules
- Users can only access their own profile and journal documents.

## Local Data
- App settings are stored locally in SharedPreferences.
- No secret management layer is implemented in the Flutter code.

## Network Security
- Android manifest enables cleartext traffic, which is appropriate for local development but should be treated carefully for production.
- The local AI API allows all origins for development convenience.

## Privacy Notes
- The app explicitly separates optional behavioral settings from journal content.
- Journals are stored in the user’s authenticated Firebase account.

