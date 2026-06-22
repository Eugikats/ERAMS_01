import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/ambulance.dart';
import '../services/patient_service.dart';

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
