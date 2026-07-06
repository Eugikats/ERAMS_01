import 'dart:async';

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
    state = AsyncData(amb.copyWith(status: AmbulanceStatus.fromString(status)));
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

  Future<void> acceptOffer() async {
    final incident = state.valueOrNull;
    if (incident == null) return;
    await DriverService().acceptTrip(incident.id);
    // Realtime subscription fires on incident update → _refresh() handles state
  }

  /// Declines the current job offer. After decline, the incident is
  /// re-assigned to a different ambulance, so the Realtime filter on this
  /// ambulance_id will no longer fire — we must refresh manually.
  Future<void> declineOffer() async {
    final incident = state.valueOrNull;
    if (incident == null) return;
    await DriverService().declineTrip(incident.id);
    await _refresh();
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
// GPS tracking — streams the device position and uploads it every 15 s.
// Works on web (via geolocator_web / the browser Geolocation API) as well as
// Android/iOS/desktop.
// ---------------------------------------------------------------------------

/// Whether the device position is currently being streamed and shared.
final gpsActiveProvider = StateProvider<bool>((ref) => false);

/// Outcome of a [GpsNotifier.startTracking] attempt, so the UI can explain to
/// the driver exactly why location sharing did or didn't begin.
enum GpsStartResult {
  started,
  alreadyRunning,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

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

  Future<GpsStartResult> startTracking() async {
    // Already streaming — treat as success, don't open a second stream.
    if (_positionSub != null) return GpsStartResult.alreadyRunning;

    // Location services must be enabled on the device / browser.
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      // Some browsers throw instead of answering — assume available and let
      // the permission check below be the real gate.
      serviceEnabled = true;
    }
    if (!serviceEnabled) return GpsStartResult.serviceDisabled;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return GpsStartResult.permissionDeniedForever;
    }
    if (perm != LocationPermission.whileInUse &&
        perm != LocationPermission.always) {
      return GpsStartResult.permissionDenied;
    }

    ref.read(gpsActiveProvider.notifier).state = true;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (pos) {
        final isFirstFix = _latestPosition == null;
        _latestPosition = pos;
        state = AsyncData(pos);
        // Publish the very first fix immediately so the driver appears on the
        // map without waiting for the next upload tick.
        if (isFirstFix) _pushLocation();
      },
      onError: (Object e, StackTrace st) {
        // Stream failed mid-session (permission revoked, hardware error) —
        // flip back to inactive so the badge reflects reality.
        state = AsyncError(e, st);
        stopTracking();
      },
      cancelOnError: true,
    );

    // Upload on a fixed 15-second cadence regardless of stream frequency.
    _uploadTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _pushLocation());

    return GpsStartResult.started;
  }

  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _latestPosition = null;
    ref.read(gpsActiveProvider.notifier).state = false;
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
