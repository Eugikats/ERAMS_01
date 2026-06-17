import '../models/incident.dart';
import '../models/hospital.dart';
import 'supabase_service.dart';

class IncidentService {
  Future<List<Incident>> fetchActiveIncidents() async {
    final data = await supabaseClient
        .from('incidents')
        .select()
        .inFilter('status', ['logged', 'dispatched', 'en_route', 'arrived'])
        .order('created_at', ascending: false);
    return (data as List).map((e) => Incident.fromJson(e)).toList();
  }

  Future<List<Hospital>> fetchHospitals() async {
    final data = await supabaseClient.from('hospitals').select();
    return (data as List).map((e) => Hospital.fromJson(e)).toList();
  }

  Future<Incident> createIncident({
    required String reporterName,
    required String reporterPhone,
    required double latitude,
    required double longitude,
    required String locationDescription,
    required String natureOfEmergency,
    required String patientConditionNotes,
    required String assignedHospitalId,
  }) async {
    final userId = supabaseClient.auth.currentUser!.id;
    final data = await supabaseClient
        .from('incidents')
        .insert({
          'reporter_name': reporterName,
          'reporter_phone': reporterPhone,
          'incident_location': 'POINT($longitude $latitude)',
          'location_description': locationDescription,
          'nature_of_emergency': natureOfEmergency,
          'patient_condition_notes': patientConditionNotes,
          'assigned_hospital_id': assignedHospitalId,
          'status': 'logged',
          'created_by': userId,
        })
        .select()
        .single();
    return Incident.fromJson(data);
  }
}
