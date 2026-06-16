enum IncidentStatus {
  logged,
  dispatched,
  enRoute,
  arrived,
  completed,
  cancelled;

  static IncidentStatus fromString(String value) => switch (value) {
    'logged' => logged,
    'dispatched' => dispatched,
    'en_route' => enRoute,
    'arrived' => arrived,
    'completed' => completed,
    'cancelled' => cancelled,
    _ => logged,
  };

  String get dbValue => switch (this) {
    enRoute => 'en_route',
    _ => name,
  };

  String get label => switch (this) {
    logged => 'Logged',
    dispatched => 'Dispatched',
    enRoute => 'En Route',
    arrived => 'Arrived',
    completed => 'Completed',
    cancelled => 'Cancelled',
  };

  bool get isActive =>
      this == logged || this == dispatched || this == enRoute || this == arrived;
}

class Incident {
  final String id;
  final String reporterName;
  final String reporterPhone;
  final double? latitude;
  final double? longitude;
  final String locationDescription;
  final String natureOfEmergency;
  final String patientConditionNotes;
  final IncidentStatus status;
  final String? createdBy;
  final String? assignedAmbulanceId;
  final String? assignedHospitalId;
  final DateTime createdAt;
  final DateTime? dispatchedAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;

  const Incident({
    required this.id,
    required this.reporterName,
    required this.reporterPhone,
    this.latitude,
    this.longitude,
    required this.locationDescription,
    required this.natureOfEmergency,
    required this.patientConditionNotes,
    required this.status,
    this.createdBy,
    this.assignedAmbulanceId,
    this.assignedHospitalId,
    required this.createdAt,
    this.dispatchedAt,
    this.arrivedAt,
    this.completedAt,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    double? lat, lng;
    final loc = json['incident_location'];
    if (loc is Map<String, dynamic> && loc['coordinates'] is List) {
      final coords = loc['coordinates'] as List;
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }
    return Incident(
      id: json['id'] as String,
      reporterName: json['reporter_name'] as String? ?? '',
      reporterPhone: json['reporter_phone'] as String? ?? '',
      latitude: lat,
      longitude: lng,
      locationDescription: json['location_description'] as String? ?? '',
      natureOfEmergency: json['nature_of_emergency'] as String? ?? '',
      patientConditionNotes: json['patient_condition_notes'] as String? ?? '',
      status: IncidentStatus.fromString(json['status'] as String? ?? 'logged'),
      createdBy: json['created_by'] as String?,
      assignedAmbulanceId: json['assigned_ambulance_id'] as String?,
      assignedHospitalId: json['assigned_hospital_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      dispatchedAt: json['dispatched_at'] != null
          ? DateTime.parse(json['dispatched_at'] as String)
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}
