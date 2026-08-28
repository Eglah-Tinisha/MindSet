# Database and Firebase

## Firebase Products Used
- Firebase Authentication
- Cloud Firestore

## Auth Model
- Email/password authentication.
- User profile document is created or updated after sign-up and sign-in.

## Firestore Schema
- `users/{uid}`
  - `uid`
  - `fullName`
  - `email`
  - `createdAt`
  - `lastSignedInAt`
  - `updatedAt`
- `users/{uid}/entries/{entryId}`
  - `id`
  - `ownerId`
  - `createdAt`
  - `text`
  - `result`
  - `updatedAt`

## Security Rules
- A user can only read/write their own `users/{uid}` document.
- A user can only read/write their own nested `entries`.

## Storage and Sync
- Settings are local, not in Firestore.
- Journal entries are sorted by `createdAt` descending.
- Live updates use snapshots.

## Notes
- No explicit Firestore indexes are declared in the repo.
- No offline cache configuration is customized in code.

