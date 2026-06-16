class Hospital {
  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String contactPhone;

  const Hospital({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    required this.contactPhone,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    // Supabase returns geography as GeoJSON when using select with geojson cast,
    // or as a WKT string. Handle both cases.
    double? lat, lng;
    final loc = json['location'];
    if (loc is Map<String, dynamic> && loc['coordinates'] is List) {
      final coords = loc['coordinates'] as List;
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }
    return Hospital(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      latitude: lat,
      longitude: lng,
      contactPhone: json['contact_phone'] as String? ?? '',
    );
  }
}
