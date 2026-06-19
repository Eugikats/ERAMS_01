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

## Phase 6 — Admin Module: Fleet & Analytics ✓ Complete

### Tasks
- [x] **Navigate to Scene** button on driver active incident card — opens Google Maps with incident location pre-loaded as destination, driving mode selected; only renders when incident has a pinned location (`latitude != null`)
- [x] **Fleet tab**: list all ambulances with status badges, assigned driver, and home hospital; "Add Ambulance" form (plate number, driver, hospital); edit existing ambulances including clearing driver/hospital assignments
- [x] **Users tab**: list all profiles with role badges; tap role badge to change role via simple dialog; admin cannot change their own role (guard via UI)
- [x] **Analytics tab**: KPI cards (total incidents, avg response time created_at→arrived_at); horizontal bar chart for incidents by status; horizontal bar chart for incidents by hospital; status breakdown with progress bars; pull-to-refresh
- [x] `AdminService`: `fetchAllAmbulances`, `createAmbulance`, `updateAmbulance`, `fetchAllProfiles`, `updateProfileRole`, `updateProfileHospital`, `fetchAllHospitals`, `fetchAnalytics` → `AdminAnalytics`
- [x] `admin_provider.dart`: `FleetNotifier`, `ProfilesNotifier`, `adminHospitalsProvider`, `analyticsProvider`
- [x] Wire `/admin` route to `AdminScreen` (replaces placeholder); removed unused `_RolePlaceholderScreen`
- [x] **Users tab — Create User**: "Add User" dialog (email, full name, phone, role, hospital if role=hospital); calls new `admin_create_user` Edge Function which uses the service-role key to create the `auth.users` row (never exposed to the Flutter client) and returns an auto-generated temporary password shown once in a copyable dialog
- [x] **Users tab — Edit Details**: overflow menu (⋮) on each user card → "Edit Details" dialog for full name + phone (role/hospital still changed via the existing role chip)
- [x] **Users tab — Reset Password**: overflow menu → "Reset Password" with confirmation, calls new `admin_reset_password` Edge Function, shows the new temporary password once
- [x] **Forced password change flow**: accounts created or reset get `must_change_password: true` in Supabase Auth user metadata; `ForcePasswordChangeScreen` (`/force-password-change`) intercepts login (and app reloads, via a `go_router` redirect guard in `app.dart`) until the user sets their own password, then clears the flag and continues to their role dashboard
- [x] Migration `20260620000005_profiles_email.sql` — adds `profiles.email` (backfilled from `auth.users`, kept in sync by the auth trigger going forward) so the admin Users screen can show/identify accounts without needing Admin API access from the client
- [x] New Edge Functions `supabase/functions/admin_create_user` and `supabase/functions/admin_reset_password` (Deno/TS), both gated by a shared `_shared/adminAuth.ts` check that the caller's `profiles.role = 'admin'`

### Needs Team Testing
- Log in as driver demo account, get dispatched to an incident, and confirm the "Navigate to Scene" button appears on the active incident card.
- Tap "Navigate to Scene" — confirm Google Maps opens with the incident location pre-loaded as destination and driving mode selected.
- Log in as admin (`katusiime66+admin@gmail.com`), open Fleet tab — confirm seeded ambulances appear with status badges.
- Tap "Add Ambulance": enter a plate number, assign a driver and hospital, save — confirm the new ambulance appears in the list.
- Tap the edit icon on an existing ambulance, change the assigned driver, save — confirm the change persists after refreshing.
- Open Users tab — confirm all demo accounts are listed. Tap a role badge and change a user's role — confirm it updates in the Supabase `profiles` table.
- Open Analytics tab — confirm total incident count matches the seeded data. Run a full dispatch flow end-to-end and confirm response time appears in the Avg Response KPI card.
- **Before testing Create User / Reset Password**: run `supabase db push` (migration 005) and `supabase functions deploy admin_create_user` + `supabase functions deploy admin_reset_password`.
- Tap "Add User", fill in a new account, submit — confirm a temporary password dialog appears and the user shows up in the list immediately.
- Sign in as that new user with the temp password — confirm you land on "Set a New Password" before reaching their dashboard; set a password and confirm you land on the correct role dashboard afterward.
- On an existing user, open the ⋮ menu → "Edit Details" — change name/phone, save, confirm it persists after refresh.
- On an existing user, open the ⋮ menu → "Reset Password", confirm, then sign in as that user with the new temp password — confirm the forced password-change screen appears again.

---

## Phase 7 — Polish, History, Profiles & Deployment ✓ Complete

### Tasks

#### Dashboard robustness (all roles)
- [x] **Profile view** (all roles): bottom sheet shows full name, role badge, phone, member-since date; allows editing full name and phone; invalidates `currentProfileProvider` so app bar refreshes — `lib/widgets/profile_edit_sheet.dart`, `lib/services/profile_service.dart`
- [x] **Dispatcher — incident history tab**: "History" tab added to Dispatcher dashboard; completed + cancelled incidents, last 30 days, searchable by nature of emergency or location; response time shown per card
- [x] **Hospital — patient history tab**: "History" tab added to Hospital screen; completed + cancelled incidents assigned to the hospital, last 30 days, searchable
- [x] **Driver — trip history tab**: "History" tab added to Driver screen; completed + cancelled incidents for the driver's ambulance, last 30 days, searchable
- [x] **GPS web guard**: `GpsNotifier.startTracking()` returns early if `kIsWeb` — prevents `geolocator` crash on Flutter web build
- [x] **Profile icon** added to app bar of all four role screens (Dispatcher, Driver, Hospital, Admin)
- [x] Responsive layout: Dispatcher already uses `LayoutBuilder` 800px breakpoint; Admin uses full-width `DefaultTabController`; Driver/Hospital are single-column mobile-first
- [x] Offline-first: GPS location failures queue and retry on next 15s tick (implemented in Phase 4); Supabase Realtime auto-reconnects; no further changes needed for MVP
- [ ] Build and deploy Flutter web to Firebase Hosting — **team action**: push to `main` triggers GitHub Actions `firebase-hosting-merge.yml` automatically
- [ ] Build Android APK — **team action**: run `flutter build apk --release --dart-define-from-file=.env.json` locally, then install on driver device
- [ ] Smoke-test full end-to-end flow — **team action**: run through the full dispatch cycle on the deployed app

### Needs Team Testing
- Open the deployed Firebase Hosting URL in a desktop browser — confirm Dispatcher view is usable.
- Open the same URL on a mobile browser — confirm it doesn't break.
- Tap the profile icon (person outline) in any role's app bar — confirm the profile sheet opens with correct name, role badge, and phone. Edit the name, save, confirm the sheet updates and closes.
- Log in as Dispatcher, open the History tab — confirm completed incidents appear (run a full dispatch flow first if the DB is empty). Search for a term — confirm filtering works.
- Log in as Hospital staff, open History tab — confirm only that hospital's incidents appear.
- Log in as Driver, open History tab — confirm only trips for that driver's ambulance appear.
- Install the Android APK on a physical device. Confirm the GPS toggle starts location updates (check the ambulance row in Supabase — `current_location` should update every ~15s).
- Full smoke test: dispatcher logs → auto-assign → driver alert → live location → hospital ETA → status complete → admin analytics updated.

---

## Phase 8 — Validation, Documentation & Demo Prep ✓ Code Complete

### Tasks
- [x] **Evaluation form** — `docs/EVALUATION_FORM.md`: structured questionnaire with 6 sections covering ease of use (A), dispatch speed/automation (B), GPS accuracy/driver experience (C), hospital communication (D), performance/reliability (E), and overall assessment (F); mirrors original proposal Section F questionnaire
- [x] **README updated** — final setup/deployment instructions, ASCII architecture diagram, ERD summary, key design decisions table, known limitations, all 8 build phases, demo credentials, Android APK build command
- [ ] **Screenshots/screen recordings** — **team action**: capture each role's golden path (login → main flow → history tab) for the final report and oral defense slides
- [ ] **Tag `v1.0-demo`** — **team action**: `git tag v1.0-demo && git push origin v1.0-demo`
- [ ] **Firebase deploy** — **team action**: push to `main` (CI auto-deploys); update README with live URL once available

### Needs Team Testing
- Print `docs/EVALUATION_FORM.md` or share as PDF; run informal walkthroughs with at least one person per role.
- Record a screen capture of the full dispatch flow: dispatcher logs → auto-assign → driver En Route → hospital ETA → Completed → admin analytics. Use this for the oral defense.
- Confirm the live Firebase Hosting URL works on both desktop and mobile browsers before the defense.

---

*Last updated: 18 June 2026 — Phases 0–8 code complete; remaining items are team actions (deploy, screenshots, tag v1.0-demo)*
