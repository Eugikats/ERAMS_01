import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Throws if [id] has any incidents still pointing at it, so deleting an
  /// ambulance never silently orphans incident history.
  Future<void> deleteAmbulance(String id) async {
    final incidents = await supabaseClient
        .from('incidents')
        .select('id')
        .eq('assigned_ambulance_id', id);
    if ((incidents as List).isNotEmpty) {
      throw Exception(
          'Cannot delete — ${incidents.length} incident(s) still reference '
          'this ambulance. Reassign or complete them first.');
    }
    await supabaseClient.from('ambulances').delete().eq('id', id);
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

  Future<void> updateProfileDetails(
    String userId, {
    required String fullName,
    required String phone,
  }) async {
    await supabaseClient.from('profiles').update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', userId);
  }

  /// Creates a new auth user + profile via the `admin_create_user` Edge
  /// Function (requires the service-role key, which never touches the
  /// client). Returns the auto-generated temporary password to show the
  /// admin once — the new user must set their own password on first login.
  Future<String> createUser({
    required String email,
    required String fullName,
    required String role,
    String? hospitalId,
    String phone = '',
  }) async {
    try {
      final res = await supabaseClient.functions.invoke(
        'admin_create_user',
        body: {
          'email': email,
          'fullName': fullName,
          'role': role,
          'hospitalId': hospitalId,
          'phone': phone,
        },
      );
      return res.data['tempPassword'] as String;
    } on FunctionException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// Resets a user's password via the `admin_reset_password` Edge Function.
  /// Returns the new temporary password; the user must set their own on
  /// next login.
  Future<String> resetUserPassword(String userId) async {
    try {
      final res = await supabaseClient.functions.invoke(
        'admin_reset_password',
        body: {'userId': userId},
      );
      return res.data['tempPassword'] as String;
    } on FunctionException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  String _extractError(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return e.reasonPhrase ?? 'Request failed';
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

  Future<void> createHospital({
    required String name,
    required String address,
    required String contactPhone,
    double? latitude,
    double? longitude,
  }) async {
    await supabaseClient.from('hospitals').insert({
      'name': name,
      'address': address,
      'contact_phone': contactPhone,
      if (latitude != null && longitude != null)
        'location': 'SRID=4326;POINT($longitude $latitude)',
    });
  }

  Future<void> updateHospital(
    String id, {
    required String name,
    required String address,
    required String contactPhone,
    double? latitude,
    double? longitude,
  }) async {
    await supabaseClient.from('hospitals').update({
      'name': name,
      'address': address,
      'contact_phone': contactPhone,
      if (latitude != null && longitude != null)
        'location': 'SRID=4326;POINT($longitude $latitude)',
    }).eq('id', id);
  }

  /// Throws if [id] still has ambulances, staff, or incidents pointing at
  /// it, so deleting a hospital never silently orphans history.
  Future<void> deleteHospital(String id) async {
    final ambulances = await supabaseClient
        .from('ambulances')
        .select('id')
        .eq('hospital_id', id);
    final staff = await supabaseClient
        .from('profiles')
        .select('id')
        .eq('hospital_id', id);
    final incidents = await supabaseClient
        .from('incidents')
        .select('id')
        .eq('assigned_hospital_id', id);

    final blockers = <String>[];
    if ((ambulances as List).isNotEmpty) {
      blockers.add('${ambulances.length} ambulance(s)');
    }
    if ((staff as List).isNotEmpty) {
      blockers.add('${staff.length} staff member(s)');
    }
    if ((incidents as List).isNotEmpty) {
      blockers.add('${incidents.length} incident(s)');
    }
    if (blockers.isNotEmpty) {
      throw Exception(
          'Cannot delete — ${blockers.join(', ')} still reference this '
          'hospital. Reassign them first.');
    }

    await supabaseClient.from('hospitals').delete().eq('id', id);
  }

  // ── Patient Records ──────────────────────────────────────────

  Future<List<PatientRecord>> fetchAllPatientRecords() async {
    final data = await supabaseClient
        .from('incidents')
        .select('*, ambulances(plate_number), hospitals(name)')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => PatientRecord.fromJson(e as Map<String, dynamic>))
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
        .select('assigned_hospital_id, hospitals(name)');

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

// ── Patient Records ──────────────────────────────────────────

class PatientRecord {
  final String incidentId;
  final String patientName;
  final String patientPhone;
  final String natureOfEmergency;
  final String locationDescription;
  final String status;
  final String? ambulancePlate;
  final String? hospitalName;
  final DateTime createdAt;
  final DateTime? dispatchedAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;

  const PatientRecord({
    required this.incidentId,
    required this.patientName,
    required this.patientPhone,
    required this.natureOfEmergency,
    required this.locationDescription,
    required this.status,
    this.ambulancePlate,
    this.hospitalName,
    required this.createdAt,
    this.dispatchedAt,
    this.arrivedAt,
    this.completedAt,
  });

  String? get responseTime {
    if (arrivedAt == null) return null;
    final diff = arrivedAt!.difference(createdAt);
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  factory PatientRecord.fromJson(Map<String, dynamic> json) {
    final ambulance = json['ambulances'] as Map<String, dynamic>?;
    final hospital = json['hospitals'] as Map<String, dynamic>?;
    return PatientRecord(
      incidentId: json['id'] as String,
      patientName: json['reporter_name'] as String? ?? '',
      patientPhone: json['reporter_phone'] as String? ?? '',
      natureOfEmergency: json['nature_of_emergency'] as String? ?? '',
      locationDescription: json['location_description'] as String? ?? '',
      status: json['status'] as String? ?? 'logged',
      ambulancePlate: ambulance?['plate_number'] as String?,
      hospitalName: hospital?['name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      dispatchedAt: json['dispatched_at'] != null
          ? DateTime.parse(json['dispatched_at'] as String)
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
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
