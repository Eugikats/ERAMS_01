import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ambulance.dart';
import '../models/incident.dart';
import '../models/trip.dart';
import '../services/patient_service.dart';
import '../services/supabase_service.dart';

// ── Patient GPS location ──────────────────────────────────────────────────────

/// Kampala city centre — used as the default when GPS is unavailable on web.
const _kampalaDefault = LatLng(0.3136, 32.5811);

final patientLocationProvider = FutureProvider<LatLng>((ref) async {
  if (kIsWeb) {
    // On web, try the browser geolocation API via geolocator
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 8));
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return _kampalaDefault;
    }
  }

  // Native (Android/iOS)
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return _kampalaDefault;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return _kampalaDefault;
  }
  if (permission == LocationPermission.deniedForever) return _kampalaDefault;

  final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
  return LatLng(pos.latitude, pos.longitude);
});

// ── Nearby ambulances ─────────────────────────────────────────────────────────

final nearbyAmbulancesProvider =
    FutureProvider.autoDispose<List<Ambulance>>((ref) async {
  final locationAsync = ref.watch(patientLocationProvider);
  final location = locationAsync.valueOrNull ?? _kampalaDefault;
  return PatientService()
      .fetchNearbyAmbulances(location.latitude, location.longitude);
});

// ── Patient's active trip/incident ───────────────────────────────────────────

/// Returns the patient's current active incident (pending_acceptance →
/// arrived), or null when they have no active trip.
final patientActiveIncidentProvider =
    FutureProvider.autoDispose<Incident?>((ref) async {
  return PatientService().fetchActiveTrip();
});

// ── Realtime incident tracking (by incidentId) ────────────────────────────────

class ActiveIncidentNotifier
    extends FamilyAsyncNotifier<Incident?, String> {
  RealtimeChannel? _channel;
  late String _incidentId;

  @override
  Future<Incident?> build(String incidentId) async {
    _incidentId = incidentId;
    final data = await supabaseClient
        .from('incidents')
        .select()
        .eq('id', _incidentId)
        .maybeSingle();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return data != null ? Incident.fromJson(data) : null;
  }

  void _subscribeRealtime() {
    _channel = supabaseClient
        .channel('patient:incident:$_incidentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'incidents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _incidentId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    try {
      final data = await supabaseClient
          .from('incidents')
          .select()
          .eq('id', _incidentId)
          .maybeSingle();
      state = AsyncData(data != null ? Incident.fromJson(data) : null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final activeIncidentProvider = AsyncNotifierProvider.family<
    ActiveIncidentNotifier, Incident?, String>(
  ActiveIncidentNotifier.new,
);

// ── Realtime ambulance location tracking (by ambulanceId) ─────────────────────

class TrackingAmbulanceNotifier
    extends FamilyAsyncNotifier<Ambulance?, String> {
  RealtimeChannel? _channel;
  late String _ambulanceId;

  @override
  Future<Ambulance?> build(String ambulanceId) async {
    _ambulanceId = ambulanceId;
    final data = await supabaseClient
        .from('ambulances')
        .select()
        .eq('id', _ambulanceId)
        .maybeSingle();
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return data != null ? Ambulance.fromJson(data) : null;
  }

  void _subscribeRealtime() {
    _channel = supabaseClient
        .channel('patient:ambulance:$_ambulanceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ambulances',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _ambulanceId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    try {
      final data = await supabaseClient
          .from('ambulances')
          .select()
          .eq('id', _ambulanceId)
          .maybeSingle();
      state = AsyncData(data != null ? Ambulance.fromJson(data) : null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final trackingAmbulanceProvider = AsyncNotifierProvider.family<
    TrackingAmbulanceNotifier, Ambulance?, String>(
  TrackingAmbulanceNotifier.new,
);

// ── Trip + driver info (one-time fetch for tracking screen) ───────────────────

final tripWithDriverProvider = FutureProvider.family
    .autoDispose<({Trip trip, String driverName, String driverPhone})?, String>(
  (ref, incidentId) => PatientService().fetchTripWithDriver(incidentId),
);
