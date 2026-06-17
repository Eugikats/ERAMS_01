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
- [✓] Initialize Flutter project (`flutter create . --platforms=web,android`)
- [✓] Set up repo structure (folders, CLAUDE.md, AGENTS.md, docs/)
- [✓] Configure `.gitignore` for Flutter (android/, ios/ committed; build/ ignored)
- [✓] Write `README.md` with project overview and setup instructions
- [✓] Create Supabase project (walbcsfwwgyerhfgbjdp.supabase.co); credentials in `.env`
- [✓] Create Firebase project (`erams-98eb2`); `firebase init hosting` complete
- [✓] Add all dependencies to `pubspec.yaml`; `flutter pub get` clean
- [✓] Set up `--dart-define` environment config pattern; `.env` and `.env.json` git-ignored
- [✓] `.vscode/launch.json` added — press F5 in VS Code to run with credentials automatically
- [✓] GitHub Actions workflows created and fixed (firebase-hosting-merge/pr, supabase_deploy)
- [✓] All 7 GitHub repository secrets added
- [✓] `web/passkeys.js` added — fixes supabase_flutter passkeys_web plugin crash on web startup

### Verified
- Local dev confirmed working with `flutter build web --dart-define-from-file=.env.json`
- App loads in browser; no fatal console errors

---

## Phase 1 — Data Model, Auth & RLS ✓ Complete

### Tasks
- [✓] SQL migration 001: schema — `profiles`, `hospitals`, `ambulances`, `incidents`, `incident_events`; PostGIS; GIST indexes; Realtime publication
- [✓] SQL migration 002: auth trigger — auto-create `profiles` row on `auth.users` insert
- [✓] SQL migration 003: RLS policies for all four roles + `current_user_role()` helper function
- [✓] `seed.sql` applied — Healthstone Hospital + Mulago + 5 demo ambulances with Kampala coordinates
- [✓] 4 demo accounts created in Supabase Auth with correct roles and real UUIDs in seed.sql
- [✓] Flutter models — `Profile`, `Hospital`, `Ambulance`, `Incident`
- [✓] `AuthService` — `signIn`, `signOut`, `currentProfile`
- [✓] Riverpod `authStateProvider` and `currentProfileProvider`
- [✓] Login screen — email/password form, role-based redirect on success, error handling
- [✓] `app.dart` updated — theme wired in, GoRouter with auth redirect + role routes
- [✓] `main.dart` — startup guard shows readable error if credentials missing (no more blank screen)

### Verified
- All 4 demo accounts log in and land on correct role placeholder screens
- Driver (`katusiime66+driver@gmail.com`) → Ambulance Driver screen ✓
- Dispatcher, Hospital, Admin accounts route correctly ✓
- Red ERAMS theme and app bar render correctly ✓

---

## Phase 2 — Dispatcher Module: Incident Logging & Map ✓ Complete

### Tasks
- [✓] **Theme pass** — `AppColors`, `AppTheme` (Material 3), status colour constants, placeholder logo widget — wired into `EramsApp` (done during Phase 1 setup)
- [x] "New Incident" form: location pin drop on map (`LocationPickerDialog`), nature of emergency dropdown (10 types), patient notes, hospital selector
- [x] Map widget (`_MapPanel`): incident markers (red/tappable), ambulance markers (colour-coded by status with tooltip), hospital markers (blue), map legend overlay
- [x] Wire incident creation to `incidents` table via `IncidentService.createIncident()`
- [x] Dispatcher Dashboard (`DispatcherDashboard`): active incident cards with status badges, filterable by status (All / Logged / Dispatched / En Route / Arrived), responsive two-panel layout (>= 800px) or tabbed layout (< 800px)
- [x] Realtime subscription for `incidents` and `ambulances` — live updates via `IncidentsNotifier` and `AmbulancesNotifier` (Supabase Realtime → re-fetch on change)

### Needs Team Testing
- Log in as the Dispatcher demo account and verify the dashboard loads with the map centred on Kampala.
- Click "New Incident": pick a location on the map, fill in all fields, submit — confirm the card appears in the list and a red marker appears on the map without page refresh.
- Open a second browser tab as Dispatcher — confirm the new incident appears there in real time too.
- Confirm status badge colours: logged=teal, dispatched=orange, en_route=blue, arrived=purple.
- Tap an incident card → map should fly to that incident's location and highlight the card.
- Confirm ambulance markers appear with correct status colours (seeded ambulances have Kampala coordinates).

---

## Phase 3 — Automated Dispatch RPC ✓ Complete

### Tasks
- [x] Postgres function `dispatch_incident(p_incident_id, p_ambulance_id DEFAULT NULL)` — auto picks nearest available ambulance via PostGIS ST_Distance; accepts optional manual ambulance override; `SECURITY DEFINER`, atomic transaction, GRANT to authenticated
- [x] Postgres function `update_incident_status(p_incident_id, p_new_status)` — transitions incident lifecycle, syncs ambulance status, writes incident_events audit row; callable by dispatcher, admin, and driver roles
- [x] Migration `20260617000004_dispatch_rpcs.sql` contains both functions
- [x] `IncidentService.dispatchIncident()` and `dispatchIncidentManual()` call the RPC via `supabase.rpc()`
- [x] `IncidentService.updateIncidentStatus()` calls `update_incident_status` RPC
- [x] `DispatchException` class with typed error codes for clean UI error handling
- [x] "Dispatch Nearest" button on incident cards (logged status only); shows loading spinner while RPC runs
- [x] On `no_ambulance_available` error: inline red banner + "Manual" fallback button appears
- [x] `ManualDispatchDialog` — lists all ambulances sorted by distance from incident, with status badges, km distance, and per-row "Assign" button
- [x] Assigned ambulance plate shown on dispatched/en_route/arrived cards

### Needs Team Testing
- Log in as Dispatcher. Log a new incident with a map location near Kampala.
- Click "Dispatch Nearest" — confirm it auto-assigns the geographically nearest ambulance (verify in Supabase table: `incidents.assigned_ambulance_id`, `ambulances.status = 'dispatched'`).
- Confirm both records update atomically and the card updates to "DISPATCHED" status without page refresh.
- Set all ambulances to `busy` in the DB, then click "Dispatch Nearest" — confirm the red error banner appears and the "Manual" button appears.
- Click "Manual" — confirm the `ManualDispatchDialog` opens showing all ambulances with status and distance. Pick one and confirm dispatch succeeds.
- Check `incident_events` table in Supabase — confirm an audit row was inserted for each dispatch.

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

*Last updated: 17 June 2026 — Phase 0 and Phase 1 verified complete*
