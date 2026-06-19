import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ambulance.dart';
import '../models/hospital.dart';
import '../models/profile.dart';
import '../services/admin_service.dart';

// ── Fleet ─────────────────────────────────────────────────────

class FleetNotifier extends AsyncNotifier<List<Ambulance>> {
  @override
  Future<List<Ambulance>> build() => AdminService().fetchAllAmbulances();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(AdminService().fetchAllAmbulances);
  }

  Future<void> createAmbulance({
    required String plateNumber,
    String? driverId,
    String? hospitalId,
  }) async {
    await AdminService().createAmbulance(
      plateNumber: plateNumber,
      driverId: driverId,
      hospitalId: hospitalId,
    );
    await refresh();
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
    await AdminService().updateAmbulance(
      id,
      plateNumber: plateNumber,
      status: status,
      driverId: driverId,
      hospitalId: hospitalId,
      clearDriver: clearDriver,
      clearHospital: clearHospital,
    );
    await refresh();
  }
}

final fleetNotifierProvider =
    AsyncNotifierProvider<FleetNotifier, List<Ambulance>>(FleetNotifier.new);

// ── Profiles ─────────────────────────────────────────────────

class ProfilesNotifier extends AsyncNotifier<List<Profile>> {
  @override
  Future<List<Profile>> build() => AdminService().fetchAllProfiles();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(AdminService().fetchAllProfiles);
  }

  Future<void> updateRole(String userId, String role) async {
    await AdminService().updateProfileRole(userId, role);
    await refresh();
  }

  Future<void> updateHospital(String userId, String? hospitalId) async {
    await AdminService().updateProfileHospital(userId, hospitalId);
    await refresh();
  }

  Future<void> updateDetails(
    String userId, {
    required String fullName,
    required String phone,
  }) async {
    await AdminService()
        .updateProfileDetails(userId, fullName: fullName, phone: phone);
    await refresh();
  }

  Future<String> createUser({
    required String email,
    required String fullName,
    required String role,
    String? hospitalId,
    String phone = '',
  }) async {
    final tempPassword = await AdminService().createUser(
      email: email,
      fullName: fullName,
      role: role,
      hospitalId: hospitalId,
      phone: phone,
    );
    await refresh();
    return tempPassword;
  }

  Future<String> resetPassword(String userId) {
    return AdminService().resetUserPassword(userId);
  }
}

final profilesNotifierProvider =
    AsyncNotifierProvider<ProfilesNotifier, List<Profile>>(
        ProfilesNotifier.new);

// ── Hospitals (shared lookup) ─────────────────────────────────

final adminHospitalsProvider = FutureProvider<List<Hospital>>(
    (_) => AdminService().fetchAllHospitals());

// ── Analytics ────────────────────────────────────────────────

final analyticsProvider = FutureProvider<AdminAnalytics>(
    (_) => AdminService().fetchAnalytics());
