import '../models/ambulance.dart';
import 'supabase_service.dart';

class AmbulanceService {
  Future<List<Ambulance>> fetchAllAmbulances() async {
    final data = await supabaseClient.from('ambulances').select(
      'id, plate_number, status, driver_id, hospital_id, last_location_update,'
      ' ST_X(current_location::geometry) as longitude,'
      ' ST_Y(current_location::geometry) as latitude',
    );
    return (data as List).map((e) => Ambulance.fromJson(e as Map<String, dynamic>)).toList();
  }
}
