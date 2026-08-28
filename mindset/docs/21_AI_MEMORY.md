# AI Memory

## Permanent Project Facts
- MindSet is a Flutter app for private emotional reflection and journaling.
- Firebase Auth and Firestore are the backend identity and storage layers.
- The app uses a local FastAPI BERT classifier instead of a cloud AI service.
- Settings are intentionally split between device-local preferences and Firebase-backed user data.

## Coding Conventions
- Widgets are small, composable, and mostly named after their visual role.
- Theme tokens live in `MindSetTheme` and `MoodPalette`.
- Data models include `toJson()` and `fromJson()` when they cross service boundaries.
- Service classes are injected optionally for testability.

## Structural Conventions
- Screens live in `lib/screens`.
- Shared widgets live in `lib/widgets`.
- Domain models live in `lib/models`.
- Persistence and integration logic lives in `lib/services`.

## Behavioral Constraints
- Do not silently modify journal content.
- Keep the journal flow centered on analysis first, save second.
- Keep user data scoped to the authenticated account.
- Respect the chosen AI endpoint from settings unless a fallback is needed for connection resilience.

## Inferred Future Direction
- Optional behavioral signal tracking is planned but not yet implemented.
- More analytics and richer reports are likely intended future growth areas.

