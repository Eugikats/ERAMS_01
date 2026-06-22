import '../models/ambulance.dart';
import 'supabase_service.dart';

class PatientService {
  /// Returns available ambulances ordered by distance from [lat]/[lng].
  /// Falls back to alphabetical order on web when PostGIS RPC is unavailable.
  Future<List<Ambulance>> fetchNearbyAmbulances(double lat, double lng) async {
    try {
      // Use PostGIS RPC for distance-ordered results
      final data = await supabaseClient.rpc('nearby_ambulances', params: {
        'p_lat': lat,
        'p_lng': lng,
      });
      return (data as List)
          .map((e) => Ambulance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback: plain query without distance ordering
      final data = await supabaseClient
          .from('ambulances')
          .select()
          .eq('status', 'available')
          .order('plate_number');
      return (data as List)
          .map((e) => Ambulance.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }
}
