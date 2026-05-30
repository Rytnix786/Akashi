/// Health Reading model — NDVI reading from Sentinel Hub
library;

class HealthReading {
  final String id;
  final String fieldId;
  final DateTime readingDate;
  final double? ndviMean;
  final double? ndwiMean;
  final double? cloudCover;
  final String? healthStatus; // 'green' | 'yellow' | 'red' | 'unknown'
  final int? pixelCount;
  final DateTime createdAt;

  const HealthReading({
    required this.id,
    required this.fieldId,
    required this.readingDate,
    this.ndviMean,
    this.ndwiMean,
    this.cloudCover,
    this.healthStatus,
    this.pixelCount,
    required this.createdAt,
  });

  factory HealthReading.fromJson(Map<String, dynamic> json) {
    return HealthReading(
      id: json['id'] as String,
      fieldId: json['field_id'] as String,
      readingDate: DateTime.parse(json['reading_date'] as String),
      ndviMean: (json['ndvi_mean'] as num?)?.toDouble(),
      ndwiMean: (json['ndwi_mean'] as num?)?.toDouble(),
      cloudCover: (json['cloud_cover'] as num?)?.toDouble(),
      healthStatus: json['health_status'] as String?,
      pixelCount: json['pixel_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Returns Bengali label for NDVI value (weak/medium/strong)
  String get ndviLabel {
    if (ndviMean == null) return 'অজানা';
    if (ndviMean! >= 0.5) return 'শক্তিশালী';
    if (ndviMean! >= 0.25) return 'মাঝারি';
    return 'দুর্বল';
  }

  /// Returns 0–1 scale for NDVI bar
  double get ndviBarValue => ndviMean != null
      ? (ndviMean!.clamp(-1.0, 1.0) + 1.0) / 2.0
      : 0;
}
