import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/l10n/bn_strings.dart';
import '../../models/field.dart';
import '../../models/health_reading.dart';
import '../../providers/field_provider.dart';
import '../../providers/weather_provider.dart';
import '../../core/config/app_config.dart';

class FieldDetailScreen extends StatelessWidget {
  final FieldModel field;

  const FieldDetailScreen({super.key, required this.field});

  // Calculate dynamic growth stage based on planting date
  // Boro rice variety standard duration is 120 days in Bangladesh
  Map<String, dynamic> _calculateGrowthStage() {
    final plantingDate = field.plantingDate ?? field.createdAt;
    final bool isEstimated = field.plantingDate == null;
    final totalDurationDays = 120;
    final elapsedDays = DateTime.now().difference(plantingDate).inDays;
    final double progress = (elapsedDays / totalDurationDays).clamp(0.0, 1.0);

    String stageName = "অঙ্কুরোদগম পর্যায়";
    String details = "চারা রোপণের প্রারম্ভিক সময়";
    IconData icon = Icons.spa;

    if (progress >= 0.0 && progress < 0.20) {
      stageName = "চারা পর্যায় (Seedling Stage)";
      details = "রোপণ সম্পন্ন হয়েছে, চারা বৃদ্ধির প্রাথমিক পর্যায়";
      icon = Icons.spa;
    } else if (progress >= 0.20 && progress < 0.50) {
      stageName = "কুশি গজানো পর্যায় (Tillering Stage)";
      details = "কুশি বৃদ্ধির সঠিক সময়, পর্যাপ্ত পটাশ ও ইউরিয়া সার প্রয়োজন";
      icon = Icons.grass;
    } else if (progress >= 0.50 && progress < 0.80) {
      stageName = "ফুল আসা ও দুধ পর্যায় (Flowering Stage)";
      details = "ধানের শীষ গজানো ও ফুল আসার পর্যায়, জমিতে পর্যাপ্ত সেচ রাখুন";
      icon = Icons.grain;
    } else if (progress >= 0.80 && progress < 1.0) {
      stageName = "পাকা পর্যায় (Maturation Stage)";
      details = "ধান পাকার শেষ ধাপ, ফসল কাটার প্রস্তুতি নিন";
      icon = Icons.agriculture;
    } else {
      stageName = "ফসল সংগ্রহ সম্পন্ন (Harvested)";
      details = "ধান কেটে ঘরে তোলার কাজ শেষ হয়েছে";
      icon = Icons.inventory;
    }

    return {
      'stage': stageName,
      'details': details,
      'icon': icon,
      'progress': progress,
      'days': elapsedDays,
      'isEstimated': isEstimated,
    };
  }

  // Fetch flood risk from backend API
  Future<Map<String, dynamic>?> _fetchFloodRisk(String fieldId) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));
      final response = await dio.get('/fields/$fieldId/flood-risk');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
    } catch (e) {
      debugPrint("Failed to fetch flood risk: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final readings = context.watch<FieldProvider>().getReadings(field.id);
    final latestReading = readings.isNotEmpty ? readings.first : null;
    final status = latestReading?.healthStatus ?? 'unknown';
    final weather = context.watch<WeatherProvider>().weather;
    final highRain = context.watch<WeatherProvider>().highRainWarning;

    final growth = _calculateGrowthStage();

    // Mock Sentinel-1 GRD SAR trigger if cloud cover > 60%
    final bool wasSarUsed = (latestReading?.cloudCover ?? 0.0) > 60.0;

    return Scaffold(
      backgroundColor: AkashiColors.background,
      appBar: AppBar(
        backgroundColor: AkashiColors.surfaceContainerHigh,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AkashiColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          field.name,
          style: AkashiTextTheme.headlineMd.copyWith(
            color: AkashiColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.agriculture, color: AkashiColors.primary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.read<FieldProvider>().loadFields();
        },
        backgroundColor: AkashiColors.primary,
        foregroundColor: AkashiColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.refresh),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── FLOOD ALERTS BANNER ───────────────────────────────────────────
          FutureBuilder<Map<String, dynamic>?>(
            future: _fetchFloodRisk(field.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData &&
                  snapshot.data != null) {
                final flood = snapshot.data!;
                final riskStatus = flood['status'] ?? 'green';
                if (riskStatus != 'green') {
                  final isWarning = riskStatus == 'warning';
                  final Color color = isWarning ? Colors.orange.shade800 : Colors.red.shade800;
                  final String badge = isWarning ? 'বন্যা সতর্কতা (Warning)' : 'বন্যা বিপদসীমা অতিক্রম (Critical)';
                  final String message = flood['message'] ?? '';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: color, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                badge,
                                style: TextStyle(
                                  fontFamily: "NotoSansBengali",
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: const TextStyle(
                                  fontFamily: "NotoSansBengali",
                                  color: Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),

          // ── 1: Satellite / Map View ─────────────────────────────────────
          _MapSection(field: field),
          const SizedBox(height: 16),

          // ── Sentinel-1 SAR Badge ──────────────────────────────────────────
          if (wasSarUsed)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.radar, color: Colors.blue.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Data source: Sentinel-1 SAR (মেঘলা আবহাওয়ার কারণে রাডার প্রযুক্তিতে বিশ্লেষণ সম্পন্ন হয়েছে)",
                      style: TextStyle(
                        fontFamily: "NotoSansBengali",
                        color: Colors.blue.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── 2: Health Status Card ───────────────────────────────────────
          _StatusCard(reading: latestReading, status: status),
          const SizedBox(height: 16),

          // ── Crop Growth Stage Indicator Section ───────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AkashiColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "ফসলের জীবনকাল ও বৃদ্ধি পর্যায় (Growth Stage)",
                      style: TextStyle(
                        fontFamily: "NotoSansBengali",
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (growth['isEstimated'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AkashiColors.tertiaryFixed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "আনুমানিক বৃদ্ধির পর্যায়",
                          style: AkashiTextTheme.labelLg.copyWith(
                            color: AkashiColors.onTertiaryFixed,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(growth['icon'], color: Colors.green.shade800, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            growth['stage'],
                            style: const TextStyle(
                              fontFamily: "NotoSansBengali",
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            growth['details'],
                            style: const TextStyle(
                              fontFamily: "NotoSansBengali",
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Slider timeline bar
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: growth['progress'],
                      backgroundColor: Colors.grey.shade100,
                      color: Colors.green.shade600,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("রোপণ (Day 0)", style: TextStyle(fontFamily: "NotoSansBengali", fontSize: 11, color: Colors.grey)),
                        Text("অতিক্রান্ত: ${growth['days']} দিন", style: const TextStyle(fontFamily: "NotoSansBengali", fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                        const Text("কাটা (Day 120)", style: TextStyle(fontFamily: "NotoSansBengali", fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3: Last 5 readings timeline dots ──────────────────────────────
          _HistoryDotsSection(readings: readings),
          const SizedBox(height: 16),

          // ── 4: Weather Notice ───────────────────────────────────────────
          _WeatherNoticeCard(highRain: highRain),
          const SizedBox(height: 12),

          // ── 5: AI Recommendation ────────────────────────────────────────
          _RecommendationCard(
            status: status,
            highRain: highRain,
            ndvi: latestReading?.ndviMean,
          ),
          const SizedBox(height: 16),

          // ── 6: Soil Metrics ─────────────────────────────────────────────
          _SoilMetricsGrid(reading: latestReading),
        ],
      ),
    );
  }
}

// ── Map Section ───────────────────────────────────────────────────────────────
class _MapSection extends StatelessWidget {
  final FieldModel field;

  const _MapSection({required this.field});

  @override
  Widget build(BuildContext context) {
    final centerLat = field.centerLat ?? AppConfig.bangladeshLat;
    final centerLon = field.centerLon ?? AppConfig.bangladeshLon;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 256,
        child: field.polygonCoordinates != null
            ? FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(centerLat, centerLon),
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: field.polygonCoordinates!
                            .map((p) => LatLng(p[1], p[0]))
                            .toList(),
                        color: AkashiColors.primary.withOpacity(0.4),
                        borderColor: AkashiColors.primaryFixedDim,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                ],
              )
            : _FallbackMapImage(),
      ),
    );
  }
}

class _FallbackMapImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600&q=75',
          fit: BoxFit.cover,
        ),
        Container(
          decoration: BoxDecoration(
            color: AkashiColors.primary.withOpacity(0.3),
          ),
          child: const Center(
            child: Icon(Icons.map, size: 48, color: Colors.white),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              _MapControl(icon: Icons.add),
              const SizedBox(height: 8),
              _MapControl(icon: Icons.remove),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapControl extends StatelessWidget {
  final IconData icon;
  const _MapControl({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AkashiColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Icon(icon, color: AkashiColors.primary),
    );
  }
}

// ── Status Card ───────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final HealthReading? reading;
  final String status;

  const _StatusCard({required this.reading, required this.status});

  @override
  Widget build(BuildContext context) {
    final ndvi = reading?.ndviMean;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AkashiColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: _borderColor(status),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AkashiColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco,
              color: AkashiColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BnStrings.currentStatus,
                  style: AkashiTextTheme.labelLgUppercase,
                ),
                Text(
                  status == 'green' 
                      ? BnStrings.cropHealthGood 
                      : (status == 'yellow' ? 'ফসল মাঝারি ঝুঁকিতে' : (status == 'red' ? 'ফসল মারাত্মক ঝুঁকিতে' : 'অজানা অবস্থা')),
                  style: AkashiTextTheme.titleLg.copyWith(
                    color: AkashiColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ndvi != null ? ndvi.toStringAsFixed(2) : '–',
                style: AkashiTextTheme.headlineMd.copyWith(
                  color: AkashiColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                BnStrings.ndviLabel,
                style: AkashiTextTheme.labelLgMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _borderColor(String status) {
    switch (status) {
      case 'green':
        return AkashiColors.primary;
      case 'yellow':
        return AkashiColors.tertiaryContainer;
      case 'red':
        return AkashiColors.error;
      default:
        return AkashiColors.outline;
    }
  }
}

// ── Last 5 Health Readings Timeline Dots ───────────────────────────────────────
class _HistoryDotsSection extends StatelessWidget {
  final List<HealthReading> readings;

  const _HistoryDotsSection({required this.readings});

  @override
  Widget build(BuildContext context) {
    // Show maximum 5 timeline dots corresponding to latest 5 readings
    final int maxDots = 5;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AkashiColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AkashiColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "সর্বশেষ ৫টি পর্যবেক্ষণ টাইমলাইন (Health History)",
            style: TextStyle(
              fontFamily: "NotoSansBengali",
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(maxDots, (i) {
              final hasReading = i < readings.length;
              final reading = hasReading ? readings[i] : null;
              final status = reading?.healthStatus ?? 'unknown';
              
              String dateText = "–";
              if (hasReading && reading != null) {
                // Format date as e.g. "25 May"
                dateText = DateFormat('d MMM').format(reading.readingDate);
              }

              return Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _dotColor(status, hasReading),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: hasReading 
                        ? Center(
                            child: Text(
                              "${i + 1}",
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontFamily: "NotoSansBengali",
                      color: Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _dotColor(String status, bool hasReading) {
    if (!hasReading) return AkashiColors.surfaceContainerHigh;
    switch (status) {
      case 'green':
        return Colors.green.shade600;
      case 'yellow':
        return Colors.orange.shade500;
      case 'red':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade400;
    }
  }
}

// ── Weather Notice Card ────────────────────────────────────────────────────────
class _WeatherNoticeCard extends StatelessWidget {
  final bool highRain;

  const _WeatherNoticeCard({required this.highRain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AkashiColors.secondaryFixed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  AkashiColors.onSecondaryContainer.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cloud,
              color: AkashiColors.onSecondaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BnStrings.weatherAlert,
                  style: AkashiTextTheme.labelLgMuted,
                ),
                Text(
                  highRain
                      ? 'পরবর্তী ৩ দিন বৃষ্টির সম্ভাবনা বেশি'
                      : 'আকাশ মেঘাচ্ছন্ন থাকতে পারে',
                  style: AkashiTextTheme.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AkashiColors.onSecondaryFixed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recommendation Card ───────────────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  final String status;
  final bool highRain;
  final double? ndvi;

  const _RecommendationCard({
    required this.status,
    required this.highRain,
    this.ndvi,
  });

  String get _recommendationText {
    if (highRain) return BnStrings.rainWarning;
    switch (status) {
      case 'green':
        return 'আগামীকাল সার দেওয়ার সঠিক সময়। ফসলের অবস্থা ভালো।';
      case 'yellow':
        return 'সেচ প্রদান করুন এবং ৩ দিনের মধ্যে পুনরায় পর্যবেক্ষণ করুন।';
      case 'red':
        return 'জরুরি ভিত্তিতে কৃষি সম্প্রসারণ কর্মকর্তার সাথে যোগাযোগ করুন।';
      default:
        return BnStrings.noRainAdvice;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AkashiColors.tertiaryFixed,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AkashiColors.tertiaryContainer.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AkashiColors.tertiaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.tips_and_updates,
              color: AkashiColors.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BnStrings.specialAdvice,
                  style: AkashiTextTheme.labelLgMuted,
                ),
                Text(
                  _recommendationText,
                  style: AkashiTextTheme.bodyLg.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AkashiColors.onTertiaryFixed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Soil Metrics Grid ─────────────────────────────────────────────────────────
class _SoilMetricsGrid extends StatelessWidget {
  final HealthReading? reading;

  const _SoilMetricsGrid({this.reading});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          BnStrings.soilNutrients,
          style: AkashiTextTheme.labelLgUppercase,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AkashiColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: BnStrings.humidity,
                  value: reading?.ndwiMean != null
                      ? '${(reading!.ndwiMean! * 100).round()}%'
                      : '৬৫%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: BnStrings.nitrogen,
                  value: BnStrings.nitrogenMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AkashiColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AkashiTextTheme.labelLgMuted),
          const SizedBox(height: 4),
          Text(
            value,
            style: AkashiTextTheme.titleLg.copyWith(
              color: AkashiColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
