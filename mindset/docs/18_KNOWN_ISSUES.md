# Known Issues and Risks

## Observations
- No map system is currently present, despite the requested documentation template mentioning maps.
- No Bloc/Cubit state-management framework is used.
- No dedicated offline sync policy or retry queue is implemented.
- The local AI client and API do not share one exact JSON contract name set; the Flutter client is defensive, but the schema should be kept in sync.
- `understanding_ai/` contains large binary artifacts that were not inspected structurally here.

## Possible Bug Surfaces
- `JournalPage` saves entries with generated IDs and timestamps in the client; duplicate rapid saves should be checked carefully.
- `ReportSectionCard` and other UI widgets rely on analytics computed from the in-memory entry list; if entries are stale, the summaries can lag until Firestore updates arrive.
- `SettingsPage` stores only the endpoint URL locally, so device-specific configuration must be repeated per install.

