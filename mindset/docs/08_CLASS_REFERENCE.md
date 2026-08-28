# Class Reference

## Data Models
- `EmotionResult`: full prediction result returned from the AI service and stored with journal entries
- `EmotionScore`: one emotion/probability pair
- `ValenceScore`: positive/negative/neutral breakdown
- `JournalEntry`: persisted reflection record
- `AppSettings`: local app preferences
- `MoodOption`, `WeeklyMoodItem`, `FeatureItem`: UI data holders

## Services
- `AuthService`: creates accounts, signs in, signs out, creates user profiles, maps Firebase errors
- `LocalStore`: persists and loads `AppSettings`
- `JournalStore`: saves, loads, watches, deletes, and clears journal entries
- `JournalAnalytics`: computes streaks, top emotions, valence, report notes, and export text
- `EmotionAnalyzer`: HTTP client and parser for the AI API

## Screens
- `MindSetApp`: app root widget
- `AuthFlow`: auth screen router
- `MindSetShell`: authenticated shell
- `DashboardPage`, `JournalPage`, `InsightsPage`, `ReportsPage`, `SettingsPage`
- `WelcomePage`, `LoginPage`, `SignUpPage`

## Widgets
- `AppScaffold`, `WellnessCard`, `IconBox`, `PageTitle`, `SectionHeader`, `AppTextField`, `MoodBadge`, `BrandMark`, `AuthFormShell`, `StatTile`
- `JournalEntryCard`, `MoodSelector`, `VoiceRecorderCard`, `ReflectionResultCard`, `PatternSummaryCard`
- `EmotionProgressRow`, `InsightCard`, `PromptCard`, `ReportMetricRow`, `ReportSectionCard`
- `PrivacyNotice`, `SettingsSwitchTile`, `PrivacySignalTile`, `SettingsActionTile`

