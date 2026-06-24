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
- [x] **Hospitals tab** (new 4th admin tab): full CRUD — "Add Hospital" / per-row edit dialog (name, address, contact phone, map-pin location reusing the dispatcher's `pickLocation` picker); delete with a dependency guard that blocks (with a clear message) if any ambulances, staff, or incidents still reference that hospital, instead of silently orphaning history
- [x] **Fleet tab — Delete Ambulance**: delete icon + confirmation on each ambulance card, guarded the same way — blocked if any incident still references that ambulance
- [x] `AdminService` / `admin_provider.dart`: added `createHospital`, `updateHospital`, `deleteHospital`, `deleteAmbulance`; converted `adminHospitalsProvider` from a plain `FutureProvider` to a `HospitalsNotifier` (`AsyncNotifierProvider`) so the Fleet tab's and Add User dialog's hospital dropdowns refresh automatically after any hospital CRUD action
- [x] Deliberately **not** built this round (per security/audit-trail review): no hard-delete for Users (deactivation needs an Auth-layer ban via Edge Function, deferred), and no edit/delete for Incidents or Incident Events (both are audit-trail records)

### Needs Team Testing
- Log in as driver demo account, get dispatched to an incident, and confirm the "Navigate to Scene" button appears on the active incident card.
- Tap "Navigate to Scene" — confirm Google Maps opens with the incident location pre-loaded as destination and driving mode selected.
- Log in as admin (`katusiime66+admin@gmail.com`), open Fleet tab — confirm seeded ambulances appear with status badges.
- Tap "Add Ambulance": enter a plate number, assign a driver and hospital, save — confirm the new ambulance appears in the list.
- Tap the edit icon on an existing ambulance, change the assigned driver, save — confirm the change persists after refreshing.
- Open Users tab — confirm all demo accounts are listed. Tap a role badge and change a user's role — confirm it updates in the Supabase `profiles` table.
- Open Analytics tab — confirm total incident count matches the seeded data. Run a full dispatch flow end-to-end and confirm response time appears in the Avg Response KPI card.
- Open the new Hospitals tab — confirm Healthstone and Mulago are listed. Tap "Add Hospital", fill in name/address/phone, pick a location on the map, save — confirm it appears immediately, and that it now also appears in the Fleet tab's and Add User dialog's hospital dropdowns without a page refresh.
- Edit an existing hospital's details and confirm they persist after refresh.
- Try deleting a hospital that has ambulances or staff linked to it — confirm it's blocked with a clear error instead of silently failing or orphaning records. Then try deleting one with no dependents — confirm it's removed.
- In the Fleet tab, try deleting an ambulance that has incident history — confirm it's blocked. Add a fresh test ambulance with no history and delete it — confirm it's removed.
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

---

## Proposal Gap Analysis — Features Not Yet Implemented

*Added 21 June 2026 after cross-referencing the submitted research proposal (Sections 1.3, 1.5, 3.6) with the built codebase. Full details in `ERAMS_TECHNICAL_BUILD_PLAN.md` Section 11.*

---

## Phase 9 — Schema Extensions & Ambulance Marketplace Data [ ] Not started

### Tasks
- [ ] Migration 006: add `patient` role to `profiles.role` constraint + RLS policies
- [ ] Migration 007: add `service_type`, `base_fare`, `price_per_km`, `rating`, `rating_count`, `equipment_notes` columns to `ambulances`
- [ ] Migration 008: create `trips` table with full schema (patient_id, payment_method, payment_status, fare_amount, payment_ref, ratings, offer/accept/decline timestamps)
- [ ] Migration 009: create `messages` table + enable Realtime publication
- [ ] Update ambulance seed data with service types and pricing for 5 demo ambulances
- [ ] Update `lib/models/ambulance.dart` with new marketplace fields
- [ ] Update Admin Fleet tab: service type badge + pricing fields in Add/Edit ambulance form

### Needs Team Testing
- Verify all 4 migrations apply cleanly via `supabase db push`
- Confirm `patient` role login routes correctly (to patient home, once Phase 10 is built)
- Confirm demo ambulances show BLS/ALS/ICU and pricing in admin Fleet tab

---

## Phase 10 — Patient Registration, Login & Home Screen ✓ Complete

### Tasks
- [x] Patient registration form (`AuthService.registerPatient()`) — full name, phone, email, password; upserts `profiles` row with `role = 'patient'`
- [x] GoRouter `/patient` route + redirect for patient role — `UserRole.patient.routePath` returns `/patient`; login screen routes there on success
- [x] `lib/features/patient/patient_home_screen.dart` — map centred on patient GPS; numbered markers (coloured by service type: BLS/ALS/ICU); count chip; marker tap → info card (service type, distance, fare estimate, rating); "Request Ambulance" button; profile icon; sign out
- [x] `lib/services/patient_service.dart` — `fetchNearbyAmbulances(lat, lng)` via `nearby_ambulances` PostGIS RPC; alphabetical fallback
- [x] `lib/state/patient_provider.dart` — `patientLocationProvider` (one-shot GPS fetch), `nearbyAmbulancesProvider` (auto-dispose FutureProvider)
- [x] Web GPS guard — `kIsWeb` branch uses browser geolocation with 8-second timeout; falls back to Kampala centre

### Needs Team Testing
- Register a new patient account (`/patient/register`) and confirm it redirects to `/patient` home screen
- Log in as an existing patient account and confirm the same redirect
- Confirm ambulance markers appear on the map (numbered green pins) centred on the device's GPS location (or Kampala if permission denied)
- Tap a marker — confirm the info card shows plate number, service type badge, distance, fare estimate, and star rating
- Confirm the count chip updates correctly when ambulances are available or not
- Tap "Request Ambulance" — currently navigates to `/patient/request` (Phase 11 screen — expected to 404 until Phase 11 is built)

### Bug Fix — Auth Email Link Routing (Email Confirmation + Password Recovery)
- [x] **Root cause**: Flutter Web defaults to hash-based URL routing, and `go_router` was trying to parse Supabase's `#access_token=...&type=...` auth-link fragment as a navigation target — crashing with `GoException: no routes for location` on both signup-confirmation and password-recovery email links.
- [x] `pubspec.yaml` / `main.dart` — added `flutter_web_plugins` and called `usePathUrlStrategy()` (web only) so the URL fragment is freed up exclusively for Supabase; Firebase Hosting's existing `** → /index.html` rewrite rule means this doesn't break refreshes/direct links
- [x] `auth_service.dart` — `registerPatient()`'s `signUp()` now passes `emailRedirectTo: Uri.base.origin` (web only) so confirmation links point at whatever domain the app is actually running on, instead of depending solely on the Supabase Dashboard's Site URL default
- [x] `app.dart` — router now tracks the most recent `AuthChangeEvent`; when a password-recovery link lands (`AuthChangeEvent.passwordRecovery`), it's redirected to the existing `ForcePasswordChangeScreen` (same screen used for admin-issued temp passwords) instead of silently signing in with no prompt
- **Manual dashboard step (already done)**: Supabase Dashboard → Authentication → URL Configuration — Site URL set to `https://erams-98eb2.web.app`, and that URL added to Redirect URLs

### Needs Team Testing (bug fix)
- Register a brand-new patient account, open the confirmation email, click "Verify Account" — confirm it lands on the live app (not localhost) and doesn't crash, and that you're signed in afterward.
- From the Supabase Dashboard, send a password-recovery email to a test account, click the link — confirm it opens the live app and shows the "Set a New Password" screen instead of a "Page Not Found" crash.
- Confirm normal navigation (login, role dashboards, refreshing on `/admin`, `/dispatcher`, etc.) still works correctly now that URLs are path-based instead of hash-based.

---

## Phase 11 — Ambulance Request Form & Driver Accept/Decline [x] Complete

### Tasks
- [x] `supabase/migrations/20260624000011_patient_request.sql` — adds `incidents.photo_url`, extends status constraint to include `pending_acceptance`, rewrites `dispatch_incident` RPC to accept optional `p_patient_id` (patient path sets `pending_acceptance`; dispatcher path sets `dispatched` immediately), adds `accept_trip` and `decline_trip` RPCs with PostGIS re-offer on decline
- [x] `lib/models/incident.dart` — added `pendingAcceptance` enum value, `photoUrl` field, updated `isActive`, `dbValue`, `label`
- [x] `lib/core/theme/app_colors.dart` — added `statusPending` amber color; `forStatus()` handles `pending_acceptance`
- [x] `lib/widgets/status_badge.dart` — PENDING label for `pending_acceptance`
- [x] `lib/services/driver_service.dart` — `fetchActiveIncident` includes `pending_acceptance`; added `acceptTrip` and `declineTrip` RPCs
- [x] `lib/services/patient_service.dart` — added `createPatientIncident()` (inserts incident, calls `dispatch_incident` with `p_patient_id`) and `fetchActiveTrip()`
- [x] `lib/services/incident_service.dart` — `fetchActiveIncidents` now includes `pending_acceptance` so dispatchers see patient-initiated requests
- [x] `lib/state/driver_provider.dart` — added `acceptOffer()` and `declineOffer()` to `DriverIncidentNotifier`; `declineOffer()` manually refreshes because the Realtime filter no longer fires after reassignment
- [x] `lib/state/patient_provider.dart` — added `patientActiveIncidentProvider` (FutureProvider.autoDispose)
- [x] `lib/features/patient/new_request_form.dart` — emergency type dropdown (10 types), additional notes field, GPS location with "Change Location" button using `pickLocation()`, "Find Nearby Ambulances" CTA navigates to `/patient/pick`
- [x] `lib/features/patient/ambulance_picker_screen.dart` — receives form data via GoRouter `extra`, shows ranked ambulance list with distance/fare/rating/service type, "Select" calls `createPatientIncident`, on success navigates to `/patient` with pending snackbar
- [x] `lib/features/driver/driver_screen.dart` — added `_JobOfferCard` StatefulWidget with 30-second `Timer.periodic` countdown; shows emergency type, patient details, location; Accept calls `acceptOffer()`, Decline (and timer expiry) calls `declineOffer()`
- [x] `lib/app.dart` — added `/patient/request` → `NewRequestFormScreen` and `/patient/pick` → `AmbulancePickerScreen` routes
- [x] `lib/features/patient/patient_home_screen.dart` — watches `patientActiveIncidentProvider`; shows amber/blue banner with status message when trip active; disables "Request Ambulance" button while active trip exists

### Needs Team Testing
- Patient logs in → taps "Request Ambulance" → emergency type dropdown, notes, confirms location (try "Change Location" button too)
- Tap "Find Nearby Ambulances" → ranked list shows with distance, fare, rating
- Tap "Select" → snackbar "Waiting for driver to accept…" appears; Request button becomes disabled; amber banner appears on home screen
- On driver screen, `_JobOfferCard` appears with 30-second countdown ring; driver accepts → both sides advance to `dispatched`
- Driver declines (or countdown expires) → next available driver is offered; if none, incident resets to `logged`
- Dispatcher dashboard now shows patient-initiated `pending_acceptance` incidents in the active list

---

## Phase 12 — Live Trip Tracking (Patient Side) [x] Complete

### Tasks
- [x] `lib/models/trip.dart` — Trip model (maps trips table: id, incident_id, ambulance_id, driver_id, status, fares, timestamps)
- [x] `lib/services/patient_service.dart` — `fetchTripWithDriver(incidentId)` joins trip row with driver's full_name/phone from profiles
- [x] `lib/state/patient_provider.dart` — `ActiveIncidentNotifier` (FamilyAsyncNotifier) with Realtime subscription on incidents by id; `TrackingAmbulanceNotifier` (FamilyAsyncNotifier) with Realtime subscription on ambulances by id; `tripWithDriverProvider` (FutureProvider.family.autoDispose)
- [x] `lib/features/patient/trip_tracking_screen.dart` — full-screen flutter_map with patient blue marker + moving ambulance marker + dashed polyline; status banner (colour-coded by incident status); bottom card showing plate, service type, ETA, distance, driver name, "Call" button, fare; on `completed` → completion dialog (duration, fare, payment method, Done button); on `cancelled` → snackbar + navigate to `/patient`; re-centre FAB; invalidates `tripWithDriverProvider` when driver accepts (to show driver name)
- [x] `lib/app.dart` — `/patient/tracking/:incidentId` route added
- [x] `lib/features/patient/ambulance_picker_screen.dart` — after `createPatientIncident`, navigates directly to `/patient/tracking/:incidentId` (bypasses home screen)
- [x] `lib/features/patient/patient_home_screen.dart` — active trip banner is now tappable → pushes to `/patient/tracking/:incidentId`

### Needs Team Testing
- Select ambulance → immediately lands on tracking screen (not home screen)
- Status banner shows correct colour and message for each status (pending, dispatched, en_route, arrived)
- Driver marker appears on map once ambulance has a GPS location; marker moves as driver pushes updates every 15 s
- ETA and distance update as ambulance moves
- When driver accepts, driver name and "Call" button appear in the bottom card
- Tap "Call" → phone dialler opens with driver's number
- Active trip banner on home screen is tappable → opens tracking screen
- Driver advances status to "Incident Complete" → completion dialog appears automatically with duration and fare; tap "Done" → returns to home screen with no active-trip banner

---

## Phase 13 — In-App Text Messaging [x] Complete

### Tasks
- [x] `supabase/migrations/20260624000013_messages.sql` — `messages` table with `incident_id`, `sender_id`, `sender_role`, `sender_name`, `body`, `created_at`; BEFORE INSERT trigger populates `sender_role`/`sender_name` from profiles (prevents spoofing); RLS: dispatchers/admins see all; patients see their own incident's messages; drivers see messages on their active incidents; Realtime publication added
- [x] `lib/models/chat_message.dart` — `ChatMessage` model with `isMe(userId)` helper
- [x] `lib/services/message_service.dart` — `streamMessages(incidentId)` (Supabase `.stream()`) + `sendMessage(incidentId, body)`
- [x] `lib/state/message_provider.dart` — `messagesProvider(incidentId)` StreamProvider.family.autoDispose; `chatSeenProvider` StateNotifierProvider tracking per-incident seen count for unread badge
- [x] `lib/widgets/chat_sheet.dart` — `ChatSheet` (DraggableScrollableSheet): message bubbles (mine right/red, theirs left/grey), sender name + role tag on others' messages, timestamps, auto-scroll on new messages, marks seen while open; `showChatSheet(context, incidentId)` helper; `chatIconWithBadge(unread)` reusable badge icon
- [x] `lib/features/patient/trip_tracking_screen.dart` — chat FAB added above re-center FAB; watches `messagesProvider` + `chatSeenProvider` for live unread badge
- [x] `lib/features/driver/driver_screen.dart` — "Chat (N new)" `OutlinedButton.icon` added to `_ActiveIncidentCard` between Navigate and Advance buttons; unread count shown in label
- [x] `lib/features/dispatcher/dispatcher_dashboard.dart` — chat icon button with badge added to `_IncidentCard` Row 1 (next to ℹ️ info button); `messagesProvider` watched per card for live unread count

### Needs Team Testing
- Patient sends message → driver sees it in real time (no refresh needed)
- Driver replies → patient sees it instantly on tracking screen (badge on FAB)
- Dispatcher opens chat → sees all messages from patient and driver
- Unread badge increments on all sides when messages arrive while chat is closed
- Opening chat resets badge to 0 on that screen
- Messages persist after page refresh (stored in Supabase)

---

## Phase 14 — Mobile Money Payment (Flutterwave) [ ] Not started

### Tasks
- [ ] Add Flutterwave Flutter SDK to `pubspec.yaml`
- [ ] Payment bottom sheet in ambulance picker: fare breakdown + payment method selector
- [ ] MTN MoMo + Airtel Money flow via Flutterwave charge API
- [ ] Card payment via Flutterwave inline checkout WebView
- [ ] Cash flow: mark `payment_method = 'cash'`, proceed immediately
- [ ] Edge Function `flutterwave_webhook`: verify signature → update `trips.payment_status` → trigger dispatch
- [ ] Cash: driver confirms `cash_received` at completion
- [ ] Admin Patients tab: payment method badge + status on each record

### Needs Team Testing
- MTN MoMo payment flow completes → driver receives job offer
- Airtel Money payment flow completes
- Cash selection bypasses payment → driver notified immediately
- Failed payment → patient sees clear error, can retry
- Admin sees Paid / Cash / Pending / Failed status on each patient record

---

## Phase 15 — Ratings System [x] Complete

### Tasks
- [x] `supabase/migrations/20260624000012_rating_trigger.sql` — adds `patient_rating` / `patient_comment` columns to trips; `update_ambulance_rating_fn()` trigger recalculates `ambulances.rating` + `rating_count` on every rating update; `sync_trips_on_incident_close()` trigger mirrors incident completion/cancellation into the trips table; RLS policy allowing patients to update their own completed trip's rating
- [x] `PatientService.submitRating(tripId, rating, comment?)` — UPDATE trips SET patient_rating + patient_comment
- [x] `lib/features/patient/trip_rating_screen.dart` — interactive 5-star row, optional comment field, Submit (disabled until star selected) + Skip buttons; navigates to `/patient` on either action; invalidates `patientActiveIncidentProvider`
- [x] `lib/features/patient/trip_tracking_screen.dart` — completion dialog's single "Done" button replaced with "Skip" (→ `/patient`) + "Rate Experience" (→ `/patient/rating` with `{tripId, ambulancePlate, driverName}` via route extra)
- [x] `lib/app.dart` — `/patient/rating` route added (reads extra Map for tripId, ambulancePlate, driverName)
- [x] Ambulance cards in patient home + picker already showed `★ X.X` rating chips (built in Phase 9); no changes needed
- [x] Admin Fleet tab already showed rating inline on ambulance cards (built in Phase 9); no changes needed

### Needs Team Testing
- Rating screen appears automatically after dispatcher marks trip completed
- Selecting 1–5 stars enables Submit; submitting navigates to `/patient` home
- Skipping navigates directly to `/patient` without recording a rating
- Submitting a rating → ambulance's star average updates immediately in patient home + picker cards (after refresh)
- Admin Fleet tab shows updated rating count on ambulance card

---

## Phase 16 — SMS Notifications (Africa's Talking) [ ] Not started

### Tasks
- [ ] Africa's Talking account setup; `AT_API_KEY` + `AT_USERNAME` in Edge Function secrets
- [ ] Edge Function `send_sms` shared helper
- [ ] SMS on driver job offer, patient driver-accepted, patient driver-arrived, hospital incoming patient
- [ ] Phone number validation (+256 format) on patient registration
- [ ] Graceful failure logging to `incident_events`

### Needs Team Testing
- Close the driver app; trigger a dispatch → driver receives SMS within 30 seconds
- Patient receives SMS when driver accepts
- Hospital staff receives SMS when patient is dispatched to their hospital
- Invalid phone number rejected at registration

---

## Phase 17 — DHIS2 Export & Analytics Enhancements [x] Complete

### Tasks
- [x] Edge Function `export_to_dhis2` — aggregate completed incidents → DHIS2 Data Value Sets API; accepts date range + DHIS2 credentials in request body
- [x] "Export to DHIS2" button in Admin Analytics tab + date-range/credentials dialog
- [x] "Download Report" CSV button — fetches all incidents, builds RFC-4180 CSV, copy-to-clipboard
- [x] Fleet utilisation donut chart — `fl_chart` `PieChart` with ambulance status breakdown + legend
- [x] Calls today + completion rate KPI cards (4 KPI cards total in Analytics tab)
- [x] Response time per call bar chart (last 10 calls, oldest-to-newest, minutes)
- [x] Calls by emergency type bar chart (top 8 types, sorted by count)
- [x] `AdminAnalytics` extended with 5 new fields: `callsToday`, `completionRate`, `countByEmergencyType`, `recentResponseTimes`, `fleetStatusCounts`

### Needs Team Testing
- Export to DHIS2 succeeds with valid DHIS2 credentials (or shows clear error with invalid ones)
- CSV copy-to-clipboard delivers correct RFC-4180 data; paste into Excel/Sheets renders correctly
- Analytics tab shows all 4 KPI cards, fleet donut, 5 charts, status breakdown table
- Fleet donut colours match ambulance status colours used elsewhere in the app

---

## Phase 18 — Voice & Video Calls (Agora) [ ] Not started

### Tasks
- [ ] Agora project setup; `AGORA_APP_ID` in `.env` and Edge Function secrets
- [ ] Edge Function `generate_agora_token`
- [ ] `lib/widgets/call_screen.dart` — full call UI (video feed, mute, camera, speaker, end)
- [ ] Voice + video call buttons on patient tracking screen and driver incident card
- [ ] Android permissions: `RECORD_AUDIO`, `CAMERA` in AndroidManifest.xml
- [ ] Web browser permission prompts

### Needs Team Testing
- Patient initiates voice call → driver receives it and can accept
- Both sides can hear each other
- Video call shows both camera feeds
- Call ends cleanly and returns to trip tracking screen
- Works on Android physical device + Chrome web

---

## Phase 19 — Final Validation, Diagrams & Full Report Prep [ ] Not started

### Tasks
- [ ] DFD Level 0 (Context Diagram) — saved to `docs/diagrams/dfd_level0.svg`
- [ ] DFD Level 1 (System Diagram) — saved to `docs/diagrams/dfd_level1.svg`
- [ ] UML Use Case Diagram (all 5 roles) — saved to `docs/diagrams/use_case.svg`
- [ ] UML Sequence Diagrams: patient booking flow, payment flow, dispatcher flow — saved to `docs/diagrams/`
- [ ] Update `EVALUATION_FORM.md`: add Section G for patient experience
- [ ] Full smoke test: patient registers → requests → pays → driver accepts → tracks → completes → rates
- [ ] Update README with Phase 9–19 setup instructions (Flutterwave, Agora, Africa's Talking)
- [ ] Tag release `v2.0-complete`

---

### Critical Gap — Patient Portal (entire module missing)

The prototype's primary innovation is a **patient-initiated, ride-hailing ambulance request flow** (like SafeBoda / Faras). This is entirely absent from the current system. The current system is dispatcher-initiated only — patients must phone in and a dispatcher logs on their behalf. The prototype shows:

1. Patient logs in → sees live map of nearby ambulances with pricing, ratings, service type
2. Patient fills in emergency details + optional photo
3. Patient selects preferred ambulance
4. Patient pays via mobile money (MTN MoMo / Airtel Money) or cash
5. Driver **accepts** the job (not silently assigned)
6. Patient tracks driver live on map
7. Patient and driver communicate via in-app text/voice/video
8. Patient rates the ambulance after completion

| Gap | Status | Notes |
| --- | --- | --- |
| **Patient role + registration/login** | `[ ]` Not started | Needs new role in `profiles`, RLS policies, GoRouter route |
| **Ambulance marketplace** (pricing, ratings, service type) | `[ ]` Not started | Needs schema columns added to `ambulances` table |
| **Patient request form** (location, emergency type, photo) | `[ ]` Not started | New `lib/features/patient/` module |
| **Nearby ambulances map view** | `[ ]` Not started | Patient sees live ambulance markers with cards |
| **Driver accept / decline job** | `[ ]` Not started | Replaces silent assignment; 30-second countdown |
| **Live trip tracking for patient** | `[ ]` Not started | Patient watches driver approach on map |
| **In-app messaging** (patient ↔ driver) | `[ ]` Not started | New `messages` table + chat UI on both sides |
| **In-app voice/video call** | `[ ]` Not started | Requires WebRTC/Agora SDK |
| **Mobile money payment** | `[ ]` Not started | Flutterwave SDK (MTN MoMo + Airtel Money) |
| **Post-trip rating system** | `[ ]` Not started | 1–5 stars; updates `ambulances.rating` |
| **Dispatcher ↔ driver messaging** | `[ ]` Not started | Shares same messages infra |
| **SMS fallback notifications** | `[ ]` Not started | Africa's Talking Edge Function |
| **DHIS2 export** (shown in prototype Insights tab) | `[ ]` Not started | "Export to DHIS2" button in Admin Analytics |

Full implementation plan for the patient portal is in `ERAMS_TECHNICAL_BUILD_PLAN.md` **Phase 9** and **Section 11.2**.

These are **not blockers for the v1.0-demo of the dispatcher/driver/hospital/admin system** but represent the primary patient-facing feature the system is ultimately meant to deliver. They should be documented as planned Phase 9 work in the final report (Chapter 5).

---

---

## Admin Dashboard — Patients Tab ✓ Added

- [x] **Patients tab** (5th tab in admin dashboard): full searchable list of every incident in the system, showing patient name, phone, nature of emergency, incident location, ambulance dispatched (plate number), hospital taken to, incident status badge, logged time, and calculated response time (created_at → arrived_at)
- [x] `PatientRecord` model class in `admin_service.dart` — joined query: `incidents.*` + `ambulances(plate_number)` + `hospitals(name)`, ordered newest first
- [x] `fetchAllPatientRecords()` in `AdminService`
- [x] `patientRecordsProvider` in `admin_provider.dart`
- [x] `_PatientsTab` + `_PatientRecordCard` + `_DetailRow` in `admin_screen.dart`
- [x] Live search/filter by patient name, phone, emergency type, ambulance plate, hospital, location
- [x] Pull-to-refresh

### Needs Team Testing
- Log in as admin, open the Patients tab — confirm all logged incidents appear, newest first.
- Each card should show: patient name/phone, emergency type, location, ambulance plate (or "No ambulance assigned"), hospital name (or "No hospital assigned"), status badge, logged time, response time (if arrived).
- Run a full dispatch cycle, confirm the record updates (refresh to see latest status).
- Type in the search box — confirm filtering works across all fields.

---

*Last updated: 21 June 2026 — Patients tab added to admin dashboard; Phases 0–8 code complete; remaining items are team actions (deploy, screenshots, tag v1.0-demo)*
