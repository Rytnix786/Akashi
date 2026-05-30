/// FieldProvider — manages fields and their NDVI health readings
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/field.dart';
import '../models/health_reading.dart';

class FieldProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<FieldModel> _fields = [];
  Map<String, List<HealthReading>> _readingsByField = {};
  bool _isLoading = false;
  String? _error;

  List<FieldModel> get fields => _fields;
  bool get isLoading => _isLoading;
  String? get error => _error;

  HealthReading? getLatestReading(String fieldId) {
    final readings = _readingsByField[fieldId];
    if (readings == null || readings.isEmpty) return null;
    return readings.first; // Already ordered by date DESC from DB
  }

  List<HealthReading> getReadings(String fieldId) =>
      _readingsByField[fieldId] ?? [];

  Future<void> loadFields() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load fields
      final fieldsData = await _supabase
          .from('fields')
          .select()
          .eq('farmer_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      _fields = (fieldsData as List)
          .map((d) => FieldModel.fromJson(d as Map<String, dynamic>))
          .toList();

      // Load latest 5 readings per field (for history dots)
      if (_fields.isNotEmpty) {
        final fieldIds = _fields.map((f) => f.id).toList();
        final readingsData = await _supabase
            .from('health_readings')
            .select()
            .inFilter('field_id', fieldIds)
            .order('reading_date', ascending: false)
            .limit(50); // Max 10 readings per field × 5 fields

        _readingsByField = {};
        for (final rd in readingsData as List) {
          final reading =
              HealthReading.fromJson(rd as Map<String, dynamic>);
          _readingsByField
              .putIfAbsent(reading.fieldId, () => [])
              .add(reading);
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('FieldProvider.loadFields error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createField({
    required String name,
    required String cropType,
    required String? cropSeason,
    required List<List<double>> polygonCoords, // [[lon, lat], ...]
    required double areaAcres,
    required double areaBigha,
    required String district,
    required String upazila,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Build GeoJSON polygon
    final geoJson = {
      'type': 'Polygon',
      'coordinates': [polygonCoords],
    };

    // Calculate center point
    final centerLon = polygonCoords.map((p) => p[0]).reduce((a, b) => a + b) /
        polygonCoords.length;
    final centerLat = polygonCoords.map((p) => p[1]).reduce((a, b) => a + b) /
        polygonCoords.length;

    await _supabase.from('fields').insert({
      'farmer_id': userId,
      'name': name,
      'crop_type': cropType,
      'crop_season': cropSeason,
      'area_acres': areaAcres,
      'area_bigha': areaBigha,
      'polygon': geoJson,
      'center_point': {
        'type': 'Point',
        'coordinates': [centerLon, centerLat],
      },
      'district': district,
      'upazila': upazila,
    });

    await loadFields(); // Refresh
  }
}
