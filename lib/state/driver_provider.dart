import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ambulance.dart';
import '../models/hospital.dart';
import '../models/incident.dart';
import '../services/driver_service.dart';
import '../services/supabase_service.dart';

// ---------------------------------------------------------------------------
// Driver's ambulance — Realtime subscription on their specific row
// ---------------------------------------------------------------------------

class DriverAmbulanceNotifier extends AsyncNotifier<Ambulance?> {
  RealtimeChannel? _channel;

  @override
  Future<Ambulance?> build() async {
    final ambulance = await DriverService().fetchMyAmbulance();
    if (ambulance != null) _subscribeRealtime(ambulance.id);
    ref.onDispose(() => _channel?.unsubscribe());
    return ambulance;
  }

  void _subscribeRealtime(String ambulanceId) {
    _channel = supabaseClient
        .channel('driver:ambulance:$ambulanceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ambulances',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: ambulanceId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    try {
      state = AsyncData(await DriverService().fetchMyAmbulance());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> setStatus(String status) async {
    final amb = state.valueOrNull;
    if (amb == null) return;
    await DriverService().setAmbulanceStatus(amb.id, status);
    // Optimistic update; Realtime confirms shortly after
    state = AsyncData(Ambulance(
      id: amb.id,
      plateNumber: amb.plateNumber,
      status: AmbulanceStatus.fromString(status),
      latitude: amb.latitude,
      longitude: amb.longitude,
      driverId: amb.driverId,
      hospitalId: amb.hospitalId,
      lastLocationUpdate: amb.lastLocationUpdate,
    ));
  }
}

final driverAmbulanceProvider =
    AsyncNotifierProvider<DriverAmbulanceNotifier, Ambulance?>(
  DriverAmbulanceNotifier.new,
);

// ---------------------------------------------------------------------------
// Active incident for this driver — filtered Realtime subscription
// ---------------------------------------------------------------------------

class DriverIncidentNotifier extends AsyncNotifier<Incident?> {
  RealtimeChannel? _channel;

  @override
  Future<Incident?> build() async {
    final ambulance = await ref.watch(driverAmbulanceProvider.future);
    if (ambulance == null) return null;

    final incident =
        await DriverService().fetchActiveIncident(ambulance.id);
    _subscribeRealtime(ambulance.id);
    ref.onDispose(() => _channel?.unsubscribe());
    return incident;
  }

  void _subscribeRealtime(String ambulanceId) {
    _channel = supabaseClient
        .channel('driver:incidents:$ambulanceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'incidents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_ambulance_id',
            value: ambulanceId,
          ),
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  Future<void> _refresh() async {
    try {
      final ambulance = ref.read(driverAmbulanceProvider).valueOrNull;
      if (ambulance == null) {
        state = const AsyncData(null);
        return;
      }
      state = AsyncData(
          await DriverService().fetchActiveIncident(ambulance.id));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> advanceStatus() async {
    final incident = state.valueOrNull;
    if (incident == null) return;
    final next = switch (incident.status) {
      IncidentStatus.dispatched => 'en_route',
      IncidentStatus.enRoute => 'arrived',
      IncidentStatus.arrived => 'completed',
      _ => null,
    };
    if (next == null) return;
    await DriverService().updateIncidentStatus(incident.id, next);
    // Realtime subscription will refresh state
  }
}

final driverIncidentProvider =
    AsyncNotifierProvider<DriverIncidentNotifier, Incident?>(
  DriverIncidentNotifier.new,
);

// ---------------------------------------------------------------------------
// Hospital lookup — family provider, cached by hospital ID
// ---------------------------------------------------------------------------

final hospitalByIdProvider =
    FutureProvider.family<Hospital?, String>((ref, id) {
  return DriverService().fetchHospital(id);
});

// ---------------------------------------------------------------------------
// GPS tracking — streams device position, uploads every 2 s
// ---------------------------------------------------------------------------

final gpsActiveProvider = StateProvider<bool>((ref) => false);

class GpsNotifier extends AsyncNotifier<Position?> {
  StreamSubscription<Position>? _positionSub;
  Timer? _uploadTimer;
  Position? _latestPosition;
  final _queue = <({String ambulanceId, double lat, double lng})>[];

  @override
  Future<Position?> build() async {
    ref.onDispose(() {
      _positionSub?.cancel();
      _uploadTimer?.cancel();
    });
    return null;
  }

  Future<void> startTracking() async {
    // GPS hardware APIs are not available on Flutter web.
    if (kIsWeb) return;
    if (!await _ensurePermission()) return;

    ref.read(gpsActiveProvider.notifier).state = true;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen((pos) {
      _latestPosition = pos;
      state = AsyncData(pos);
    });

    // Upload on a fixed 2-second cadence regardless of stream frequency
    _uploadTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _pushLocation());
  }

  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    ref.read(gpsActiveProvider.notifier).state = false;
  }

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  Future<void> _pushLocation() async {
    final pos = _latestPosition;
    if (pos == null) return;
    final amb = ref.read(driverAmbulanceProvider).valueOrNull;
    if (amb == null) return;

    try {
      if (_queue.isNotEmpty) {
        final pending = List.of(_queue);
        _queue.clear();
        for (final p in pending) {
          await DriverService().pushLocation(p.ambulanceId, p.lat, p.lng);
        }
      }
      await DriverService().pushLocation(amb.id, pos.latitude, pos.longitude);
    } catch (_) {
      // Queue for retry on next tick
      _queue.add((
        ambulanceId: amb.id,
        lat: pos.latitude,
        lng: pos.longitude,
      ));
    }
  }
}

final gpsNotifierProvider =
    AsyncNotifierProvider<GpsNotifier, Position?>(GpsNotifier.new);
