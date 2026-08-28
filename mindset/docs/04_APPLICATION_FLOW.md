# Application Flow

## Entry Sequence
1. `main()` in `lib/main.dart`
2. `WidgetsFlutterBinding.ensureInitialized()`
3. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
4. `runApp(const MindSetApp())`

## Unauthenticated Flow
- `MindSetApp` chooses `AuthFlow` when no current Firebase user exists.
- `AuthFlow` starts on `WelcomePage`.
- From welcome:
  - user can toggle theme
  - user can move to login
  - user can move to signup
- `LoginPage` handles sign-in and password reset.
- `SignUpPage` handles account creation.
- Successful auth calls `onAuthenticated`, which flips the root state to the authenticated shell.

## Authenticated Flow
- `MindSetApp` switches to `MindSetShell`.
- `MindSetShell`:
  - ensures the profile document exists
  - clears legacy local entries
  - loads settings
  - loads journal entries
  - subscribes to Firestore updates

## Main Navigation
- Home: `DashboardPage`
- Journal: `JournalPage`
- Insights: `InsightsPage`
- Reports: `ReportsPage`
- Settings: `SettingsPage`

## Journal Flow
1. User writes a reflection or transcript.
2. `EmotionAnalyzer` posts text to the local API.
3. The API returns emotion, confidence, top emotions, valence, and summary.
4. `JournalPage` shows results.
5. If auto-save is enabled, the entry is persisted immediately.
6. Entries stream back into the shell and update all pages.

## Shutdown / Sign Out
- Settings calls `AuthService.signOut()`.
- Root state flips back to the auth flow.

