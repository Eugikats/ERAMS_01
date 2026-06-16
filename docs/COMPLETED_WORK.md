# ERAMS — Completed Work & Progress Tracker

This file tracks build progress against the phases defined in `ERAMS_TECHNICAL_BUILD_PLAN.md`.

**Legend:**
- `[ ]` Not started
- `[~]` In progress
- `[x]` Done — needs team testing
- `[✓]` Done — tested and verified by team

Update this file as work completes. For each `[x]` item, add a short note on what the team should test and how.

---

## Phase 0 — Environment & Repository Setup ✓ Complete

### Tasks
- [x] Initialize Flutter project (`flutter create . --platforms=web,android`)
- [x] Set up repo structure (folders, CLAUDE.md, AGENTS.md, docs/)
- [x] Configure `.gitignore` for Flutter (android/, ios/ committed; build/ ignored)
- [x] Write `README.md` with project overview and setup instructions
- [x] Create Supabase project (walbcsfwwgyerhfgbjdp.supabase.co); credentials in `.env`
- [x] Create Firebase project (`erams-98eb2`); `firebase init hosting` complete
- [x] Add all dependencies to `pubspec.yaml`; `flutter pub get` clean
- [x] Set up `--dart-define` environment config pattern; `.env` git-ignored
- [x] GitHub Actions workflows created and fixed (firebase-hosting-merge/pr, supabase_deploy)
- [x] All 7 GitHub repository secrets added

### Needs Team Testing
- Run `flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
- Confirm placeholder screen loads in browser with no console errors.

---

## Phase 1 — Data Model, Auth & RLS (Target: 18–20 Jun 2026)

### Tasks
- [x] SQL migration 001: schema — `profiles`, `hospitals`, `ambulances`, `incidents`, `incident_events`; PostGIS; GIST indexes; Realtime publication
- [x] SQL migration 002: auth trigger — auto-create `profiles` row on `auth.users` insert
- [x] SQL migration 003: RLS policies for all four roles + `current_user_role()` helper function
- [x] `seed.sql` updated — Healthstone Hospital + Mulago + 5 demo ambulances with Kampala coordinates
- [x] Flutter models — `Profile`, `Hospital`, `Ambulance`, `Incident`
- [x] `AuthService` — `signIn`, `signOut`, `currentProfile`
- [x] Riverpod `authStateProvider` and `currentProfileProvider`
- [x] Login screen — email/password form, role-based redirect on success, error handling
- [x] `app.dart` updated — theme wired in, GoRouter with auth redirect + role routes

### Needs Team Testing
- Enable PostGIS in Supabase Dashboard → Database → Extensions before applying migrations.
- Apply migrations: paste each `supabase/migrations/0*.sql` file into the Supabase SQL Editor in order (001 → 002 → 003), OR run `supabase db push` via CLI.
- Apply `supabase/seed.sql` via SQL Editor.
- Create the 4 demo accounts in Supabase Dashboard → Authentication → Add User (use the credentials in `seed.sql` header comments).
- Set the role for each account: in SQL Editor run the UPDATE statements from `seed.sql`.
- Log in with each of the 4 demo accounts from the Flutter web app. Confirm each lands on a role-labelled placeholder screen.
- Attempt to log in with a wrong password — confirm a friendly error message appears.
- Try to access `/dispatcher` while logged out — confirm it redirects to `/login`.

---

## Phase 2 — Dispatcher Module: Incident Logging & Map (Target: 20–22 Jun 2026)

### Tasks
- [ ] **Theme pass** — `AppColors`, `AppTheme` (Material 3), status colour constants, placeholder logo widget — wire into `EramsApp`
- [ ] "New Incident" form: location pin drop, nature of emergency, patient notes, hospital selector
- [ ] Map widget: incident markers, ambulance markers (colour-coded by status), hospital markers
- [ ] Wire incident creation to `incidents` table
- [ ] Dispatcher Dashboard: active incident cards with status badges, filterable by status
- [ ] Realtime subscription for `incidents` and `ambulances` — live updates on map/list

### Needs Team Testing
- Log a new incident as a Dispatcher.
- Confirm it appears on the Dashboard list AND the map instantly (without page refresh).
- Have a second browser session open — confirm the incident appears there in real time too.
- Confirm all status badge colours match the agreed palette (available=green, dispatched=orange, en_route=blue, etc.).

---

## Phase 3 — Automated Dispatch RPC (Target: 22–24 Jun 2026)

### Tasks
- [ ] Postgres function `assign_nearest_ambulance(incident_id)` with PostGIS ST_Distance
- [ ] Supabase RPC exposed; called from Flutter via `supabase.rpc(...)`
- [ ] "Dispatch" button on Dispatcher Dashboard for `logged` incidents
- [ ] Edge case UI: no ambulance available — clear error state + manual override
- [ ] `update_incident_status` function for status transitions (dispatcher + driver roles)

### Needs Team Testing
- Click "Dispatch" on a logged incident with seeded ambulances at varying distances.
- Confirm the nearest ambulance is assigned (check ambulance coordinates in Supabase table).
- Confirm both `incidents` and `ambulances` records update atomically.
- Test the "no ambulance available" edge case (set all ambulances to `busy` in DB first).

---

## Phase 4 — Driver Module (Mobile) (Target: 24–25 Jun 2026)

### Tasks
- [ ] Driver home screen: status toggle (available/busy/offline), incoming incident alert card
- [ ] Realtime subscription filtered to driver's `ambulance_id` for dispatch alerts
- [ ] Periodic GPS location updates every 10–15 seconds while active
- [ ] Status transition buttons: "En Route" → "Arrived" → "Completed" (calls `update_incident_status`)
- [ ] Offline queuing: local cache for failed location updates, retry on reconnect

### Needs Team Testing
- On a physical or emulated Android device, log in as the driver demo account.
- Dispatch an incident to that driver's ambulance (from a separate Dispatcher browser session).
- Confirm the driver receives the alert instantly on the mobile app.
- Walk around (or simulate GPS movement) — confirm location updates appear on the Dispatcher's map within ~15 seconds.
- Toggle to airplane mode, make a status change, come back online — confirm the queued change syncs.

---

## Phase 5 — Hospital Module & Notifications (Target: 25–26 Jun 2026)

### Tasks
- [ ] Hospital view: list of incidents assigned to the user's `hospital_id`, active statuses only
- [ ] Incident detail: patient condition notes, ambulance location, estimated ETA
- [ ] Realtime subscription for new assignments and location updates
- [ ] "Acknowledge / Ready to receive" action (writes `incident_events` entry)

### Needs Team Testing
- Log in as the hospital-role demo account for Mulago.
- Dispatch an incident assigned to Mulago from the Dispatcher.
- Confirm the hospital sees the incoming patient card appear without refreshing.
- Confirm the ambulance location and ETA update live as the driver moves.
- Click "Acknowledge" and confirm an event entry appears in `incident_events` in Supabase.

---

## Phase 6 — Admin Module: Fleet & Analytics (Target: 26–27 Jun 2026)

### Tasks
- [ ] Admin screens: manage `profiles` (assign roles), manage `ambulances` (add/edit/assign driver)
- [ ] Basic analytics: average response time (created_at → arrived_at), incident counts by status, incidents by hospital

### Needs Team Testing
- Log in as admin, create a new ambulance record and assign it to a driver.
- Create a new user and assign them the "dispatcher" role.
- Confirm the analytics dashboard shows correct counts from seeded/test incident data.
- Run a full incident flow end-to-end and confirm response time appears in analytics.

---

## Phase 7 — Polish, Offline Hardening & Deployment (Target: 27–29 Jun 2026)

### Tasks
- [ ] Responsive layout pass: Dispatcher/Admin on desktop widths; Driver/Hospital on mobile
- [ ] Offline-first review: confirm graceful degradation + sync-on-reconnect
- [ ] Build and deploy Flutter web to Firebase Hosting via GitHub Actions
- [ ] Build Android APK for driver demo device
- [ ] Finalize Supabase migrations and seed data (both hospitals, realistic Kampala ambulance positions)
- [ ] Smoke-test full end-to-end flow

### Needs Team Testing
- Open the deployed Firebase Hosting URL in a desktop browser — confirm Dispatcher view is usable.
- Open the same URL on a mobile browser — confirm it doesn't break.
- Install the Android APK on a physical device and run the full dispatch flow against the live Supabase instance.
- Full smoke test: dispatcher logs → auto-assign → driver alert → live location → hospital ETA → status complete → admin analytics updated.

---

## Phase 8 — Validation, Documentation & Demo Prep (Target: 29–30 Jun 2026)

### Tasks
- [ ] Prepare evaluation form (ease of use, GPS accuracy, dispatch speed, communication effectiveness)
- [ ] Update README with final setup/deployment instructions, architecture diagram, known limitations
- [ ] Capture screenshots/screen recordings for final report and oral defense
- [ ] Tag release `v1.0-demo` in GitHub

### Needs Team Testing
- Run through the evaluation form as if you are an end user (dispatcher, driver, hospital staff).
- Confirm all screenshots/recordings capture the key flows clearly for the final report.

---

*Last updated: 17 June 2026*
