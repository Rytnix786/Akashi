import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'field_provider.dart';

class OfflineQueueItem {
  final String id;
  final String name;
  final String cropType;
  final String? cropSeason;
  final List<List<double>> polygonCoords;
  final double areaAcres;
  final double areaBigha;
  final String district;
  final String upazila;
  final DateTime timestamp;
  final DateTime? plantingDate;

  OfflineQueueItem({
    required this.id,
    required this.name,
    required this.cropType,
    this.cropSeason,
    required this.polygonCoords,
    required this.areaAcres,
    required this.areaBigha,
    required this.district,
    required this.upazila,
    required this.timestamp,
    this.plantingDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'crop_type': cropType,
        'crop_season': cropSeason,
        'polygon_coords': polygonCoords,
        'area_acres': areaAcres,
        'area_bigha': areaBigha,
        'district': district,
        'upazila': upazila,
        'timestamp': timestamp.toIso8601String(),
        'planting_date': plantingDate?.toIso8601String(),
      };

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) => OfflineQueueItem(
        id: json['id'] as String,
        name: json['name'] as String,
        cropType: json['crop_type'] as String,
        cropSeason: json['crop_season'] as String?,
        polygonCoords: (json['polygon_coords'] as List)
            .map((item) => (item as List).map((val) => (val as num).toDouble()).toList())
            .toList(),
        areaAcres: (json['area_acres'] as num).toDouble(),
        areaBigha: (json['area_bigha'] as num).toDouble(),
        district: json['district'] as String,
        upazila: json['upazila'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        plantingDate: json['planting_date'] != null ? DateTime.parse(json['planting_date'] as String) : null,
      );
}

class OfflineSyncProvider extends ChangeNotifier {
  FieldProvider? _fieldProvider;
  bool _isOnline = true;
  DateTime? _lastSyncTime;
  List<OfflineQueueItem> _fieldQueue = [];
  bool _isSyncing = false;

  bool get isOnline => _isOnline;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<OfflineQueueItem> get fieldQueue => _fieldQueue;
  bool get isSyncing => _isSyncing;

  void setFieldProvider(FieldProvider provider) {
    _fieldProvider = provider;
  }

  OfflineSyncProvider() {
    _loadSyncMetadata();
    _startPeriodicConnectionCheck();
  }

  // Load cache states and transaction queue
  Future<void> _loadSyncMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load last sync time
      final lastSyncStr = prefs.getString('offline_last_sync_time');
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncStr);
      }

      // Load queued field registrations
      final queueJson = prefs.getString('offline_registration_queue');
      if (queueJson != null) {
        final List decoded = json.decode(queueJson);
        _fieldQueue = decoded.map((item) => OfflineQueueItem.fromJson(item)).toList();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to load offline sync meta: $e");
    }
  }

  // Save transaction queue to persistence SharedPreferences
  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = json.encode(_fieldQueue.map((item) => item.toJson()).toList());
      await prefs.setString('offline_registration_queue', queueJson);
    } catch (e) {
      debugPrint("Failed to save offline queue: $e");
    }
  }

  // Direct DNS check to avoid captive portal false positives
  Future<void> checkConnection() async {
    bool previousState = _isOnline;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      _isOnline = false;
    }

    if (previousState != _isOnline) {
      notifyListeners();
      if (_isOnline) {
        // Trigger auto-retry of queued operations on reconnect!
        debugPrint("Connection restored. Flushing queued registrations.");
        if (_fieldProvider != null) {
          flushQueue(_fieldProvider!);
        }
      }
    }
  }

  void _startPeriodicConnectionCheck() {
    // Check connection status every 15 seconds
    Future.doWhile(() async {
      await checkConnection();
      await Future.delayed(const Duration(seconds: 15));
      return true; // Keep looping
    });
  }

  // Cache response payloads locally
  Future<void> cacheResponse(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_$key', json.encode(data));
      
      _lastSyncTime = DateTime.now();
      await prefs.setString('offline_last_sync_time', _lastSyncTime!.toIso8601String());
      
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to cache API response: $e");
    }
  }

  // Retrieve local cached response
  Future<Map<String, dynamic>?> getCachedResponse(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cache_$key');
      if (cachedStr != null) {
        return json.decode(cachedStr) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Failed to read cached API response: $e");
    }
    return null;
  }

  // Queue a field registration when offline
  Future<void> queueFieldRegistration({
    required String name,
    required String cropType,
    required String? cropSeason,
    required List<List<double>> polygonCoords,
    required double areaAcres,
    required double areaBigha,
    required String district,
    required String upazila,
    DateTime? plantingDate,
  }) async {
    final newItem = OfflineQueueItem(
      id: 'queued-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      cropType: cropType,
      cropSeason: cropSeason,
      polygonCoords: polygonCoords,
      areaAcres: areaAcres,
      areaBigha: areaBigha,
      district: district,
      upazila: upazila,
      timestamp: DateTime.now(),
      plantingDate: plantingDate,
    );

    _fieldQueue.add(newItem);
    await _saveQueue();
    notifyListeners();
    
    debugPrint("Field registration queued locally: ${newItem.name}");
  }

  // Flush the queue and sync with the remote database on reconnect
  Future<void> flushQueue(FieldProvider fieldProvider) async {
    if (!_isOnline || _fieldQueue.isEmpty || _isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    List<OfflineQueueItem> failedItems = [];

    for (final item in _fieldQueue) {
      try {
        await fieldProvider.createField(
          name: item.name,
          cropType: item.cropType,
          cropSeason: item.cropSeason,
          polygonCoords: item.polygonCoords,
          areaAcres: item.areaAcres,
          areaBigha: item.areaBigha,
          district: item.district,
          upazila: item.upazila,
          plantingDate: item.plantingDate,
        );
        debugPrint("Successfully synchronized queued field: ${item.name}");
      } catch (e) {
        debugPrint("Failed to sync queued field ${item.name}: $e. Keeping in queue.");
        failedItems.add(item);
      }
    }

    _fieldQueue = failedItems;
    await _saveQueue();
    _isSyncing = false;
    notifyListeners();
  }
}
