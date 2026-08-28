param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$package = Join-Path $Root 'AI_KNOWLEDGE_PACKAGE'
$sourceExport = Join-Path $package 'SOURCE_EXPORT_REGENERATED.md'
$inventory = Join-Path $package 'ALL_FILES.tsv'
$sourceIndex = Join-Path $package 'SOURCE_INDEX.tsv'
New-Item -ItemType Directory -Force -Path $package | Out-Null

$excludedDirParts = @('\.git\','\.dart_tool\','\.dart-localappdata\','\.pub-cache\','\build\','\.venv\','\__pycache__\')
$allFiles = Get-ChildItem -LiteralPath $Root -Force -Recurse -File | Where-Object {
  $full = $_.FullName
  $full -notlike "$package*"
}

function Is-Excluded([string]$path) {
  foreach ($part in $excludedDirParts) { if ($path.Contains($part)) { return $true } }
  return $false
}

function Rel([string]$path) { return $path.Substring($Root.Length).TrimStart([char[]]"/\\") -replace '\\','/' }

# Complete physical-file inventory. It intentionally includes generated files, caches,
# model checkpoints, and the bundled executable; the reason/category is recorded below.
$inventoryRows = foreach ($file in ($allFiles | Sort-Object FullName)) {
  $rel = Rel $file.FullName
  $excluded = Is-Excluded $file.FullName
  $category = if ($excluded) { 'generated-or-cache' }
    elseif ($file.Extension -in @('.pkl','.pt','.pth','.bin','.safetensors','.jar','.png','.jpg','.jpeg','.gif','.ico','.webp','.wav','.mp3','.mp4','.exe')) { 'binary-or-model' }
    else { 'authored-or-config' }
  [PSCustomObject]@{ Path=$rel; Bytes=$file.Length; Extension=$file.Extension.ToLower(); Category=$category; LastWriteTime=$file.LastWriteTime.ToString('o') }
}
$inventoryRows | ConvertTo-Csv -Delimiter "`t" -NoTypeInformation | Set-Content -Encoding UTF8 $inventory

$sourceExtensions = @('.dart','.py','.ps1','.sh','.kt','.java','.swift','.m','.mm','.h','.cc','.cpp','.c','.html','.css','.js','.ts','.json','.yaml','.yml','.xml','.plist','.gradle','.kts','.properties','.rules','.md','.txt','.toml','.ini','.cfg','.cmake','.xcscheme','.xcconfig','.pbxproj','.storyboard','.xib')
$sourceFiles = $allFiles | Where-Object {
  -not (Is-Excluded $_.FullName) -and $_.Extension.ToLower() -in $sourceExtensions
} | Sort-Object FullName

$sourceRows = foreach ($file in $sourceFiles) {
  $rel = Rel $file.FullName
  $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
  if ($null -eq $text) { $text = '' }
  $lines = if ($null -eq $text -or $text.Length -eq 0) { 0 } else { ($text -split "`r?`n").Count }
  [PSCustomObject]@{ Path=$rel; Bytes=$file.Length; Lines=$lines; Extension=$file.Extension.ToLower() }
}
$sourceRows | ConvertTo-Csv -Delimiter "`t" -NoTypeInformation | Set-Content -Encoding UTF8 $sourceIndex

$fileReference = Join-Path $package '02_FILE_REFERENCE.md'
Set-Content -Encoding UTF8 $fileReference "# Every Authored Source And Configuration File`n"
Add-Content -Encoding UTF8 $fileReference "This file references every text source/configuration file exported verbatim in SOURCE_EXPORT_REGENERATED.md. Binary files, generated build outputs, dependency caches, local virtual environments, and model checkpoints remain listed in ALL_FILES.tsv and ARTIFACTS.md.`n"
foreach ($file in $sourceFiles) {
  $rel = Rel $file.FullName
  $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
  if ($null -eq $text) { $text = '' }
  $imports = @()
  if ($file.Extension.ToLower() -eq '.dart') {
    $imports = [regex]::Matches($text, '(?m)^\s*import\s+([^;]+);') | ForEach-Object { $_.Groups[1].Value.Trim() }
  } elseif ($file.Extension.ToLower() -eq '.py') {
    $imports = [regex]::Matches($text, '(?m)^\s*(?:import|from)\s+(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() }
  }
  $classes = [regex]::Matches($text, '(?m)^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)') | ForEach-Object { $_.Groups[1].Value }
  $functions = if ($file.Extension.ToLower() -eq '.py') {
    [regex]::Matches($text, '(?m)^\s*def\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(') | ForEach-Object { $_.Groups[1].Value }
  } else {
    [regex]::Matches($text, '(?m)^\s*(?:Future<[^>]+>|Future<void>|void|Widget|String|int|double|bool|Map<[^>]+>|List<[^>]+>|[A-Z][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(') | ForEach-Object { $_.Groups[1].Value }
  }
  $purpose = if ($rel -like 'mindset/lib/screens/*') { 'Flutter screen/page UI and page-level interaction logic.' }
    elseif ($rel -like 'mindset/lib/widgets/*') { 'Reusable Flutter widget/component source.' }
    elseif ($rel -like 'mindset/lib/services/*') { 'Flutter service layer for auth, persistence, analytics, AI, local storage, or voice.' }
    elseif ($rel -like 'mindset/lib/models/*') { 'Domain model and serialization source.' }
    elseif ($rel -like 'mindset/lib/theme/*') { 'Flutter theme source.' }
    elseif ($rel -eq 'mindset/lib/main.dart') { 'Flutter entry point, Firebase bootstrap, root auth/theme state.' }
    elseif ($rel -like 'understanding_ai/*') { 'Python AI/backend, training, inference, audio, STT, or multimodal source/config.' }
    elseif ($rel -like 'mindset/android/*') { 'Android platform/build/configuration source.' }
    elseif ($rel -like 'mindset/ios/*') { 'iOS platform/build/configuration source.' }
    elseif ($rel -like 'mindset/macos/*') { 'macOS platform/build/configuration source.' }
    elseif ($rel -like 'mindset/linux/*') { 'Linux platform/build/configuration source.' }
    elseif ($rel -like 'mindset/docs/*') { 'Existing repository documentation included in the export.' }
    else { 'Project source or configuration file.' }

  Add-Content -Encoding UTF8 $fileReference "## $rel"
  Add-Content -Encoding UTF8 $fileReference "- Purpose: $purpose"
  Add-Content -Encoding UTF8 $fileReference "- Bytes: $($file.Length)"
  if ($imports.Count -gt 0) { Add-Content -Encoding UTF8 $fileReference "- Dependencies/imports: $($imports -join ', ')" }
  if ($classes.Count -gt 0) { Add-Content -Encoding UTF8 $fileReference "- Classes: $($classes -join ', ')" }
  if ($functions.Count -gt 0) { Add-Content -Encoding UTF8 $fileReference "- Functions/method-like declarations: $($functions -join ', ')" }
  Add-Content -Encoding UTF8 $fileReference "- Full source: exported exactly once in SOURCE_EXPORT_REGENERATED.md.`n"
}

$header = @'
# MindSet AI Knowledge Base — Exact Source Export

This file is generated from the authored source/configuration set at the time of export. Every entry includes the exact bytes interpreted as UTF-8 text, without summarization. Generated SDK files are included when they are authored project files; dependency caches and compiled/binary artifacts are represented in `ALL_FILES.tsv` and `ARTIFACTS.md` instead of being pasted as source.

'@
Set-Content -Encoding UTF8 $sourceExport $header
foreach ($file in $sourceFiles) {
  $rel = Rel $file.FullName
  $language = switch ($file.Extension.ToLower()) {
    '.dart' {'Dart'} '.py' {'Python'} '.ps1' {'PowerShell'} '.sh' {'Shell'} '.kt' {'Kotlin'} '.java' {'Java'} '.swift' {'Swift'} '.m' {'Objective-C'} '.mm' {'Objective-C++'} '.h' {'C/C++ header'} '.cc' {'C++'} '.cpp' {'C++'} '.c' {'C'} '.json' {'JSON'} '.yaml' {'YAML'} '.yml' {'YAML'} '.xml' {'XML'} '.plist' {'XML property list'} '.gradle' {'Gradle'} '.kts' {'Kotlin DSL'} '.properties' {'Properties'} '.md' {'Markdown'} '.txt' {'Text'} '.html' {'HTML'} '.css' {'CSS'} '.js' {'JavaScript'} '.ts' {'TypeScript'} '.rules' {'Firestore rules'} default {$file.Extension.TrimStart('.')}
  }
  Add-Content -Encoding UTF8 $sourceExport ("`n==================================`n`nFILE START`n`nPath: $rel`n`nLanguage: $language`n`nFULL SOURCE CODE`n`n````$language")
  Get-Content -LiteralPath $file.FullName | Add-Content -Encoding UTF8 $sourceExport
  Add-Content -Encoding UTF8 $sourceExport "````
FILE END

==================================`n"
}

$authored = $inventoryRows | Where-Object Category -eq 'authored-or-config'
$binary = $inventoryRows | Where-Object Category -eq 'binary-or-model'
$generated = $inventoryRows | Where-Object Category -eq 'generated-or-cache'
$dirSummary = $inventoryRows | ForEach-Object { ($_.Path -split '/')[0] } | Group-Object | Sort-Object Name

$overview = @"
# MindSet AI Continuation Package

Generated: $(Get-Date -Format o)
Repository root: `$Root`

## Executive description

MindSet is a Flutter Material 3 mental-wellness journaling application. Firebase Authentication establishes the user session, Cloud Firestore stores each user's analyzed journal entries, SharedPreferences stores device-local preferences, and a separate local FastAPI service performs emotion inference. The AI side now includes text BERT inference/training, optional Faster-Whisper speech-to-text, audio speech-emotion recognition, and a transparent provisional multimodal fusion layer.

## Current implementation stage

The repository is a working development prototype rather than a production release. The Flutter shell, auth flow, journal CRUD, analytics, settings, and local AI integration are implemented. Voice capture and multimodal backend code are present, but their end-to-end Flutter/API integration and production hardening need verification. There is no Bloc/Cubit, map, routing SDK, Firebase Storage, push notification, or custom Flutter asset bundle in the authored app.

## Startup and primary data flow

`main()` initializes Flutter bindings and Firebase, then `MindSetApp` selects the signed-in shell from `FirebaseAuth.instance.currentUser`. The unauthenticated state is `AuthFlow` (welcome → login/signup). The authenticated state is `MindSetShell`, which loads local settings and Firestore entries. Journal text is posted by `EmotionAnalyzer` to the local `/predict` endpoint, converted to an `EmotionResult`, wrapped in a `JournalEntry`, and written below `users/{uid}/entries/{entryId}`. `JournalAnalytics` derives dashboard, insight, and report values from the loaded list.

## Architecture map

```text
Flutter UI (screens/widgets)
        ↓ callbacks + models
Services (AuthService, JournalStore, LocalStore, EmotionAnalyzer, Analytics)
        ├── Firebase Auth / Firestore
        ├── SharedPreferences
        └── HTTP → understanding_ai/api.py
                         ├── BERT text classifier
                         ├── Faster-Whisper STT
                         ├── Wav2Vec2 audio SER
                         └── provisional_fusion.py
```

## Authenticated Firestore schema

* `users/{uid}`: `uid`, `fullName`, `email`, `createdAt`, `lastSignedInAt`, `updatedAt`.
* `users/{uid}/entries/{entryId}`: `id`, `ownerId`, `createdAt`, `text`, `result`, `updatedAt`.
* Rules require a non-null authenticated user whose UID equals `{uid}`. Profile creation additionally requires `request.resource.data.uid == userId`.

## Inventory totals

* Physical files inventoried: $($inventoryRows.Count)
* Authored/configuration candidates exported verbatim: $($sourceRows.Count)
* Binary/model artifacts: $($binary.Count)
* Generated/cache files: $($generated.Count)

See `ALL_FILES.tsv` for every physical path and `SOURCE_INDEX.tsv` for every verbatim export entry. `ARTIFACTS.md` explains the large binary/generated groups.

## Critical files

* `mindset/lib/main.dart`: process bootstrap, Firebase initialization, root state.
* `mindset/lib/screens/mindset_shell.dart`: authenticated state ownership and tab navigation.
* `mindset/lib/services/journal_store.dart`: Firestore persistence and live synchronization.
* `mindset/lib/services/emotion_analyzer.dart`: Flutter ↔ Python contract.
* `mindset/lib/models/models.dart`: serialized domain contract.
* `understanding_ai/api.py`: HTTP API and model orchestration.
* `understanding_ai/bert_predict.py`: text model loading and response shaping.
* `mindset/firestore.rules`: user-isolation boundary.

## Continuation rules for another AI

Preserve per-user Firestore scoping, keep analysis-before-save as the journal UX contract, keep local endpoint configuration explicit, and update both sides of the prediction schema together. Treat Firebase API keys in generated configuration as identifiers, not server secrets; never add service-account credentials to the client. Before release, remove/lock down cleartext HTTP and permissive CORS, replace debug signing, add tests for model response parsing and Firestore synchronization, and verify voice/multimodal behavior on each target platform.

## Package contents

* `01_ANALYSIS.md`: detailed findings by requested topic.
* `02_FILE_REFERENCE.md`: file-by-file authored source/config reference.
* `03_DEPENDENCIES_AND_CONTRACTS.md`: dependency and API contracts.
* `04_RISKS_AND_ROADMAP.md`: known problems and sequenced improvements.
* `ARTIFACTS.md`: binary, generated, cache, model, and asset accounting.
* `ALL_FILES.tsv`: complete physical inventory.
* `SOURCE_INDEX.tsv`: exact export index.
* `SOURCE_EXPORT_REGENERATED.md`: verbatim source/config export.
"@
Set-Content -Encoding UTF8 (Join-Path $package 'README.md') $overview

$analysis = @'
# Detailed Reverse-Engineering Analysis

## Screens and navigation

`AuthFlow` is an in-widget enum router, not named-route navigation. `WelcomePage` opens login or sign-up through callbacks. Successful auth changes `MindSetApp` from `AuthFlow` to `MindSetShell`. The shell uses an `IndexedStack`/bottom navigation model for dashboard, journal, insights, reports, and settings; tabs remain mounted. Journal entry open/reset actions are callback signals from shell to page. Settings signs out through the root callback.

## State management

There are no Bloc/Cubit classes or events/states in the dependency graph. State is held by `StatefulWidget`s: root signed-in/theme flags, auth page enum, shell entry/settings/tab state, and page-local form/loading state. Services are plain classes/functions and are instantiated directly or passed optionally. This is simple but makes lifecycle, cancellation, and test seams less formal.

## Models

The central serialized objects are `EmotionResult`, `EmotionScore`, `ValenceScore`, `JournalEntry`, and `AppSettings`; UI-only holders include mood, weekly item, and feature data. Preserve their JSON key names when changing the API or Firestore schema. `Timestamp` values are converted at the Firestore boundary.

## Services

`AuthService` wraps email/password Firebase Auth, profile creation/update, sign-out, password reset, and Firebase error translation. `JournalStore` performs user-scoped Firestore CRUD and snapshots. `LocalStore` wraps SharedPreferences settings. `JournalAnalytics` is deterministic in-memory derivation. `EmotionAnalyzer` posts JSON over HTTP, tries configured/fallback endpoints, parses defensive response variants, and returns user-facing errors. `VoiceEmotionService` records audio through `record` and permissions through `permission_handler`; inspect it together with `JournalPage` before claiming production voice support.

## AI subsystems

Text inference uses a Hugging Face BERT sequence classifier and pickled LabelEncoder. Training in `bert_train.py` expects `data/train.csv`, `text`, and `label`, uses max length 128, stratified train/validation split, and writes `bert_model`. The API exposes health/root/predict behavior. `speech/transcribe.py` lazily loads Faster-Whisper and deletes temporary files. `audio_emotion/audio_predict.py` loads Wav2Vec2 SER artifacts and creates a text-compatible map. `multimodal/pipeline.py` runs STT, text, audio, timing, and `provisional_fusion`; fusion favors agreement, strong text, or charged negative audio under explicit thresholds.

## Networking and runtime assumptions

The Flutter client is configured for local development endpoints (Android emulator `10.0.2.2`, localhost variants). Android allows cleartext traffic. The Python API's CORS is development-permissive. No retry queue, offline write policy, auth token forwarding, or production service discovery is present.

## Assets/platforms

No Flutter asset directory is declared. Platform launchers/icons and native runner files are present for Android, iOS, macOS, Linux, and generated Flutter support. Firebase options cover Android/iOS/macOS/web/windows; Linux throws unsupported. Android has the relevant microphone/Internet/cleartext configuration; runtime permission behavior is in Dart.

## Absences verified

No map/flutter_map/OpenStreetMap, GPS, polyline, vendor/customer tracking, Firebase Storage, notifications, Bloc/Cubit, ML embedding/vector database, ONNX/TFLite runtime, or custom Lottie/audio/video asset bundle was found in authored files. Model binaries and Python virtual-environment packages are present but are catalogued as artifacts.

## Bugs and risk surfaces

* Root sign-in state is sampled once and manually toggled; an external Firebase session change is not an auth-state stream.
* `MindSetShell` and pages need lifecycle review for Firestore stream cancellation, recorder disposal, and async work after unmount.
* The Flutter/Python contract is defensive rather than generated/shared; schema drift can silently degrade results.
* Local HTTP, permissive CORS, debug release signing, and client-distributed Firebase config require production hardening.
* User journal content and local endpoint settings have no encryption or managed secrets layer.
* Large model/checkpoint/cache content is in the workspace; it should be separated from deployable source and governed by artifact policy.
* Existing tests are sparse relative to auth, Firestore, HTTP, audio, and analytics behavior.

## Roadmap

1. Establish reproducible Python environment/model artifact documentation and API contract tests.
2. Add Dart unit tests for models, analytics, response parsing, and endpoint fallback; widget tests for auth/journal flows.
3. Make auth/session and Firestore stream lifecycles explicit and cancellable.
4. Finish or remove end-to-end voice/multimodal UI integration; document platform permissions and formats.
5. Harden deployment: HTTPS, restricted CORS, no debug signing, environment-specific Firebase config, logging/monitoring, rate limits, and privacy review.
6. Only then consider richer analytics, export, encrypted local drafts, and production hosting of inference.
'@
Set-Content -Encoding UTF8 (Join-Path $package '01_ANALYSIS.md') $analysis

$deps = @'
# Dependencies and Contracts

## Flutter direct dependencies

| Dependency | Role | Essential surface | Replacement/notes |
|---|---|---|---|
| `firebase_core` | Firebase bootstrap | `main.dart`, generated options | Required for Firebase; use environment-specific config. |
| `firebase_auth` | email/password identity/session | `main.dart`, `auth_service.dart`, dashboard/settings | Supabase/Auth0/custom auth are architectural replacements. |
| `cloud_firestore` | profile/journal persistence and snapshots | `auth_service.dart`, `journal_store.dart` | Any document DB requires rewriting rules/query boundary. |
| `http` | Flutter → local AI REST | `emotion_analyzer.dart` | Dio is a possible client replacement. |
| `shared_preferences` | device-local settings | `local_store.dart` | Hive/secure storage depending on sensitivity. |
| `record` | microphone recording | `voice_emotion_service.dart` | Another recorder plugin; verify platform support. |
| `path_provider` | local temporary/audio paths | voice service | Needed where recorder requires filesystem paths. |
| `permission_handler` | microphone permission | voice service | Native permission channel alternative. |
| `cupertino_icons` | icon font | UI | Optional; Material icons cover much of the UI. |

`flutter_test` and `flutter_lints` are development dependencies. The SDK constraint is Dart `^3.12.0`; app version is `1.0.0+1`. No Bloc/Cubit, maps, storage, notification, or on-device inference package is declared.

## Python environments

`requirements_api.txt` provides FastAPI/Uvicorn, PyTorch/Transformers, Pydantic, scikit-learn/joblib, pandas, and NumPy for text API/training. `requirements_stt.txt` adds Faster-Whisper and expects ffmpeg for some containers. Audio SER has its own requirements file. The checked-in `.venv` is an environment artifact, not a portable dependency specification.

## HTTP contract

The Flutter request is JSON `{ "text": "..." }` to `/predict`. The response is expected to carry primary emotion, confidence, top emotions, valence, and optional summary/certainty/entropy metadata. The Python multimodal response is a separate richer object with `transcript`, `text_prediction`, `audio_prediction`, `provisional_final`, and timing. There is no OpenAPI/client code generation link; changes must be synchronized manually.

## Firestore and security contract

`users/{uid}` and `users/{uid}/entries/{entryId}` are the only rule paths. Authenticated UID equality is the authorization primitive. Profile creation checks the UID field, but entry rules currently allow any entry shape for the owner; schema validation is therefore client/service responsibility.
'@
Set-Content -Encoding UTF8 (Join-Path $package '03_DEPENDENCIES_AND_CONTRACTS.md') $deps

$risks = @'
# Risks, Known Problems, and Roadmap

## High priority

1. Do not ship the local HTTP/cleartext inference path as production networking.
2. Replace debug signing and establish release keystore/CI secrets management.
3. Add strict request/response validation and contract tests across Dart and Python.
4. Audit microphone, temporary-file, recorder, and model lifecycle behavior.
5. Add Firestore schema validation, indexes only when queries require them, and a documented offline/conflict policy.

## Medium priority

* Stream Firebase auth state instead of sampling `currentUser`.
* Centralize dependency creation and use interfaces/fakes for testability.
* Remove stale/duplicate model checkpoints from source distribution; retain provenance manifests.
* Add structured logging and redact journal/audio content.
* Expand test coverage to all analytics edge cases, malformed AI responses, auth errors, and stream cancellation.

## Not implemented

Maps, GPS, route generation, notifications, Firebase Storage, vector search/embeddings, TFLite/ONNX inference, and production hosting are not part of the current authored implementation.
'@
Set-Content -Encoding UTF8 (Join-Path $package '04_RISKS_AND_ROADMAP.md') $risks

$artifact = @"
# Artifact Accounting

The physical workspace contains authored code plus tool-generated and binary material. Every path is in `ALL_FILES.tsv`; this file explains why binaries are not pasted into a text source export.

* Generated/cache directories: `.dart_tool`, `.dart-localappdata`, `.pub-cache`, `build`, Python `__pycache__`, and `.venv`. These are environment outputs or third-party installs, not project-authored behavior.
* Model artifacts: `understanding_ai/bert_model/**`, audio-emotion model directories, pickles, tokenizer files, safetensors, optimizer/checkpoint state, and training reports. They are required at runtime/training but cannot be meaningfully reconstructed as prose; metadata paths and sizes remain inventoried.
* Platform binary assets: Android/iOS/macOS icons, launch images, Gradle wrapper JAR, and `cloudflared/cloudflared.exe` are represented by path/size/category.
* No custom Flutter `assets:` declaration was found in `pubspec.yaml`.

The source export includes authored text/config files outside the knowledge package and excluded generated/cache directories. Do not treat the existence of a model binary as proof that a corresponding runtime path is wired into Flutter; follow the code references in `SOURCE_EXPORT_REGENERATED.md`.
"@
Set-Content -Encoding UTF8 (Join-Path $package 'ARTIFACTS.md') $artifact

Write-Output "Generated $package"
Write-Output "Inventory: $($inventoryRows.Count) files"
Write-Output "Source export: $($sourceRows.Count) files"
