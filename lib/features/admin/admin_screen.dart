import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/ambulance.dart';
import '../../models/hospital.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../state/admin_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/profile_edit_sheet.dart';
import '../../widgets/status_badge.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                await AuthService().signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.airport_shuttle), text: 'Fleet'),
              Tab(icon: Icon(Icons.people), text: 'Users'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Analytics'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FleetTab(),
            _UsersTab(),
            _AnalyticsTab(),
          ],
        ),
      ),
    );
  }
}

// ── Fleet Tab ────────────────────────────────────────────────────────────────

class _FleetTab extends ConsumerWidget {
  const _FleetTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleetAsync = ref.watch(fleetNotifierProvider);
    final hospitalsAsync = ref.watch(adminHospitalsProvider);
    final profilesAsync = ref.watch(profilesNotifierProvider);

    return fleetAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: e.toString(),
          onRetry: () => ref.invalidate(fleetNotifierProvider)),
      data: (ambulances) {
        final hospitals = hospitalsAsync.valueOrNull ?? [];
        final drivers = (profilesAsync.valueOrNull ?? [])
            .where((p) => p.role == UserRole.driver)
            .toList();

        return Column(
          children: [
            _SectionHeader(
              title: '${ambulances.length} Ambulance${ambulances.length == 1 ? '' : 's'}',
              action: FilledButton.icon(
                onPressed: () => _showAmbulanceForm(
                  context,
                  ref,
                  hospitals: hospitals,
                  drivers: drivers,
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Ambulance'),
              ),
            ),
            Expanded(
              child: ambulances.isEmpty
                  ? const _EmptyState(
                      icon: Icons.airport_shuttle,
                      message: 'No ambulances yet.\nTap "Add Ambulance" to register one.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: ambulances.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _AmbulanceCard(
                        ambulance: ambulances[i],
                        hospitals: hospitals,
                        drivers: drivers,
                        onEdit: () => _showAmbulanceForm(
                          context,
                          ref,
                          existing: ambulances[i],
                          hospitals: hospitals,
                          drivers: drivers,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAmbulanceForm(
    BuildContext context,
    WidgetRef ref, {
    Ambulance? existing,
    required List<Hospital> hospitals,
    required List<Profile> drivers,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => _AmbulanceFormDialog(
        existing: existing,
        hospitals: hospitals,
        drivers: drivers,
        onSave: (plate, driverId, hospitalId, clearDriver, clearHospital) async {
          final notifier = ref.read(fleetNotifierProvider.notifier);
          if (existing == null) {
            await notifier.createAmbulance(
              plateNumber: plate,
              driverId: driverId,
              hospitalId: hospitalId,
            );
          } else {
            await notifier.updateAmbulance(
              existing.id,
              plateNumber: plate,
              driverId: driverId,
              hospitalId: hospitalId,
              clearDriver: clearDriver,
              clearHospital: clearHospital,
            );
          }
        },
      ),
    );
  }
}

class _AmbulanceCard extends StatelessWidget {
  final Ambulance ambulance;
  final List<Hospital> hospitals;
  final List<Profile> drivers;
  final VoidCallback onEdit;

  const _AmbulanceCard({
    required this.ambulance,
    required this.hospitals,
    required this.drivers,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hospital = hospitals.where((h) => h.id == ambulance.hospitalId)
        .firstOrNull;
    final driver = drivers.where((d) => d.id == ambulance.driverId)
        .firstOrNull;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.forStatus(ambulance.status.dbValue)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.airport_shuttle,
                color: AppColors.forStatus(ambulance.status.dbValue),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ambulance.plateNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusBadge(status: ambulance.status.dbValue),
                      if (driver != null)
                        _InfoChip(
                            icon: Icons.person, label: driver.fullName),
                      if (hospital != null)
                        _InfoChip(
                            icon: Icons.local_hospital, label: hospital.name),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbulanceFormDialog extends StatefulWidget {
  final Ambulance? existing;
  final List<Hospital> hospitals;
  final List<Profile> drivers;
  final Future<void> Function(String plate, String? driverId, String? hospitalId,
      bool clearDriver, bool clearHospital) onSave;

  const _AmbulanceFormDialog({
    this.existing,
    required this.hospitals,
    required this.drivers,
    required this.onSave,
  });

  @override
  State<_AmbulanceFormDialog> createState() => _AmbulanceFormDialogState();
}

class _AmbulanceFormDialogState extends State<_AmbulanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateCtrl;
  String? _driverId;
  String? _hospitalId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _plateCtrl =
        TextEditingController(text: widget.existing?.plateNumber ?? '');
    _driverId = widget.existing?.driverId;
    _hospitalId = widget.existing?.hospitalId;
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final origDriverId = widget.existing?.driverId;
      final origHospitalId = widget.existing?.hospitalId;
      await widget.onSave(
        _plateCtrl.text.trim().toUpperCase(),
        _driverId,
        _hospitalId,
        origDriverId != null && _driverId == null,
        origHospitalId != null && _hospitalId == null,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Ambulance' : 'Add Ambulance'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _plateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Plate Number *',
                  hintText: 'e.g. UAB 123X',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _driverId,
                decoration: const InputDecoration(labelText: 'Assigned Driver'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— None —')),
                  ...widget.drivers.map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d.fullName),
                      )),
                ],
                onChanged: (v) => setState(() => _driverId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _hospitalId,
                decoration:
                    const InputDecoration(labelText: 'Home Hospital'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— None —')),
                  ...widget.hospitals.map((h) => DropdownMenuItem(
                        value: h.id,
                        child: Text(h.name),
                      )),
                ],
                onChanged: (v) => setState(() => _hospitalId = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ── Users Tab ────────────────────────────────────────────────────────────────

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesNotifierProvider);
    final hospitalsAsync = ref.watch(adminHospitalsProvider);

    return profilesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(profilesNotifierProvider)),
      data: (profiles) {
        final hospitals = hospitalsAsync.valueOrNull ?? [];
        return Column(
          children: [
            _SectionHeader(
              title: '${profiles.length} User${profiles.length == 1 ? '' : 's'}',
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _UserCard(
                  profile: profiles[i],
                  hospitals: hospitals,
                  onChangeRole: (role) async {
                    await ref
                        .read(profilesNotifierProvider.notifier)
                        .updateRole(profiles[i].id, role);
                  },
                  onChangeHospital: (hid) async {
                    await ref
                        .read(profilesNotifierProvider.notifier)
                        .updateHospital(profiles[i].id, hid);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UserCard extends StatefulWidget {
  final Profile profile;
  final List<Hospital> hospitals;
  final Future<void> Function(String role) onChangeRole;
  final Future<void> Function(String? hospitalId) onChangeHospital;

  const _UserCard({
    required this.profile,
    required this.hospitals,
    required this.onChangeRole,
    required this.onChangeHospital,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _saving = false;

  Future<void> _pickRole(BuildContext context) async {
    final roles = ['dispatcher', 'driver', 'hospital', 'admin'];
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Change role for\n${widget.profile.fullName}',
            style: const TextStyle(fontSize: 15)),
        children: roles
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        if (r == widget.profile.role.name)
                          const Icon(Icons.check,
                              size: 16, color: AppColors.primary)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text(UserRole.fromString(r).label),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
    if (picked == null || picked == widget.profile.role.name) return;
    setState(() => _saving = true);
    try {
      await widget.onChangeRole(picked);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (widget.profile.role) {
      UserRole.admin => AppColors.primary,
      UserRole.dispatcher => AppColors.secondary,
      UserRole.driver => AppColors.statusEnRoute,
      UserRole.hospital => AppColors.statusArrived,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: Text(
                widget.profile.fullName.isNotEmpty
                    ? widget.profile.fullName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: roleColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.profile.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.profile.phone,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : GestureDetector(
                    onTap: () => _pickRole(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: roleColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.profile.role.label,
                            style: TextStyle(
                                color: roleColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down,
                              color: roleColor, size: 16),
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

// ── Analytics Tab ────────────────────────────────────────────────────────────

class _AnalyticsTab extends ConsumerWidget {
  const _AnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return analyticsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(analyticsProvider)),
      data: (a) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(analyticsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI row
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'Total Incidents',
                    value: '${a.totalIncidents}',
                    icon: Icons.assignment,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    label: 'Avg Response',
                    value: a.avgResponseFormatted,
                    icon: Icons.timer_outlined,
                    color: AppColors.statusDispatched,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Incidents by status
            _ChartCard(
              title: 'Incidents by Status',
              child: a.countByStatus.isEmpty
                  ? const _EmptyState(
                      icon: Icons.bar_chart,
                      message: 'No incident data yet.',
                    )
                  : _BarChart(
                      data: a.countByStatus,
                      colorFor: AppColors.forStatus,
                    ),
            ),
            const SizedBox(height: 16),
            // Incidents by hospital
            _ChartCard(
              title: 'Incidents by Hospital',
              child: a.countByHospital.isEmpty
                  ? const _EmptyState(
                      icon: Icons.local_hospital,
                      message: 'No hospital data yet.',
                    )
                  : _BarChart(
                      data: a.countByHospital,
                      colorFor: (_) => AppColors.secondary,
                    ),
            ),
            const SizedBox(height: 16),
            // Status breakdown table
            if (a.countByStatus.isNotEmpty) ...[
              _ChartCard(
                title: 'Status Breakdown',
                child: Column(
                  children: a.countByStatus.entries.map((e) {
                    final pct = a.totalIncidents > 0
                        ? e.value / a.totalIncidents
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          StatusBadge(status: e.key),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: AppColors.divider,
                                color: AppColors.forStatus(e.key),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${e.value}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Simple horizontal bar chart using only Flutter primitives (no fl_chart dep).
class _BarChart extends StatelessWidget {
  final Map<String, int> data;
  final Color Function(String key) colorFor;

  const _BarChart({required this.data, required this.colorFor});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.fold(0, (a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return Column(
      children: data.entries.map((e) {
        final frac = e.value / maxVal;
        final color = colorFor(e.key);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  e.key,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 18,
                    backgroundColor: AppColors.divider,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '${e.value}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textSecondary)),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
