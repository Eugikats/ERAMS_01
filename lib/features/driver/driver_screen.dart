import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ambulance.dart';
import '../../models/hospital.dart';
import '../../models/incident.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../state/auth_provider.dart';
import '../../state/dispatcher_provider.dart';
import '../../state/driver_provider.dart';
import '../../state/message_provider.dart';
import '../../state/routing_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/call_screen.dart';
import '../../widgets/chat_list_view.dart';
import '../../widgets/chat_sheet.dart';
import '../../widgets/incident_history_list.dart';
import '../../widgets/profile_edit_sheet.dart';
import '../../widgets/status_badge.dart';

class DriverScreen extends ConsumerStatefulWidget {
  const DriverScreen({super.key});

  @override
  ConsumerState<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends ConsumerState<DriverScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _historyRows = [];
  bool _historyLoading = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 2 && _historyRows.isEmpty) {
        _loadHistory();
      }
    });
    // Auto-start GPS once the ambulance data is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartGps());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _maybeStartGps() async {
    final ambulance = await ref.read(driverAmbulanceProvider.future);
    if (!mounted) return;
    if (ambulance != null && ambulance.status != AmbulanceStatus.offline) {
      await _startGpsWithFeedback();
    }
  }

  /// Starts location streaming and, if it can't, tells the driver why so they
  /// can fix it (turn on location services, grant browser permission, etc.).
  Future<void> _startGpsWithFeedback() async {
    final result =
        await ref.read(gpsNotifierProvider.notifier).startTracking();
    if (!mounted) return;
    final message = switch (result) {
      GpsStartResult.started || GpsStartResult.alreadyRunning => null,
      GpsStartResult.serviceDisabled =>
        'Location services are off. Turn them on to share your position.',
      GpsStartResult.permissionDenied =>
        'Location permission denied. Allow location access to go live on the map.',
      GpsStartResult.permissionDeniedForever =>
        'Location is blocked for this site. Enable it in your browser settings, then tap GPS again.',
    };
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// Manual GPS badge toggle: stop sharing if live, otherwise (re)start it.
  Future<void> _toggleGps(bool currentlyActive) async {
    if (currentlyActive) {
      ref.read(gpsNotifierProvider.notifier).stopTracking();
    } else {
      await _startGpsWithFeedback();
    }
  }

  Future<void> _loadHistory() async {
    final ambulanceId =
        ref.read(driverAmbulanceProvider).valueOrNull?.id;
    if (ambulanceId == null) return;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final rows =
          await ProfileService().fetchDriverHistory(ambulanceId);
      if (mounted) setState(() => _historyRows = rows);
    } catch (e) {
      if (mounted) setState(() => _historyError = e.toString());
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ambulanceAsync = ref.watch(driverAmbulanceProvider);
    final incidentAsync = ref.watch(driverIncidentProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final gpsActive = ref.watch(gpsActiveProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const AppLogoHorizontal(),
        actions: [
          IconButton(
            tooltip: 'My profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => showProfileSheet(context),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              ref.read(gpsNotifierProvider.notifier).stopTracking();
              await AuthService().signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.airport_shuttle_outlined), text: 'Active'),
            Tab(icon: Icon(Icons.forum_outlined), text: 'Chats'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Active tab ────────────────────────────────────────
          ambulanceAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
        data: (ambulance) {
          if (ambulance == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No ambulance is linked to your account.\n'
                  'Contact the administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 15),
                ),
              ),
            );
          }

          final allIncidents =
              ref.watch(incidentsNotifierProvider).valueOrNull ?? [];
          final activeIncidents = allIncidents
              .where((i) => i.status.isActive)
              .toList();

          return Column(
            children: [
              // ── Top half: live map ──────────────────────────────
              Expanded(
                flex: 1,
                child: _DriverLiveMap(
                  ambulance: ambulance,
                  incidents: activeIncidents,
                  assignedIncident: incidentAsync.valueOrNull,
                ),
              ),
              // ── Bottom half: header + card ──────────────────────
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AmbulanceHeader(
                        ambulance: ambulance,
                        driverName: profile?.fullName ?? '',
                        gpsActive: gpsActive,
                        onToggleGps: () => _toggleGps(gpsActive),
                      ),
                      const SizedBox(height: 12),
                      _StatusToggle(
                        current: ambulance.status,
                        hasActiveJob: incidentAsync.valueOrNull != null,
                        onChanged: (newStatus) async {
                          await ref
                              .read(driverAmbulanceProvider.notifier)
                              .setStatus(newStatus);
                          if (newStatus == 'offline') {
                            ref
                                .read(gpsNotifierProvider.notifier)
                                .stopTracking();
                          } else if (!ref.read(gpsActiveProvider)) {
                            await _startGpsWithFeedback();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      incidentAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (e, _) => Text(
                          'Error loading incident: $e',
                          style: const TextStyle(color: AppColors.error),
                        ),
                        data: (incident) {
                          if (incident == null) {
                            return const _StandingByCard();
                          }
                          if (incident.status ==
                              IncidentStatus.pendingAcceptance) {
                            return _JobOfferCard(incident: incident);
                          }
                          return _ActiveIncidentCard(incident: incident);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
          // ── Chats tab ─────────────────────────────────────────
          const ChatListView(),
          // ── History tab ───────────────────────────────────────
          IncidentHistoryList(
            rows: _historyRows,
            isLoading: _historyLoading,
            error: _historyError,
            onRefresh: _loadHistory,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ambulance header
// ---------------------------------------------------------------------------

class _AmbulanceHeader extends StatelessWidget {
  final Ambulance ambulance;
  final String driverName;
  final bool gpsActive;
  final VoidCallback onToggleGps;

  const _AmbulanceHeader({
    required this.ambulance,
    required this.driverName,
    required this.gpsActive,
    required this.onToggleGps,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.primary,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.airport_shuttle_outlined,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ambulance.plateNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (driverName.isNotEmpty)
                    Text(
                      driverName,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13),
                    ),
                ],
              ),
            ),
            Tooltip(
              message: gpsActive
                  ? 'Sharing your live location — tap to stop'
                  : 'Location off — tap to share your live position',
              child: GestureDetector(
                onTap: onToggleGps,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: gpsActive
                        ? Colors.greenAccent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: gpsActive
                          ? Colors.greenAccent
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        gpsActive ? Icons.gps_fixed : Icons.gps_off,
                        color: gpsActive ? Colors.greenAccent : Colors.white60,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        gpsActive ? 'GPS On' : 'GPS Off',
                        style: TextStyle(
                          color:
                              gpsActive ? Colors.greenAccent : Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status toggle
// ---------------------------------------------------------------------------

class _StatusToggle extends StatefulWidget {
  final AmbulanceStatus current;
  final bool hasActiveJob;
  final Future<void> Function(String) onChanged;

  const _StatusToggle({
    required this.current,
    required this.hasActiveJob,
    required this.onChanged,
  });

  @override
  State<_StatusToggle> createState() => _StatusToggleState();
}

class _StatusToggleState extends State<_StatusToggle> {
  bool _updating = false;

  Future<void> _select(String status) async {
    if (_updating || widget.current.dbValue == status) return;
    setState(() => _updating = true);
    try {
      await widget.onChanged(status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'YOUR STATUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            if (_updating) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _OnlineSwitch(
                online: current != AmbulanceStatus.offline,
                enabled: !_updating,
                onChanged: (goOnline) =>
                    _select(goOnline ? 'available' : 'offline'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _StatusButton(
                label: 'Busy',
                icon: Icons.do_not_disturb_on_outlined,
                color: AppColors.statusBusy,
                // Automatic: turns on the moment a job is accepted, and
                // off again once it's completed/cancelled -- not a manual
                // control, since being "busy" is a fact, not a choice.
                selected: widget.hasActiveJob,
                enabled: false,
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Single Online/Offline switch — the primary control for going on or off
/// duty. Any non-offline status (available/busy/dispatched/en_route) reads
/// as "online".
class _OnlineSwitch extends StatelessWidget {
  final bool online;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _OnlineSwitch({
    required this.online,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        online ? AppColors.statusAvailable : AppColors.statusOffline;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? () => onChanged(!online) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      online
                          ? Icons.radio_button_checked
                          : Icons.power_settings_new,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      online ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: online,
                  activeThumbColor: AppColors.statusAvailable,
                  onChanged: enabled ? onChanged : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = selected ? color : AppColors.textSecondary;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? color : AppColors.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fgColor, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Job offer card with 30-second countdown
// ---------------------------------------------------------------------------

class _JobOfferCard extends ConsumerStatefulWidget {
  final Incident incident;
  const _JobOfferCard({required this.incident});

  @override
  ConsumerState<_JobOfferCard> createState() => _JobOfferCardState();
}

class _JobOfferCardState extends ConsumerState<_JobOfferCard> {
  static const _countdownSeconds = 30;
  late int _secondsLeft;
  Timer? _timer;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _countdownSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        _decline(); // auto-decline on timeout
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    _timer?.cancel();
    setState(() => _acting = true);
    try {
      await ref.read(driverIncidentProvider.notifier).acceptOffer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e')),
        );
        setState(() => _acting = false);
      }
    }
  }

  Future<void> _decline() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _acting = true);
    try {
      await ref.read(driverIncidentProvider.notifier).declineOffer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e')),
        );
        setState(() => _acting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final progress = _secondsLeft / _countdownSeconds;
    final urgentColor =
        _secondsLeft <= 10 ? AppColors.error : AppColors.statusPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'NEW JOB OFFER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.statusPending,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            // Countdown ring
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: AppColors.divider,
                    color: urgentColor,
                  ),
                ),
                Text(
                  '$_secondsLeft',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: urgentColor),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.statusPending.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: AppColors.statusPending.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      AppColors.statusPending.withValues(alpha: 0.06),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notification_important_outlined,
                        color: AppColors.statusPending, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        incident.natureOfEmergency.isEmpty
                            ? 'Emergency'
                            : incident.natureOfEmergency,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              // Details
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    if (incident.reporterName.isNotEmpty)
                      _DetailRow(
                        Icons.person_outline,
                        incident.reporterPhone.isEmpty
                            ? incident.reporterName
                            : '${incident.reporterName}  ·  ${incident.reporterPhone}',
                      ),
                    if (incident.patientConditionNotes.isNotEmpty)
                      _DetailRow(
                        Icons.medical_information_outlined,
                        incident.patientConditionNotes,
                        highlight: true,
                      ),
                    if (incident.locationDescription.isNotEmpty)
                      _DetailRow(
                        Icons.place_outlined,
                        incident.locationDescription,
                      ),
                  ],
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _acting ? null : _decline,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(color: AppColors.error),
                          foregroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Decline',
                            style:
                                TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _acting ? null : _accept,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.statusAvailable,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _acting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Accept',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Standing by (no active incident)
// ---------------------------------------------------------------------------

class _StandingByCard extends StatelessWidget {
  const _StandingByCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            Icons.radio_button_on_outlined,
            size: 56,
            color: AppColors.statusAvailable.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          const Text(
            'Standing by',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Waiting for dispatch assignment',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active incident card
// ---------------------------------------------------------------------------

class _ActiveIncidentCard extends ConsumerStatefulWidget {
  final Incident incident;
  const _ActiveIncidentCard({required this.incident});

  @override
  ConsumerState<_ActiveIncidentCard> createState() =>
      _ActiveIncidentCardState();
}

class _ActiveIncidentCardState
    extends ConsumerState<_ActiveIncidentCard> {
  bool _advancing = false;

  void _navigateToScene() {
    final lat = widget.incident.latitude;
    final lng = widget.incident.longitude;
    if (lat == null || lng == null) return;
    ref.read(_navTargetProvider.notifier).state = LatLng(lat, lng);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navigating — map centred on patient location'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _advance() async {
    setState(() => _advancing = true);
    try {
      await ref
          .read(driverIncidentProvider.notifier)
          .advanceStatus();
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;

    final hospitalAsync = incident.assignedHospitalId != null
        ? ref
            .watch(hospitalByIdProvider(incident.assignedHospitalId!))
        : const AsyncData<Hospital?>(null);
    final hospitalName = hospitalAsync.valueOrNull?.name;

    final (buttonLabel, buttonIcon, buttonColor) =
        switch (incident.status) {
      IncidentStatus.dispatched => (
          "I'm En Route",
          Icons.directions_car_outlined,
          AppColors.statusEnRoute,
        ),
      IncidentStatus.enRoute => (
          "I've Arrived",
          Icons.location_on_outlined,
          AppColors.statusArrived,
        ),
      IncidentStatus.arrived => (
          'Incident Complete',
          Icons.check_circle_outline,
          AppColors.statusAvailable,
        ),
      _ => (null, null, null),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACTIVE INCIDENT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        incident.natureOfEmergency.isEmpty
                            ? 'Emergency'
                            : incident.natureOfEmergency,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    StatusBadge(status: incident.status.dbValue),
                  ],
                ),
              ),
              // Detail rows
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    if (incident.locationDescription.isNotEmpty)
                      _DetailRow(Icons.place_outlined,
                          incident.locationDescription),
                    _DetailRow(
                      Icons.person_outline,
                      incident.reporterName.isEmpty
                          ? 'Unknown caller'
                          : incident.reporterPhone.isEmpty
                              ? incident.reporterName
                              : '${incident.reporterName}  ·  ${incident.reporterPhone}',
                    ),
                    if (hospitalName != null)
                      _DetailRow(
                          Icons.local_hospital_outlined, hospitalName),
                    if (incident.patientConditionNotes.isNotEmpty) ...[
                      const Divider(height: 20),
                      _DetailRow(
                        Icons.medical_information_outlined,
                        incident.patientConditionNotes,
                        highlight: true,
                      ),
                    ],
                  ],
                ),
              ),
              // Navigate to scene (centres the in-app live map on patient)
              if (incident.latitude != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _navigateToScene,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text(
                        'Navigate to Scene',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              // Chat with patient/dispatcher
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Builder(
                  builder: (ctx) {
                    final msgs =
                        ref.watch(messagesProvider(incident.id));
                    final seen = ref.watch(
                            chatSeenProvider)[incident.id] ??
                        0;
                    final unread =
                        ((msgs.valueOrNull?.length ?? 0) - seen)
                            .clamp(0, 99);
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            showChatSheet(context, incident.id),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(
                              color: AppColors.secondary),
                          foregroundColor: AppColors.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: chatIconWithBadge(unread),
                        label: Text(
                          unread > 0
                              ? 'Chat ($unread new)'
                              : 'Chat',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Voice / video call buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pushCallScreen(
                          context,
                          incidentId: incident.id,
                          isVideo: false,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(
                              color: AppColors.statusAvailable),
                          foregroundColor: AppColors.statusAvailable,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.call_outlined, size: 18),
                        label: const Text('Voice Call',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pushCallScreen(
                          context,
                          incidentId: incident.id,
                          isVideo: true,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: const BorderSide(
                              color: AppColors.statusEnRoute),
                          foregroundColor: AppColors.statusEnRoute,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon:
                            const Icon(Icons.videocam_outlined, size: 18),
                        label: const Text('Video Call',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              // Action button
              if (buttonLabel != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _advancing ? null : _advance,
                      style: FilledButton.styleFrom(
                        backgroundColor: buttonColor,
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _advancing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : Icon(buttonIcon),
                      label: Text(
                        buttonLabel,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Provider: navigation target set when driver taps "Navigate to Scene"
// ---------------------------------------------------------------------------

final _navTargetProvider = StateProvider<LatLng?>((ref) => null);

// ---------------------------------------------------------------------------
// Single live map — top half of the Active tab
// Shows all active incidents, driver's ambulance, and assigned hospital
// ---------------------------------------------------------------------------

class _DriverLiveMap extends ConsumerStatefulWidget {
  final Ambulance ambulance;
  final List<Incident> incidents;
  final Incident? assignedIncident;

  const _DriverLiveMap({
    required this.ambulance,
    required this.incidents,
    required this.assignedIncident,
  });

  @override
  ConsumerState<_DriverLiveMap> createState() => _DriverLiveMapState();
}

class _DriverLiveMapState extends ConsumerState<_DriverLiveMap> {
  final _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final navTarget = ref.watch(_navTargetProvider);
    final ambulance = widget.ambulance;
    final driverLat = ambulance.latitude;
    final driverLng = ambulance.longitude;

    // When navigate-to-scene is tapped, move map to patient
    ref.listen(_navTargetProvider, (_, next) {
      if (next != null) {
        _mapController.move(next, 15);
      }
    });

    final hospitalAsync = widget.assignedIncident?.assignedHospitalId != null
        ? ref.watch(
            hospitalByIdProvider(widget.assignedIncident!.assignedHospitalId!))
        : const AsyncData<Hospital?>(null);
    final hospital = hospitalAsync.valueOrNull;

    // Build markers
    final markers = <Marker>[];

    // All active incident pins
    for (final inc in widget.incidents) {
      final lat = inc.latitude;
      final lng = inc.longitude;
      if (lat == null || lng == null) continue;
      final isAssigned = inc.id == widget.assignedIncident?.id;
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 44,
        height: 52,
        child: Tooltip(
          message: inc.locationDescription.isEmpty
              ? inc.natureOfEmergency
              : inc.locationDescription,
          child: Column(
            children: [
              Container(
                width: isAssigned ? 40 : 32,
                height: isAssigned ? 40 : 32,
                decoration: BoxDecoration(
                  color: isAssigned ? AppColors.primary : AppColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (isAssigned ? AppColors.primary : AppColors.error)
                          .withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  isAssigned
                      ? Icons.person_pin_circle
                      : Icons.emergency_outlined,
                  color: Colors.white,
                  size: isAssigned ? 22 : 16,
                ),
              ),
              Container(
                  width: 2,
                  height: 10,
                  color: isAssigned ? AppColors.primary : AppColors.error),
            ],
          ),
        ),
      ));
    }

    // Hospital pin (assigned hospital only)
    if (hospital != null &&
        hospital.latitude != null &&
        hospital.longitude != null) {
      markers.add(Marker(
        point: LatLng(hospital.latitude!, hospital.longitude!),
        width: 40,
        height: 40,
        child: Tooltip(
          message: hospital.name,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
              ],
            ),
            child: const Icon(Icons.local_hospital,
                color: Colors.white, size: 20),
          ),
        ),
      ));
    }

    // Driver pin
    if (driverLat != null && driverLng != null) {
      markers.add(Marker(
        point: LatLng(driverLat, driverLng),
        width: 40,
        height: 40,
        child: Tooltip(
          message: ambulance.plateNumber,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.statusEnRoute,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                    color: AppColors.statusEnRoute.withValues(alpha: 0.35),
                    blurRadius: 10),
              ],
            ),
            child:
                const Icon(Icons.airport_shuttle, color: Colors.white, size: 20),
          ),
        ),
      ));
    }

    // Default centre: driver's GPS → first incident → Kampala
    final defaultCenter = driverLat != null && driverLng != null
        ? LatLng(driverLat, driverLng)
        : widget.incidents.isNotEmpty &&
                widget.incidents.first.latitude != null
            ? LatLng(widget.incidents.first.latitude!,
                widget.incidents.first.longitude!)
            : const LatLng(0.3476, 32.5825); // Kampala

    // Shortest road route to the patient assigned to this ambulance — the
    // path the driver should actually follow, highlighted on the map.
    final assignedLat = widget.assignedIncident?.latitude;
    final assignedLng = widget.assignedIncident?.longitude;
    final routeToPatient = (driverLat != null &&
            driverLng != null &&
            assignedLat != null &&
            assignedLng != null)
        ? ref
            .watch(routeProvider(routeCacheKey(
              LatLng(driverLat, driverLng),
              LatLng(assignedLat, assignedLng),
            )))
            .valueOrNull
        : null;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: navTarget ?? defaultCenter,
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.erams.erams',
            ),
            if (routeToPatient != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routeToPatient.points,
                    color: AppColors.primary,
                    strokeWidth: 5,
                    borderColor: Colors.white,
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
          ],
        ),
        // Legend
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LegendRow(AppColors.primary, Icons.person_pin_circle,
                    'Your patient'),
                const SizedBox(height: 4),
                const _LegendRow(AppColors.error, Icons.emergency_outlined,
                    'Other calls'),
                if (hospital != null) ...[
                  const SizedBox(height: 4),
                  const _LegendRow(AppColors.secondary, Icons.local_hospital,
                      'Hospital'),
                ],
                if (driverLat != null) ...[
                  const SizedBox(height: 4),
                  const _LegendRow(
                      AppColors.statusEnRoute, Icons.airport_shuttle, 'You'),
                ],
              ],
            ),
          ),
        ),
        // Live badge
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.statusAvailable,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  'LIVE  ·  ${widget.incidents.length} calls',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ),
        // OSM attribution
        Positioned(
          bottom: 2,
          right: 6,
          child: Text(
            '© OpenStreetMap',
            style: TextStyle(
                fontSize: 9, color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _LegendRow(this.color, this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5)),
          child: Icon(icon, color: Colors.white, size: 11),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detail row
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const _DetailRow(this.icon, this.text, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: highlight
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: highlight
                    ? FontWeight.w500
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
