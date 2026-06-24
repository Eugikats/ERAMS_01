import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ambulance.dart';
import '../../models/hospital.dart';
import '../../models/incident.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../state/auth_provider.dart';
import '../../state/driver_provider.dart';
import '../../widgets/app_logo.dart';
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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _historyRows.isEmpty) {
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
      await ref.read(gpsNotifierProvider.notifier).startTracking();
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AmbulanceHeader(
                  ambulance: ambulance,
                  driverName: profile?.fullName ?? '',
                  gpsActive: gpsActive,
                  onToggleGps: () async {
                    if (gpsActive) {
                      ref.read(gpsNotifierProvider.notifier).stopTracking();
                    } else {
                      await ref
                          .read(gpsNotifierProvider.notifier)
                          .startTracking();
                    }
                  },
                ),
                const SizedBox(height: 16),
                _StatusToggle(
                  current: ambulance.status,
                  onChanged: (newStatus) async {
                    await ref
                        .read(driverAmbulanceProvider.notifier)
                        .setStatus(newStatus);
                    if (newStatus == 'offline') {
                      ref.read(gpsNotifierProvider.notifier).stopTracking();
                    } else if (!ref.read(gpsActiveProvider)) {
                      await ref
                          .read(gpsNotifierProvider.notifier)
                          .startTracking();
                    }
                  },
                ),
                const SizedBox(height: 20),
                incidentAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text(
                    'Error loading incident: $e',
                    style:
                        const TextStyle(color: AppColors.error),
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
          );
        },
      ),
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
            GestureDetector(
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
                      color: gpsActive
                          ? Colors.greenAccent
                          : Colors.white60,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      gpsActive ? 'GPS On' : 'GPS Off',
                      style: TextStyle(
                        color: gpsActive
                            ? Colors.greenAccent
                            : Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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

class _StatusToggle extends StatelessWidget {
  final AmbulanceStatus current;
  final ValueChanged<String> onChanged;

  const _StatusToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatusButton(
                label: 'Available',
                icon: Icons.check_circle_outline,
                color: AppColors.statusAvailable,
                selected: current == AmbulanceStatus.available,
                onTap: () => onChanged('available'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusButton(
                label: 'Busy',
                icon: Icons.do_not_disturb_on_outlined,
                color: AppColors.statusBusy,
                selected: current == AmbulanceStatus.busy,
                onTap: () => onChanged('busy'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusButton(
                label: 'Offline',
                icon: Icons.power_settings_new,
                color: AppColors.statusOffline,
                selected: current == AmbulanceStatus.offline,
                onTap: () => onChanged('offline'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
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
              Icon(icon,
                  color:
                      selected ? color : AppColors.textSecondary,
                  size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color:
                      selected ? color : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
                    if (incident.latitude != null)
                      _DetailRow(
                        Icons.place_outlined,
                        '${incident.latitude!.toStringAsFixed(4)}, '
                            '${incident.longitude!.toStringAsFixed(4)}',
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

  Future<void> _navigateToScene() async {
    final lat = widget.incident.latitude;
    final lng = widget.incident.longitude;
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
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
              // Navigate to scene
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
                      icon: const Icon(Icons.navigation_outlined, size: 18),
                      label: const Text(
                        'Navigate to Scene',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
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
