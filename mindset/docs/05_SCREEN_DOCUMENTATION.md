# Screen Documentation

## WelcomePage
- Purpose: landing screen for first-time or signed-out users
- Widgets: brand mark, feature grid, CTA buttons, theme toggle
- Navigation: to login or signup
- Dependencies: `common_widgets.dart`

## LoginPage
- Purpose: sign in with email/password
- Widgets: form fields, password reset, login button
- Validation: email format, required password
- Business logic: calls `AuthService.signIn()` and `sendPasswordReset()`

## SignUpPage
- Purpose: create a new Firebase account
- Widgets: full name, email, password, confirm password
- Validation: name length, email format, password length, confirmation match
- Business logic: calls `AuthService.createAccount()`

## MindSetShell
- Purpose: authenticated app container and tab navigation
- Widgets: `IndexedStack`, bottom `NavigationBar`
- Business logic: loads state, syncs entries, manages open-entry and reset requests

## DashboardPage
- Purpose: overview of journal health and recent activity
- Widgets: greeting, stats tiles, recent reflections, next-step card
- Dependencies: `JournalAnalytics`, Firebase user display name/email

## JournalPage
- Purpose: write and analyze reflections
- Widgets: text or voice mode selector, input field, voice transcript card, result card, saved entries list
- Business logic: analyze, save, delete, and open entries

## InsightsPage
- Purpose: emotional trend visualization
- Widgets: valence bars, emotion distribution, pattern cards, prompt card

## ReportsPage
- Purpose: report-like summary with export action
- Widgets: metric rows, report sections, copy-to-clipboard action

## SettingsPage
- Purpose: app settings, profile details, and account actions
- Widgets: theme switch, feature toggles, API endpoint editor, privacy notice, clear/sign-out actions
- Business logic: persists settings locally, clears journals in Firestore, shows profile dialog

