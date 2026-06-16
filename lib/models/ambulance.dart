enum AmbulanceStatus {
  available,
  dispatched,
  enRoute,
  busy,
  offline;

  static AmbulanceStatus fromString(String value) => switch (value) {
    'available' => available,
    'dispatched' => dispatched,
    'en_route' => enRoute,
    'busy' => busy,
    'offline' => offline,
    _ => offline,
  };

  String get dbValue => switch (this) {
    enRoute => 'en_route',
    _ => name,
  };

  String get label => switch (this) {
    available => 'Available',
    dispatched => 'Dispatched',
    enRoute => 'En Route',
    busy => 'Busy',
    offline => 'Offline',
  };
}

class Ambulance {
  final String id;
  final String plateNumber;
  final AmbulanceStatus status;
  final double? latitude;
  final double? longitude;
  final String? driverId;
  final String? hospitalId;
  final DateTime? lastLocationUpdate;

  const Ambulance({
    required this.id,
    required this.plateNumber,
    required this.status,
    this.latitude,
    this.longitude,
    this.driverId,
    this.hospitalId,
    this.lastLocationUpdate,
  });

  factory Ambulance.fromJson(Map<String, dynamic> json) {
    double? lat, lng;
    final loc = json['current_location'];
    if (loc is Map<String, dynamic> && loc['coordinates'] is List) {
      final coords = loc['coordinates'] as List;
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }
    return Ambulance(
      id: json['id'] as String,
      plateNumber: json['plate_number'] as String,
      status: AmbulanceStatus.fromString(json['status'] as String? ?? 'offline'),
      latitude: lat,
      longitude: lng,
      driverId: json['driver_id'] as String?,
      hospitalId: json['hospital_id'] as String?,
      lastLocationUpdate: json['last_location_update'] != null
          ? DateTime.parse(json['last_location_update'] as String)
          : null,
    );
  }
}
