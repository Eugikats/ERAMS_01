import '../models/ambulance.dart';
import '../models/hospital.dart';
import '../models/profile.dart';
import 'supabase_service.dart';

class AdminService {
  // ── Ambulances ────────────────────────────────────────────────

  Future<List<Ambulance>> fetchAllAmbulances() async {
    final data = await supabaseClient
        .from('ambulances')
        .select()
        .order('plate_number');
    return (data as List)
        .map((e) => Ambulance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createAmbulance({
    required String plateNumber,
    String? driverId,
    String? hospitalId,
  }) async {
    await supabaseClient.from('ambulances').insert({
      'plate_number': plateNumber,
      'status': 'offline',
      if (driverId != null) 'driver_id': driverId,
      if (hospitalId != null) 'hospital_id': hospitalId,
    });
  }

  Future<void> updateAmbulance(
    String id, {
    String? plateNumber,
    String? status,
    String? driverId,
    String? hospitalId,
    bool clearDriver = false,
    bool clearHospital = false,
  }) async {
    await supabaseClient.from('ambulances').update({
      if (plateNumber != null) 'plate_number': plateNumber,
      if (status != null) 'status': status,
      if (driverId != null) 'driver_id': driverId,
      if (clearDriver) 'driver_id': null,
      if (hospitalId != null) 'hospital_id': hospitalId,
      if (clearHospital) 'hospital_id': null,
    }).eq('id', id);
  }

  // ── Profiles (users) ─────────────────────────────────────────

  Future<List<Profile>> fetchAllProfiles() async {
    final data = await supabaseClient
        .from('profiles')
        .select()
        .order('full_name');
    return (data as List)
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateProfileRole(String userId, String role) async {
    await supabaseClient
        .from('profiles')
        .update({'role': role})
        .eq('id', userId);
  }

  Future<void> updateProfileHospital(String userId, String? hospitalId) async {
    await supabaseClient
        .from('profiles')
        .update({'hospital_id': hospitalId})
        .eq('id', userId);
  }

  // ── Hospitals ────────────────────────────────────────────────

  Future<List<Hospital>> fetchAllHospitals() async {
    final data = await supabaseClient
        .from('hospitals')
        .select()
        .order('name');
    return (data as List)
        .map((e) => Hospital.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Analytics ────────────────────────────────────────────────

  Future<AdminAnalytics> fetchAnalytics() async {
    // Incident counts by status
    final countData = await supabaseClient
        .from('incidents')
        .select('status');

    final counts = <String, int>{};
    for (final row in countData as List) {
      final s = row['status'] as String;
      counts[s] = (counts[s] ?? 0) + 1;
    }

    // Average response time: created_at → arrived_at (seconds)
    final rtData = await supabaseClient
        .from('incidents')
        .select('created_at, arrived_at')
        .not('arrived_at', 'is', null);

    double avgResponseSec = 0;
    if ((rtData as List).isNotEmpty) {
      final total = rtData.fold<double>(0, (sum, row) {
        final created = DateTime.parse(row['created_at'] as String);
        final arrived = DateTime.parse(row['arrived_at'] as String);
        return sum + arrived.difference(created).inSeconds;
      });
      avgResponseSec = total / rtData.length;
    }

    // Incidents by hospital
    final hospData = await supabaseClient
        .from('incidents')
        .select('hospital_id, hospitals(name)');

    final byHospital = <String, int>{};
    for (final row in hospData as List) {
      final name =
          (row['hospitals'] as Map<String, dynamic>?)?['name'] as String? ??
              'Unassigned';
      byHospital[name] = (byHospital[name] ?? 0) + 1;
    }

    return AdminAnalytics(
      countByStatus: counts,
      avgResponseSeconds: avgResponseSec,
      countByHospital: byHospital,
      totalIncidents: counts.values.fold(0, (a, b) => a + b),
    );
  }
}

class AdminAnalytics {
  final Map<String, int> countByStatus;
  final double avgResponseSeconds;
  final Map<String, int> countByHospital;
  final int totalIncidents;

  const AdminAnalytics({
    required this.countByStatus,
    required this.avgResponseSeconds,
    required this.countByHospital,
    required this.totalIncidents,
  });

  String get avgResponseFormatted {
    if (avgResponseSeconds == 0) return 'N/A';
    final mins = (avgResponseSeconds / 60).floor();
    final secs = (avgResponseSeconds % 60).round();
    if (mins == 0) return '${secs}s';
    return '${mins}m ${secs}s';
  }
}
