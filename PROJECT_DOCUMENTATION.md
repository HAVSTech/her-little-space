# Harini's Little Space — Flutter App

## Overview

**Harini's Little Space** is a private, lightweight Flutter companion app for tracking cycle information, personal check-ins, relationship memories, and shared little moments.

The Flutter app uses the **same Supabase backend as the existing web application**, so shared cycle records and relationship statistics remain synchronized across supported clients.

The project focuses on:
- Calm, minimal, romantic UI.
- Shared cycle history backed by Supabase.
- Local mood, symptom, and theme preferences.
- Shared relationship-moment counter.
- Cycle insights and estimated fertile-window notifications.
- Responsive scrolling with safe spacing around the floating bottom navigation.
- Custom app branding and launcher icon.

---

## Core Features

### 1. Today

- Current date and dynamic greeting.
- Custom app branding and logo.
- Current cycle day.
- Estimated cycle phase.
- Average cycle length.
- Estimated next period date.
- Estimated fertile-window alert.
- Mood selection.
- Symptom tracking.
- Recent cycle information.
- Pull-to-refresh for shared data.
- Light/dark theme switching.

> Cycle and fertility information is presented as a calendar-based estimate. It is not intended to confirm ovulation, pregnancy, or provide medical certainty.

### 2. Cycle History

- Total logged periods.
- Average cycle length.
- Visual cycle-length chart.
- Month-by-month chart labels.
- Hover/long-press chart interaction.
- Cycle duration for individual history entries.
- Start date and optional start time.
- Swipe-to-delete cycle records.
- Log-period action.
- Confirmation dialog before deleting a shared record.

Cycle duration is calculated from consecutive period start dates.

### 3. Log Period

Users can log:
- Period start date.
- Optional start time.
- Optional period end date.

After saving, the app refreshes the shared cycle history and shows a confirmation dialog.

### 4. Fertile-Window Estimate

The app calculates an estimated fertile window using the average cycle length.

The UI intentionally uses language such as **Higher pregnancy possibility** and **Estimated fertile window**. It does not describe calendar days as guaranteed safe or unsafe days.

### 5. Mood and Symptoms

Mood and symptom selections are stored locally on the device using `SharedPreferences`. These lightweight personal preferences are not sent to Supabase.

### 6. Us / Relationship Space

The Us section contains:
- Relationship anniversary.
- Birthday dates.
- Days-together counter.
- Special memories.
- First outing memory.
- Relationship milestone memory.
- Shared Little Moments counter.
- Add-a-moment action.

The Little Moments counter is shared through Supabase and uses an atomic database RPC to avoid client-side race conditions.

### 7. Dark Mode

- Light theme.
- Dark theme.
- Persistent theme selection using `SharedPreferences`.

### 8. Custom App Branding

- `assets/images/app_logo.png`.
- Android/iOS launcher icon configuration.
- Rose/blush visual language.
- Material 3 theming.
- Rounded cards and soft borders.
- Floating liquid-glass-inspired bottom navigation.

---

## Technology Stack

| Layer | Technology |
|---|---|
| Mobile framework | Flutter |
| Language | Dart |
| UI | Flutter Material 3 |
| Backend | Supabase |
| Database | PostgreSQL via Supabase |
| Authentication | Supabase Anonymous Auth |
| Local storage | SharedPreferences |
| Date formatting | intl |
| State management | Flutter `ChangeNotifier` |
| Database RPC | PostgreSQL function |
| App icons | flutter_launcher_icons |
| Source control | Git / GitHub |
| Build targets | Android / iOS |

### Main Dependencies

~~~yaml
supabase_flutter: ^2.17.2
shared_preferences: ^2.5.5
intl: ^0.20.3
flutter_launcher_icons: ^0.14.4
~~~

---

## Architecture

The application follows a lightweight layered architecture.

~~~text
Flutter UI Screens
       │
       ▼
AppState (ChangeNotifier)
       │
       ├──────────────► SupabaseService ─────► Supabase Auth
       │                       │
       │                       ├─────────────► shared_period_cycles
       │                       ├─────────────► shared_relationship_stats
       │                       └─────────────► increment_shared_intimacy()
       │
       └──────────────► PreferencesService ──► SharedPreferences
~~~

### Application Flow

~~~text
Flutter App
    │
    ├── AppState
    │     │
    │     ├── Cycle data ──────────> SupabaseService
    │     │                              │
    │     │                              └── shared_period_cycles
    │     │
    │     ├── Little Moments ──────> SupabaseService
    │     │                              │
    │     │                              ├── shared_relationship_stats
    │     │                              └── increment_shared_intimacy()
    │     │
    │     └── Mood / Symptoms / Theme
    │                                    │
    │                                    └── PreferencesService
    │                                             │
    │                                             └── SharedPreferences
    │
    └── Flutter UI
~~~

---

## Project Structure

~~~text
her-little-space/
│
├── android/
├── assets/
│   └── images/
│       └── app_logo.png
├── ios/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── period_cycle.dart
│   ├── services/
│   │   ├── supabase_service.dart
│   │   └── preferences_service.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── widgets/
│       └── common.dart
├── pubspec.yaml
└── README.md
~~~

---

## State Management

The app uses Flutter's built-in `ChangeNotifier` rather than a third-party state-management package.

`AppState` is responsible for loading and updating cycle data, the shared Little Moments count, local preferences, mood, symptoms, and theme state.

The root `App` listens to `AppState` with `AnimatedBuilder`, keeping the dependency footprint small while providing reactive UI updates.

---

## Backend Architecture

### Shared Cycle Data

Table: `public.shared_period_cycles`

Fields:

~~~text
id
period_start
period_start_time
period_end
created_at
~~~

The app loads records ordered by `period_start DESC`. Cycle lengths are calculated locally from consecutive period start dates.

### Shared Relationship Data

Table: `public.shared_relationship_stats`

Field:

~~~text
intimacy_count
~~~

The count is incremented through `increment_shared_intimacy()`. The database performs the increment atomically rather than relying on a read → local increment → write sequence.

---

## Authentication

The app uses **Supabase Anonymous Authentication**.

Startup flow:

~~~text
App launch
    ↓
Check current Supabase user
    ↓
No user?
    ↓
Sign in anonymously
    ↓
Load shared data
~~~

No email/password account is required for the current application flow.

---

## Data Persistence Strategy

The application separates shared data from device-local preferences.

### Supabase

Used for data shared across clients:
- Period history.
- Period start times.
- Period end dates.
- Relationship Little Moments count.

### SharedPreferences

Used for device-specific preferences:
- Selected mood.
- Selected symptoms.
- Dark/light theme.

---

## Security Considerations

The Flutter application uses the **Supabase publishable key**, intended for client-side applications.

The application does **not** use or expose a Supabase service-role key.

Backend access is controlled through Supabase authentication and Row Level Security policies.

Sensitive server-side credentials must never be committed to GitHub.

---

## UI / UX Design

The visual system uses a soft rose/blush palette:

~~~text
Background   #FFFBF9
Surface      #FFFFFF
Ink          #332A2D
Muted        #7B7074
Rose         #B95763
Rose Soft    #F8E9EB
Line         #EAD7DA
Blush        #FFF2F0
~~~

Design characteristics:
- Rounded cards.
- Soft borders.
- Low visual density.
- Rose accent color.
- Gentle typography hierarchy.
- Material 3 components.
- Floating glass-style navigation.
- Responsive scrolling.
- Safe-area-aware bottom spacing.

All primary scrollable pages reserve additional bottom space so the floating navigation does not cover the final content.

---

## Navigation

The application currently has three main sections:

~~~text
┌──────────────┬──────────────┬──────────────┐
│    Today     │   History    │      Us      │
└──────────────┴──────────────┴──────────────┘
~~~

Navigation uses an `IndexedStack`, allowing the main screens to remain mounted while switching tabs.

---

## Build

### Development

~~~bash
flutter pub get
flutter run
~~~

### Analyze

~~~bash
flutter analyze
~~~

### Android Release APK

~~~bash
flutter clean
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
~~~

APK output:

`build/app/outputs/flutter-apk/app-release.apk`

### Android Split APKs

~~~bash
flutter build apk --release --split-per-abi
~~~

### Play Store App Bundle

~~~bash
flutter build appbundle --release
~~~

---

## Development Notes

- The Flutter app shares its backend with the web version.
- Do not create a second Supabase project for this client.
- Do not replace shared cycle storage with local-only cycle data.
- Preserve local-date behavior for period dates.
- Keep cycle calculations based on calendar dates rather than UTC date conversion.
- Preserve the atomic RPC for the Little Moments counter.
- Keep bottom-navigation safe-area spacing when adding new scrollable pages.
- Use the existing app logo asset rather than Flutter's default launcher icon.

---

## Future Extension Areas

Potential future additions:
- Push notifications.
- More detailed cycle analytics.
- Optional data export.
- Additional relationship memories.
- Cloud synchronization of additional preferences.
- App onboarding.
- Secure application distribution through Google Play / App Store.

---

## Repository

**GitHub:** `HAVSTech/her-little-space`

**Application:** Harini's Little Space

**Backend:** Shared Supabase project used by the web and Flutter clients.