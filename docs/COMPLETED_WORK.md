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
- [✓] "New Incident" form: location pin drop on map (`LocationPickerDialog`), nature of emergency dropdown (10 types), patient notes, hospital selector
- [✓] Map widget (`_MapPanel`): incident markers (red/tappable), ambulance markers (colour-coded by status with tooltip), hospital markers (blue), map legend overlay
- [✓] Wire incident creation to `incidents` table via `IncidentService.createIncident()`
- [✓] Dispatcher Dashboard (`DispatcherDashboard`): active incident cards with status badges, filterable by status (All / Logged / Dispatched / En Route / Arrived), responsive two-panel layout (>= 800px) or tabbed layout (< 800px)
- [✓] Realtime subscription for `incidents` and `ambulances` — live updates via `IncidentsNotifier` and `AmbulancesNotifier` (Supabase Realtime → re-fetch on change)

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
- [✓] Postgres function `dispatch_incident(p_incident_id, p_ambulance_id DEFAULT NULL)` — auto picks nearest available ambulance via PostGIS ST_Distance; accepts optional manual ambulance override; `SECURITY DEFINER`, atomic transaction, GRANT to authenticated
- [✓] Postgres function `update_incident_status(p_incident_id, p_new_status)` — transitions incident lifecycle, syncs ambulance status, writes incident_events audit row; callable by dispatcher, admin, and driver roles
- [✓] Migration `20260617000004_dispatch_rpcs.sql` contains both functions
- [✓] `IncidentService.dispatchIncident()` and `dispatchIncidentManual()` call the RPC via `supabase.rpc()`
- [✓] `IncidentService.updateIncidentStatus()` calls `update_incident_status` RPC
- [✓] `DispatchException` class with typed error codes for clean UI error handling
- [✓] "Dispatch Nearest" button on incident cards (logged status only); shows loading spinner while RPC runs
- [✓] On `no_ambulance_available` error: inline red banner + "Manual" fallback button appears
- [✓] `ManualDispatchDialog` — lists all ambulances sorted by distance from incident, with status badges, km distance, and per-row "Assign" button
- [✓] Assigned ambulance plate shown on dispatched/en_route/arrived cards

### Needs Team Testing
- Log in as Dispatcher. Log a new incident with a map location near Kampala.
- Click "Dispatch Nearest" — confirm it auto-assigns the geographically nearest ambulance (verify in Supabase table: `incidents.assigned_ambulance_id`, `ambulances.status = 'dispatched'`).
- Confirm both records update atomically and the card updates to "DISPATCHED" status without page refresh.
- Set all ambulances to `busy` in the DB, then click "Dispatch Nearest" — confirm the red error banner appears and the "Manual" button appears.
- Click "Manual" — confirm the `ManualDispatchDialog` opens showing all ambulances with status and distance. Pick one and confirm dispatch succeeds.
- Check `incident_events` table in Supabase — confirm an audit row was inserted for each dispatch.

---

## Phase 4 — Driver Module (Mobile) ✓ Complete

### Tasks
- [x] Driver home screen (`DriverScreen`): ambulance header card, GPS on/off indicator, status toggle (Available / Busy / Offline), active incident card or "Standing by" state
- [x] Realtime subscription filtered to driver's `assigned_ambulance_id` on `incidents` table — driver sees alert instantly when dispatched
- [x] GPS location stream via `Geolocator.getPositionStream()`, uploads to `ambulances.current_location` every 15 seconds; auto-starts on screen load, stops when driver goes offline
- [x] Status transition buttons: "I'm En Route" → "I've Arrived" → "Incident Complete" (calls `update_incident_status` RPC)
- [x] Offline queue: failed location pushes are queued in memory and flushed on next successful upload
- [x] `DriverService` — `fetchMyAmbulance`, `fetchActiveIncident`, `fetchHospital`, `setAmbulanceStatus`, `pushLocation`, `updateIncidentStatus`
- [x] `driver_provider.dart` — `DriverAmbulanceNotifier`, `DriverIncidentNotifier`, `GpsNotifier`, `hospitalByIdProvider`

### Needs Team Testing
- Log in as the driver demo account (`katusiime66+driver@gmail.com`).
- Confirm the screen shows "UBE 001A" header and GPS auto-starts (green GPS indicator).
- On a separate Dispatcher session, dispatch an incident to UBE 001A.
- Confirm the driver screen immediately shows the incident card (Realtime alert, no refresh).
- Tap "I'm En Route" — confirm the Dispatcher's card updates to "EN ROUTE" and ambulance marker colour changes.
- Tap "I've Arrived" then "Incident Complete" — confirm the incident disappears from the dispatcher list and ambulance returns to Available.
- Confirm ambulance GPS position updates on the Dispatcher map every ~2 seconds while driving.
- Toggle driver to "Offline" — confirm GPS stops (indicator turns grey).

---

## Phase 5 — Hospital Module & Notifications ✓ Complete

### Tasks
- [x] Hospital screen (`HospitalScreen`): hospital name header, incoming patient count, list of active incidents assigned to the user's hospital
- [x] Incident card: nature of emergency, status badge, caller info, location description, ambulance plate + status, live ETA to hospital (Haversine distance ÷ 40 km/h), patient condition notes
- [x] Realtime subscription on `incidents` filtered by `assigned_hospital_id` — new assignments appear instantly
- [x] Realtime subscription on `ambulances` — ETA updates live as driver pushes GPS position
- [x] "Acknowledge — Ready to Receive" button writes `incident_events` row (`event_type = 'message'`, typed payload); button becomes a disabled "Acknowledged" confirmation after tap
- [x] Acknowledge state loaded from DB on startup (`fetchAcknowledgedIncidentIds` queries `incident_events`) — survives page refresh; optimistic local update keeps button disabled immediately after tap
- [x] `HospitalService` — `fetchMyHospital`, `fetchAssignedIncidents`, `fetchAllAmbulances`, `acknowledgeIncident`
- [x] `hospital_provider.dart` — `myHospitalProvider`, `HospitalIncidentsNotifier`, `HospitalAmbulancesNotifier`, `acknowledgedIncidentsProvider`

### Needs Team Testing
- Log in as `katusiime66+hospital@gmail.com` (Mulago Hospital account).
- Confirm the screen shows "Mulago National Referral Hospital" header.
- From a Dispatcher tab, log a new incident and assign it to Mulago — confirm the card appears on the hospital screen without refreshing.
- Confirm the ambulance plate, status, and ETA update live as the driver pushes GPS.
- Click "Acknowledge" — confirm button changes to green "Acknowledged" and an entry appears in `incident_events` in Supabase (event_type = 'message', payload contains 'hospital_acknowledged').
- Complete the incident from the driver side — confirm the card disappears from the hospital view.

---

## Phase 6 — Admin Module: Fleet & Analytics (Target: 26–27 Jun 2026)

### Tasks
- [x] **Navigate to Scene** button on driver active incident card — opens Google Maps with incident location pre-loaded as destination, driving mode selected; only renders when incident has a pinned location (`latitude != null`)
- [ ] Admin screens: manage `profiles` (assign roles), manage `ambulances` (add/edit/assign driver)
- [ ] Basic analytics: average response time (created_at → arrived_at), incident counts by status, incidents by hospital

### Needs Team Testing
- Log in as driver demo account, get dispatched to an incident, and confirm the "Navigate to Scene" button appears on the active incident card.
- Tap "Navigate to Scene" — confirm Google Maps opens with the incident location pre-loaded as destination and driving mode selected.
- Log in as admin, create a new ambulance record and assign it to a driver.
- Create a new user and assign them the "dispatcher" role.
- Confirm the analytics dashboard shows correct counts from seeded/test incident data.
- Run a full incident flow end-to-end and confirm response time appears in analytics.

---

## Phase 7 — Polish, History, Profiles & Deployment (Target: 27–29 Jun 2026)

### Tasks

#### Dashboard robustness (all roles)
- [ ] **Profile view** (all roles): show full name, role, phone; allow editing full name and phone
- [ ] **Dispatcher — incident history tab**: completed + cancelled incidents, last 30 days, searchable by nature of emergency
- [ ] **Hospital — patient history tab**: completed incidents assigned to this hospital, last 30 days
- [ ] **Driver — trip history tab**: completed incidents assigned to this driver's ambulance

#### Polish & deployment
- [ ] Responsive layout pass: Dispatcher/Admin on desktop widths; Driver/Hospital on mobile
- [ ] GPS tracking: guard `Geolocator` calls behind a web-safe check so the driver screen doesn't throw on Flutter web (GPS only active on Android)
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
- Verify history tabs show past incidents correctly for each role.
- Verify profile view shows correct data and edits persist.

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

*Last updated: 18 June 2026 — Phases 0–3 verified; Phases 4–5 built (Phase 5 acknowledge bug fixed); Phase 6 started (Navigate to Scene button); Phase 7 plan updated with history + profile features*
