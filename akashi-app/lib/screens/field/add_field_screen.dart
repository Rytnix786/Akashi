/// Screen 7: Add Field Screen (Map-based polygon drawing)
/// - OpenStreetMap tile base
/// - Tap to add polygon points (minimum 3)
/// - Area calculated in acres + bigha
/// - Crop type + season + name inputs
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/l10n/bn_strings.dart';
import '../../core/config/app_config.dart';
import '../../providers/field_provider.dart';
import '../../providers/farmer_provider.dart';
import '../../providers/offline_sync_provider.dart';

class AddFieldScreen extends StatefulWidget {
  const AddFieldScreen({super.key});

  @override
  State<AddFieldScreen> createState() => _AddFieldScreenState();
}

class _AddFieldScreenState extends State<AddFieldScreen> {
  final _mapController = MapController();
  final _nameController = TextEditingController();

  List<LatLng> _points = [];
  bool _isLoading = false;
  String _selectedCropType = BnStrings.cropRice;
  String _selectedSeason = BnStrings.seasonBoro;
  DateTime? _selectedPlantingDate;

  Future<void> _selectPlantingDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('bn', 'BD'),
    );
    if (picked != null) {
      setState(() {
        _selectedPlantingDate = picked;
      });
    }
  }

  // Bangladesh center default
  LatLng _currentCenter = const LatLng(
    AppConfig.bangladeshLat,
    AppConfig.bangladeshLon,
  );

  @override
  void initState() {
    super.initState();
    _nameController.text = BnStrings.defaultFieldName;
    _locateMe();
  }

  Future<void> _locateMe() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _currentCenter = LatLng(pos.latitude, pos.longitude);
        });
        _mapController.move(_currentCenter, AppConfig.defaultMapZoom);
      }
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void _addPoint(TapPosition tapPos, LatLng point) {
    setState(() => _points.add(point));
  }

  void _undoLastPoint() {
    if (_points.isNotEmpty) {
      setState(() => _points.removeLast());
    }
  }

  /// Shoelace formula for polygon area in square meters
  double _calculateAreaM2() {
    if (_points.length < 3) return 0;
    double area = 0;
    final n = _points.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final lat1 = _points[i].latitude * (3.14159265359 / 180);
      final lat2 = _points[j].latitude * (3.14159265359 / 180);
      final lon1 = _points[i].longitude * (3.14159265359 / 180);
      final lon2 = _points[j].longitude * (3.14159265359 / 180);
      area += (lon2 - lon1) * (2 + (lat1).abs().clamp(0, 1) + (lat2).abs().clamp(0, 1));
    }
    return (area.abs() / 4) * 40680631590769; // Approximation in m²
  }

  Future<void> _saveField() async {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(BnStrings.minPointsRequired),
          backgroundColor: AkashiColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final farmer = context.read<FarmerProvider>().farmer;
    final offlineSync = context.read<OfflineSyncProvider>();

    try {
      final areaM2 = _calculateAreaM2();
      final areaAcres = areaM2 / 4046.86;
      final areaBigha = AppConfig.acresToBigha(areaAcres);

      // Build polygon coords as [[lon, lat], ...] and close the ring
      final coords = [
        ..._points.map((p) => [p.longitude, p.latitude]),
        [_points[0].longitude, _points[0].latitude], // Close ring
      ];

      if (!offlineSync.isOnline) {
        await offlineSync.queueFieldRegistration(
          name: _nameController.text.trim(),
          cropType: _selectedCropType,
          cropSeason: _selectedSeason,
          polygonCoords: coords,
          areaAcres: areaAcres,
          areaBigha: areaBigha,
          district: farmer?.district ?? '',
          upazila: farmer?.upazila ?? '',
          plantingDate: _selectedPlantingDate,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ইন্টারনেট সংযোগ নেই। সংযোগ ফিরলে স্বয়ংক্রিয়ভাবে সংরক্ষিত হবে।"),
            backgroundColor: AkashiColors.tertiary,
          ),
        );
      } else {
        await context.read<FieldProvider>().createField(
          name: _nameController.text.trim(),
          cropType: _selectedCropType,
          cropSeason: _selectedSeason,
          polygonCoords: coords,
          areaAcres: areaAcres,
          areaBigha: areaBigha,
          district: farmer?.district ?? '',
          upazila: farmer?.upazila ?? '',
          plantingDate: _selectedPlantingDate,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(BnStrings.genericError),
          backgroundColor: AkashiColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areaAcres = _calculateAreaM2() / 4046.86;
    final areaBigha = AppConfig.acresToBigha(areaAcres);

    return Scaffold(
      backgroundColor: AkashiColors.background,
      appBar: AppBar(
        backgroundColor: AkashiColors.surfaceContainerHigh,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AkashiColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          BnStrings.addFieldTitle,
          style: AkashiTextTheme.headlineMd.copyWith(
            color: AkashiColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_points.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo, color: AkashiColors.primary),
              onPressed: _undoLastPoint,
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Map with tap-to-add polygon ──────────────────────────────
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter,
                    initialZoom: AppConfig.defaultMapZoom,
                    onTap: _addPoint,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    if (_points.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _points,
                            color: AkashiColors.primary.withValues(alpha: 0.35),
                            borderColor: AkashiColors.primaryFixedDim,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: _points.asMap().entries.map((e) {
                        return Marker(
                          point: e.value,
                          width: 24,
                          height: 24,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AkashiColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${e.key + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Instruction overlay
                if (_points.isEmpty)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AkashiColors.surfaceContainerLowest
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        BnStrings.tapToAddPoints,
                        style: AkashiTextTheme.bodyMd.copyWith(
                          color: AkashiColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // Area badge
                if (_points.length >= 3)
                  Positioned(
                    top: 12,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AkashiColors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${areaBigha.toStringAsFixed(2)} ${BnStrings.bigha}',
                        style: AkashiTextTheme.labelLg.copyWith(
                          color: AkashiColors.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                // My location FAB
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    onPressed: _locateMe,
                    backgroundColor: AkashiColors.surfaceContainerLowest,
                    child: const Icon(
                      Icons.my_location,
                      color: AkashiColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Field details form ────────────────────────────────────────
          Expanded(
            flex: 1,
            child: Container(
              color: AkashiColors.surfaceContainerLowest,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Field name
                    TextField(
                      controller: _nameController,
                      style: AkashiTextTheme.bodyLg,
                      decoration: InputDecoration(
                        labelText: BnStrings.fieldName,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AkashiColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Crop + Season row
                    Row(
                      children: [
                        Expanded(
                          child: _ChipSelector(
                            label: BnStrings.cropType,
                            items: BnStrings.cropTypes,
                            selected: _selectedCropType,
                            onSelected: (v) =>
                                setState(() => _selectedCropType = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ChipSelector(
                            label: BnStrings.cropSeason,
                            items: BnStrings.seasons,
                            selected: _selectedSeason,
                            onSelected: (v) =>
                                setState(() => _selectedSeason = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Planting Date Picker (Optional)
                    InkWell(
                      onTap: () => _selectPlantingDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AkashiColors.outlineVariant),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, color: AkashiColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedPlantingDate == null
                                      ? "রোপণের তারিখ (ঐচ্ছিক)"
                                      : "রোপণের তারিখ: ${_selectedPlantingDate!.year}-${_selectedPlantingDate!.month.toString().padLeft(2, '0')}-${_selectedPlantingDate!.day.toString().padLeft(2, '0')}",
                                  style: AkashiTextTheme.bodyLg.copyWith(
                                    color: _selectedPlantingDate == null
                                        ? AkashiColors.onSurfaceVariant
                                        : AkashiColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedPlantingDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _selectedPlantingDate = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _saveField,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          BnStrings.saveField,
                          style: AkashiTextTheme.titleLg.copyWith(
                            color: AkashiColors.onPrimary,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AkashiColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini chip selector for crop type / season
class _ChipSelector extends StatelessWidget {
  final String label;
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ChipSelector({
    required this.label,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AkashiTextTheme.labelLgMuted),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selected,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AkashiColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: AkashiColors.outlineVariant),
            ),
            isDense: true,
          ),
          style: AkashiTextTheme.bodyMd,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onSelected(v);
          },
        ),
      ],
    );
  }
}
