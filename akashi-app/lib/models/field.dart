/// Field model — PostGIS polygon stored as GeoJSON in Supabase
library;

class FieldModel {
  final String id;
  final String farmerId;
  final String name;
  final String cropType;
  final String? cropSeason;
  final double? areaAcres;
  final double? areaBigha;
  final List<List<double>>? polygonCoordinates; // [[lon, lat], ...]
  final double? centerLat;
  final double? centerLon;
  final String district;
  final String upazila;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? plantingDate;

  const FieldModel({
    required this.id,
    required this.farmerId,
    required this.name,
    required this.cropType,
    this.cropSeason,
    this.areaAcres,
    this.areaBigha,
    this.polygonCoordinates,
    this.centerLat,
    this.centerLon,
    required this.district,
    required this.upazila,
    required this.isActive,
    required this.createdAt,
    this.plantingDate,
  });

  factory FieldModel.fromJson(Map<String, dynamic> json) {
    // Parse polygon coordinates from PostGIS GeoJSON
    List<List<double>>? coords;
    if (json['polygon'] != null) {
      try {
        final geo = json['polygon'] as Map<String, dynamic>;
        final rawCoords = geo['coordinates'] as List?;
        if (rawCoords != null && rawCoords.isNotEmpty) {
          coords = (rawCoords[0] as List).map((pt) {
            final p = pt as List;
            return [p[0] as double, p[1] as double];
          }).toList();
        }
      } catch (_) {}
    }

    final pDateVal = json['planting_date'];
    final DateTime? pDate = pDateVal != null ? DateTime.parse(pDateVal as String) : null;

    return FieldModel(
      id: json['id'] as String,
      farmerId: json['farmer_id'] as String,
      name: json['name'] as String? ?? 'আমার জমি',
      cropType: json['crop_type'] as String,
      cropSeason: json['crop_season'] as String?,
      areaAcres: (json['area_acres'] as num?)?.toDouble(),
      areaBigha: (json['area_bigha'] as num?)?.toDouble(),
      polygonCoordinates: coords,
      district: json['district'] as String,
      upazila: json['upazila'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      plantingDate: pDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'farmer_id': farmerId,
    'name': name,
    'crop_type': cropType,
    'crop_season': cropSeason,
    'area_acres': areaAcres,
    'area_bigha': areaBigha,
    'district': district,
    'upazila': upazila,
    'is_active': isActive,
    'planting_date': plantingDate?.toIso8601String().split('T')[0],
  };
}
