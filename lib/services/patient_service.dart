import '../models/ambulance.dart';
import '../models/incident.dart';
import '../models/trip.dart';
import 'supabase_service.dart';

class PatientService {
  /// Returns available ambulances ordered by distance from [lat]/[lng].
  /// Falls back to alphabetical order when PostGIS RPC is unavailable.
  Future<List<Ambulance>> fetchNearbyAmbulances(double lat, double lng) async {
    try {
      final data = await supabaseClient.rpc('nearby_ambulances', params: {
        'p_lat': lat,
        'p_lng': lng,
      });
      return (data as List)
          .map((e) => Ambulance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
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

  /// Creates a patient-initiated incident and dispatches it to [ambulanceId]
  /// in pending_acceptance state. Returns the created incident.
  Future<Incident> createPatientIncident({
    required String natureOfEmergency,
    required String patientConditionNotes,
    required double latitude,
    required double longitude,
    required String ambulanceId,
    String? assignedHospitalId,
  }) async {
    final userId = supabaseClient.auth.currentUser!.id;

    // Fetch patient profile for reporter fields
    final profileData = await supabaseClient
        .from('profiles')
        .select('full_name, phone')
        .eq('id', userId)
        .single();

    // Insert the incident
    final incidentData = await supabaseClient
        .from('incidents')
        .insert({
          'reporter_name':          profileData['full_name'] as String? ?? '',
          'reporter_phone':         profileData['phone'] as String? ?? '',
          'incident_location':      'SRID=4326;POINT($longitude $latitude)',
          'nature_of_emergency':    natureOfEmergency,
          'patient_condition_notes': patientConditionNotes,
          'assigned_hospital_id':   assignedHospitalId,
          'status':                 'logged',
          'created_by':             userId,
        })
        .select()
        .single();

    final incidentId = incidentData['id'] as String;

    // Dispatch to the selected ambulance with patient_id → sets pending_acceptance
    await supabaseClient.rpc('dispatch_incident', params: {
      'p_incident_id':  incidentId,
      'p_ambulance_id': ambulanceId,
      'p_patient_id':   userId,
    });

    // Return the updated incident (with pending_acceptance status)
    final updated = await supabaseClient
        .from('incidents')
        .select()
        .eq('id', incidentId)
        .single();
    return Incident.fromJson(updated);
  }

  /// Returns the patient's most recent active incident (pending or dispatched),
  /// or null if they have none.
  Future<Incident?> fetchActiveTrip() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return null;

    // Get the most recent non-completed trip for this patient
    final tripData = await supabaseClient
        .from('trips')
        .select('incident_id')
        .eq('patient_id', userId)
        .inFilter('status', ['requested', 'accepted'])
        .order('requested_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (tripData == null) return null;
    final incidentId = tripData['incident_id'] as String;

    final incidentData = await supabaseClient
        .from('incidents')
        .select()
        .eq('id', incidentId)
        .inFilter('status', ['pending_acceptance', 'dispatched', 'en_route', 'arrived'])
        .maybeSingle();

    if (incidentData == null) return null;
    return Incident.fromJson(incidentData);
  }

  /// Records a patient rating (1–5 stars) for a completed trip.
  Future<void> submitRating(
      String tripId, int rating, String? comment) async {
    await supabaseClient.from('trips').update({
      'patient_rating': rating,
      if (comment != null) 'patient_comment': comment,
    }).eq('id', tripId);
  }

  /// Fetches the active trip for [incidentId] along with the driver's profile.
  /// Returns null when no qualifying trip exists.
  Future<({Trip trip, String driverName, String driverPhone})?>
      fetchTripWithDriver(String incidentId) async {
    final tripData = await supabaseClient
        .from('trips')
        .select()
        .eq('incident_id', incidentId)
        .inFilter('status',
            ['requested', 'accepted', 'en_route', 'arrived', 'completed'])
        .order('requested_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (tripData == null) return null;
    final trip = Trip.fromJson(tripData);

    String driverName = '';
    String driverPhone = '';
    if (trip.driverId != null) {
      try {
        final profileData = await supabaseClient
            .from('profiles')
            .select('full_name, phone')
            .eq('id', trip.driverId!)
            .single();
        driverName = profileData['full_name'] as String? ?? '';
        driverPhone = profileData['phone'] as String? ?? '';
      } catch (_) {}
    }

    return (trip: trip, driverName: driverName, driverPhone: driverPhone);
  }
}
