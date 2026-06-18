# ERAMS — Emergency Response and Ambulance Management System

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=flat-square&logo=supabase&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Hosting-FFCA28?style=flat-square&logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Status](https://img.shields.io/badge/Status-v1.0--demo-brightgreen?style=flat-square)

> **Final Year Project — Bachelor of Information Technology and Computing**  
> Kyambogo University | Uganda | Academic Year 2025–2026

---

## Live Demo

| Target | URL / File |
|--------|-----------|
| **Web app (Dispatcher, Hospital, Admin)** | Deployed via Firebase Hosting — see GitHub Actions for the live URL after CI passes |
| **Android APK (Driver)** | Built locally: `flutter build apk --release --dart-define-from-file=.env.json` |

**Demo credentials** (Supabase Auth):

| Role | Email | Password |
|------|-------|----------|
| Dispatcher | `katusiime66+dispatcher@gmail.com` | `Erams2026!` |
| Driver | `katusiime66+driver@gmail.com` | `Erams2026!` |
| Hospital Staff | `katusiime66+hospital@gmail.com` | `Erams2026!` |
| Administrator | `katusiime66+admin@gmail.com` | `Erams2026!` |

---

## What ERAMS Does

ERAMS digitises emergency ambulance dispatch across two Kampala hospitals — **Mulago National Referral Hospital** and **Healthstone Hospital, Banda**. It replaces manual telephone dispatch and paper logbooks with:

- **Automated nearest-ambulance dispatch** — PostGIS `ST_Distance` picks the closest available unit; dispatcher can override manually
- **Live GPS tracking** — driver location uploads every 15 s; appears in real time on the dispatcher's map
- **Role-based access control** — four roles (Dispatcher, Driver, Hospital Staff, Administrator) each see only their own module
- **Advance hospital notifications** — hospital staff see the incoming patient, ambulance status, and live ETA before arrival
- **Incident history & analytics** — completed/cancelled incidents searchable by role; admin dashboard shows counts by status/hospital and average response time
- **Offline resilience** — failed GPS pushes queue and retry automatically on the next 15 s tick

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter Client                        │
│  ┌──────────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │  Dispatcher  │  │  Driver  │  │ Hospital │  │ Admin  │  │
│  │  (web)       │  │(Android) │  │  (web)   │  │ (web)  │  │
│  └──────┬───────┘  └────┬─────┘  └────┬─────┘  └───┬────┘  │
│         │   go_router + Riverpod       │             │       │
└─────────┼──────────────┼──────────────┼─────────────┼───────┘
          │              │              │             │
          ▼              ▼              ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│                         Supabase                             │
│                                                              │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │  Postgres   │  │   Realtime   │  │  Auth (email/pw)   │  │
│  │  + PostGIS  │  │  (websocket) │  │  + RLS policies    │  │
│  └──────┬──────┘  └──────┬───────┘  └────────────────────┘  │
│         │                │                                   │
│  ┌──────▼──────────────────────────────────────────────┐    │
│  │  Tables: profiles · hospitals · ambulances ·        │    │
│  │          incidents · incident_events                 │    │
│  │  RPCs:   dispatch_incident · update_incident_status  │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│              Firebase Hosting (web only)                     │
│         Static Flutter web build → `build/web`              │
└─────────────────────────────────────────────────────────────┘
```

| Layer | Technology |
|-------|-----------|
| Client | Flutter 3.x (single codebase — web + Android) |
| State management | Riverpod (`AsyncNotifier`, `FutureProvider`, `StateProvider`) |
| Navigation | `go_router` with role-based redirect |
| Maps | `flutter_map` + OpenStreetMap (zero cost, no API key) |
| Backend | Supabase (Postgres + PostGIS, Auth, Realtime) |
| Web hosting | Firebase Hosting |
| CI/CD | GitHub Actions |

---

## Data Model (ERD — simplified)

```
profiles ──────────────────────────────────────┐
  id (uuid, FK → auth.users)                   │
  full_name, phone, role, hospital_id           │
                                                │
hospitals ─────────────────────────────────────┤
  id, name, address, location (geography)       │
                                                │
ambulances ────────────────────────────────────┤
  id, plate_number, status, current_location    │
  driver_id (FK → profiles), hospital_id        │
                                                │
incidents ─────────────────────────────────────┤
  id, reporter_name, reporter_phone             │
  location (geography), location_description   │
  nature_of_emergency, patient_condition_notes  │
  status (logged/dispatched/en_route/           │
          arrived/completed/cancelled)          │
  assigned_ambulance_id (FK → ambulances)       │
  hospital_id (FK → hospitals)                  │
  created_at, arrived_at, completed_at          │
                                                │
incident_events ────────────────────────────── ┘
  id, incident_id (FK), actor_id (FK → profiles)
  event_type, payload (jsonb), created_at
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | 3.x stable | https://docs.flutter.dev/get-started/install |
| Android Studio or VS Code | latest | + Flutter/Dart extensions |
| Supabase CLI | latest | `npm install -g supabase` |
| Firebase CLI | latest | `npm install -g firebase-tools` |

---

## Local Setup

### 1. Clone & install

```bash
git clone https://github.com/Eugikats/ERAMS_01.git
cd ERAMS_01
flutter pub get
```

### 2. Configure credentials

Create `.env.json` from the example (git-ignored):

```bash
cp .env.example .env.json
```

Edit `.env.json` to match this format:

```json
{
  "SUPABASE_URL": "https://walbcsfwwgyerhfgbjdp.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-key-here"
}
```

> The `.vscode/launch.json` is pre-configured — press **F5** in VS Code to run on Chrome with credentials injected automatically.

### 3. Run on web (Chrome)

```bash
flutter run -d chrome --dart-define-from-file=.env.json
```

### 4. Run on Android

```bash
flutter devices                            # find your device ID
flutter run -d <device_id> --dart-define-from-file=.env.json
```

---

## Supabase Setup (first time only)

```bash
# Link to the remote project
supabase link --project-ref walbcsfwwgyerhfgbjdp

# Apply all migrations (schema, RLS, dispatch RPCs)
supabase db push

# Seed demo hospitals, ambulances, and user profiles
# (Run seed.sql via Supabase Dashboard → SQL Editor)
```

Enable the **PostGIS** extension in the Supabase dashboard:  
**Database → Extensions → postgis → Enable**

Demo accounts must be created manually in **Authentication → Users → Add User** using the emails in the table above, then `seed.sql` sets correct roles.

---

## Deployment

### Web — Firebase Hosting (CI/CD)

Pushing to `main` triggers the GitHub Actions workflow automatically:

```
.github/workflows/firebase-hosting-merge.yml
```

It runs `flutter analyze` → `flutter test` → `flutter build web --release` → `firebase deploy`.

**Required GitHub repository secrets:**

| Secret | Where to find it |
|--------|-----------------|
| `SUPABASE_URL` | Supabase project → Settings → API |
| `SUPABASE_ANON_KEY` | Supabase project → Settings → API |
| `FIREBASE_SERVICE_ACCOUNT_ERAMS_98EB2` | Firebase → Project Settings → Service Accounts |

### Android APK (manual)

```bash
flutter build apk --release --dart-define-from-file=.env.json
# Output: build/app/outputs/flutter-apk/app-release.apk
# Transfer to device: adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Project Structure

```
ERAMS_01/
├── docs/
│   ├── ERAMS_TECHNICAL_BUILD_PLAN.md   ← full architecture & phase specs
│   ├── COMPLETED_WORK.md               ← progress tracker
│   └── EVALUATION_FORM.md              ← structured user evaluation form
├── .github/workflows/                   ← CI/CD (Firebase + Supabase deploy)
├── lib/
│   ├── main.dart                        ← app entry point, Supabase init
│   ├── app.dart                         ← root widget, theme, go_router
│   ├── core/
│   │   ├── config/                      ← Supabase credentials (--dart-define)
│   │   ├── theme/                       ← AppColors, AppTheme
│   │   └── utils/                       ← geo_utils (EWKB → lat/lng)
│   ├── models/                          ← Profile, Hospital, Ambulance, Incident
│   ├── services/                        ← Supabase client wrappers (one per domain)
│   ├── state/                           ← Riverpod providers & notifiers
│   ├── features/
│   │   ├── auth/                        ← login screen, role-based redirect
│   │   ├── dispatcher/                  ← dashboard, live map, incident form, dispatch
│   │   ├── driver/                      ← GPS tracking, alerts, status transitions
│   │   ├── hospital/                    ← incoming patients, ETA, acknowledge
│   │   └── admin/                       ← fleet management, user roles, analytics
│   └── widgets/                         ← StatusBadge, AppLogo, ProfileEditSheet,
│                                           IncidentHistoryList
├── supabase/
│   ├── migrations/                      ← 001 schema · 002 auth trigger · 003 RLS · 004 RPCs
│   ├── functions/                       ← Edge Function stubs (Deno/TypeScript)
│   └── seed.sql                         ← demo hospitals, ambulances, users
├── web/                                 ← Flutter web platform files
├── pubspec.yaml
├── firebase.json / .firebaserc
└── .env.example
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `flutter_map` + OpenStreetMap instead of Google Maps | Zero cost, no API key required — important for a student project with limited budget |
| Supabase Realtime re-fetch pattern (not raw payload) | PostGIS geography columns arrive as hex WKB in Realtime payloads, which require custom parsing; re-fetching via REST returns clean GeoJSON |
| `SECURITY DEFINER` Postgres RPCs for dispatch | Ensures atomic dispatch (ambulance + incident updated in one transaction) with server-side role validation, not client-side |
| Straight-line Haversine ETA (÷ 40 km/h) | Routing APIs (OSRM, Google Directions) add cost and complexity; straight-line is sufficient for MVP demonstration |
| GPS queue-and-retry on driver | Addresses the connectivity reliability concern raised in both Mulago and Healthstone stakeholder interviews |

---

## Known Limitations (MVP)

- **ETA** is a straight-line distance estimate divided by an average speed of 40 km/h — not a routing API result. Accuracy degrades for routes with significant road detours.
- **DHIS2 export** is not implemented. The data model is structured (all incidents have timestamps and structured fields) so a CSV/DHIS2 export could be added post-MVP.
- **Desktop native build** (Windows/macOS) is not a target. The "desktop" experience is the responsive web app viewed in a browser.
- **Push notifications** (FCM) are not implemented. Drivers receive alerts only while the app is open. A future version could add background push via Firebase Cloud Messaging.
- **Multi-dispatch** (one incident, multiple ambulances) is not supported. Each incident has a single `assigned_ambulance_id`.

---

## Running Tests

```bash
flutter test
```

---

## Build Phases Summary

| Phase | Dates | Deliverable |
|-------|-------|-------------|
| 0 | 17–18 Jun | Flutter project init, Supabase + Firebase setup, CI stubs |
| 1 | 18–20 Jun | DB schema, Auth, RLS, seed data, login + role routing |
| 2 | 20–22 Jun | Dispatcher dashboard, incident form, live map, Realtime |
| 3 | 22–24 Jun | Auto-dispatch RPC (PostGIS nearest), manual override |
| 4 | 24–25 Jun | Driver module — GPS tracking, alerts, status transitions |
| 5 | 25–26 Jun | Hospital module — incoming patients, live ETA, acknowledge |
| 6 | 26–27 Jun | Admin module — fleet management, user roles, analytics |
| 7 | 27–29 Jun | Profile sheet, history tabs (all roles), GPS web guard |
| 8 | 29–30 Jun | Evaluation form, final docs, `v1.0-demo` tag |

Full phase specifications and progress: [`docs/COMPLETED_WORK.md`](docs/COMPLETED_WORK.md)

---

## Team

| Name | Role |
|------|------|
| Ashaba Ritah | Team member |
| Ochiria Elias Onyait | Team member |
| Katusiime Eugene | Team member |
| Ashaka Joseph | Team member |

**Supervisor:** Ms. Shallon Ahimbisibwe, Department of Computer Science, Kyambogo University

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

© 2025–2026 Ashaba Ritah, Ochiria Elias Onyait, Katusiime Eugene, Ashaka Joseph — Kyambogo University
