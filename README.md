# ERAMS — Emergency Response and Ambulance Management System

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=flat-square&logo=supabase&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Hosting-FFCA28?style=flat-square&logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Status](https://img.shields.io/badge/Status-In%20Development-yellow?style=flat-square)

> **Final Year Project — Bachelor of Information Technology and Computing**  
> Kyambogo University | Uganda | Academic Year 2025–2026

---

## Project Description

ERAMS digitises emergency ambulance dispatch across selected hospitals in Uganda — one public (Mulago National Referral Hospital) and one private (Healthstone Hospital, Banda). The system replaces manual telephone-based dispatch and paper logbooks with:

- **Automated nearest-ambulance dispatch** using PostGIS geospatial queries
- **Live GPS tracking** of ambulances in real time (Supabase Realtime)
- **Role-based access control** (Dispatcher, Driver, Hospital Staff, Administrator)
- **Advance hospital notifications** with patient condition and ETA
- **Analytics dashboard** for response-time performance evaluation
- **Offline resilience** for drivers in low-connectivity environments

Built as a **single Flutter codebase** targeting web (Dispatcher, Hospital, Admin) and Android (Ambulance Driver), with Supabase as the backend and Firebase Hosting for the web app.

---

## Architecture

| Layer | Technology |
|-------|-----------|
| Client | Flutter (web + Android) |
| Backend-as-a-Service | Supabase (Postgres + PostGIS, Auth, Realtime, Edge Functions) |
| Web Hosting | Firebase Hosting (static Flutter web build) |
| State Management | Riverpod |
| Maps | `flutter_map` + OpenStreetMap tiles |
| Routing | `go_router` |
| CI/CD | GitHub Actions |

See `docs/ERAMS_TECHNICAL_BUILD_PLAN.md` for the full architecture diagram, ERD, and dispatch sequence diagram.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | 3.x stable | https://docs.flutter.dev/get-started/install |
| Dart | bundled with Flutter | — |
| Android Studio or VS Code | latest | IDE + Flutter extension |
| Supabase CLI | latest | `npm install -g supabase` |
| Firebase CLI | latest | `npm install -g firebase-tools` |
| Git | 2.x | https://git-scm.com |

---

## Local Setup

### 1 — Clone the repository

```bash
git clone https://github.com/forva2025/ERAMS_01.git
cd ERAMS_01
```

### 2 — Install Flutter dependencies

```bash
flutter pub get
```

### 3 — Configure environment

Copy `.env.example` to `.env` (this file is git-ignored):

```bash
cp .env.example .env
```

Open `.env` and fill in your Supabase project URL and anon key:

```dotenv
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
FIREBASE_PROJECT_ID=your-firebase-project-id
```

### 4 — Run on web

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=$(grep SUPABASE_URL .env | cut -d= -f2) \
  --dart-define=SUPABASE_ANON_KEY=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
```

Or on Android:

```bash
flutter run -d <your_device_id> \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

---

## Supabase Setup (first time)

```bash
# Link to your remote Supabase project
supabase link --project-ref your-project-ref

# Apply migrations
supabase db push

# Seed demo data
supabase db reset --db-url <your-db-url>   # applies migrations + seed.sql
```

Enable the **PostGIS** extension in the Supabase dashboard under Database → Extensions before running migrations.

---

## Firebase Hosting Setup (first time)

```bash
firebase login
firebase init hosting   # point public dir to build/web; configure as SPA
```

### Deploy web build

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
firebase deploy --only hosting
```

---

## Running Tests

```bash
# Unit and widget tests
flutter test

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## Build Phases

| Phase | Target | Description |
|-------|--------|-------------|
| 0 | 17–18 Jun | Environment & repo setup |
| 1 | 18–20 Jun | Data model, Auth, RLS |
| 2 | 20–22 Jun | Dispatcher module |
| 3 | 22–24 Jun | Automated dispatch RPC |
| 4 | 24–25 Jun | Driver mobile module |
| 5 | 25–26 Jun | Hospital module |
| 6 | 26–27 Jun | Admin module |
| 7 | 27–29 Jun | Polish & deployment |
| 8 | 29–30 Jun | Validation & demo prep |

Progress tracked in [`docs/COMPLETED_WORK.md`](docs/COMPLETED_WORK.md).  
Full phase specifications in [`docs/ERAMS_TECHNICAL_BUILD_PLAN.md`](docs/ERAMS_TECHNICAL_BUILD_PLAN.md).

---

## Project Structure

```
ERAMS_01/
├── docs/                          ← build plan, progress tracker
├── .github/workflows/             ← CI/CD (GitHub Actions)
├── lib/
│   ├── main.dart
│   ├── app.dart                   ← root widget, routing, theme
│   ├── core/                      ← config, theme, utils
│   ├── models/                    ← Dart data classes
│   ├── services/                  ← Supabase & Realtime wrappers
│   ├── state/                     ← Riverpod providers
│   ├── features/                  ← auth, dispatcher, driver, hospital, admin
│   └── widgets/                   ← shared UI components
├── supabase/
│   ├── migrations/                ← SQL schema + RLS policies
│   ├── functions/                 ← Edge Functions (Deno/TypeScript)
│   └── seed.sql
├── web/                           ← Flutter web platform files
├── test/
├── pubspec.yaml
├── firebase.json
└── .firebaserc
```

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

## Known Limitations (MVP)

- ETA calculation uses a straight-line distance estimate, not a routing API
- DHIS2 export is not implemented (deferred post-MVP)
- Desktop native build (Windows/macOS) is a stretch target — primary "desktop" experience is the responsive web app

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

© 2025–2026 Ashaba Ritah, Ochiria Elias Onyait, Katusiime Eugene, Ashaka Joseph — Kyambogo University
