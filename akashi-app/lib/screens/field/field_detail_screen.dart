/// Screen 6: Field Detail Screen
/// Design: Stitch field_detail_farmer_view.html
/// - Map with polygon overlay
/// - Status card with NDVI value
/// - 7-day history dots
/// - Weather notice + recommendation card
/// - Soil metrics grid
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final readings = context.watch<FieldProvider>().getReadings(field.id);
    final latestReading = readings.isNotEmpty ? readings.first : null;
    final status = latestReading?.healthStatus ?? 'unknown';
    final weather = context.watch<WeatherProvider>().weather;
    final highRain = context.watch<WeatherProvider>().highRainWarning;

    return Scaffold(
      backgroundColor: AkashiColors.background,
      // ── AppBar ───────────────────────────────────────────────────────────
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

      // ── FAB — Add Reading / Refresh ───────────────────────────────────────
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
          // ── 1: Satellite / Map View ─────────────────────────────────────
          _MapSection(field: field),
          const SizedBox(height: 16),

          // ── 2: Health Status Card ───────────────────────────────────────
          _StatusCard(reading: latestReading, status: status),
          const SizedBox(height: 16),

          // ── 3: 7-day History Dots ───────────────────────────────────────
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
    // Determine map center
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
                        color: AkashiColors.primary.withValues(alpha: 0.4),
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
            color: AkashiColors.primary.withValues(alpha: 0.3),
          ),
          child: const Center(
            child: Icon(Icons.map, size: 48, color: Colors.white),
          ),
        ),
        // Zoom controls overlay
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
            color: Colors.black.withValues(alpha: 0.1),
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
    final ndviPercent = ndvi != null
        ? '${(ndvi.clamp(0, 1) * 100).round()}%'
        : '–';

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
            color: Colors.black.withValues(alpha: 0.04),
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
                  BnStrings.cropHealthGood,
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

// ── History Dots ──────────────────────────────────────────────────────────────
class _HistoryDotsSection extends StatelessWidget {
  final List<HealthReading> readings;

  const _HistoryDotsSection({required this.readings});

  @override
  Widget build(BuildContext context) {
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
          Text(
            BnStrings.history7Days,
            style: AkashiTextTheme.labelLgUppercase,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final isToday = i == 6;
              final hasReading = i < readings.length;
              final reading = hasReading ? readings[i] : null;
              final status = reading?.healthStatus ?? 'unknown';

              return Column(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _dotColor(status, hasReading),
                      border: isToday
                          ? Border.all(
                              color: AkashiColors.primaryFixedDim,
                              width: 2,
                            )
                          : null,
                      boxShadow: isToday
                          ? [
                              BoxShadow(
                                color: AkashiColors.primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    BnStrings.weekDays[i],
                    style: AkashiTextTheme.labelLg.copyWith(
                      color: isToday
                          ? AkashiColors.primary
                          : AkashiColors.onSurfaceVariant,
                      fontWeight: isToday
                          ? FontWeight.w700
                          : FontWeight.w400,
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
                  AkashiColors.onSecondaryContainer.withValues(alpha: 0.1),
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
          color: AkashiColors.tertiaryContainer.withValues(alpha: 0.2),
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


