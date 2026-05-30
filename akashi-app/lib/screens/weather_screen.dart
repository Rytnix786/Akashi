/// Screen 8: Weather Screen
/// Design: Stitch farmer_weather_forecast.html
/// - Large current weather hero card (secondary-container)
/// - 7-day horizontal scroll forecast
/// - Farming advice card (primary-container)
/// - Wind + Humidity metrics grid
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/colors.dart';
import '../core/theme/typography.dart';
import '../core/l10n/bn_strings.dart';
import '../providers/weather_provider.dart';

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeatherProvider>();
    final weather = provider.weather;
    final highRain = provider.highRainWarning;

    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: AkashiColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AkashiColors.primary),
        ),
      );
    }

    final tempC = weather?.tempC ?? 30;
    final humidity = weather?.humidity ?? 65;
    final wind = weather?.windKmh ?? 12;
    final rainChance = weather?.rainChance ?? 10;
    final condition = weather?.condition ?? 'আংশিক মেঘলা';
    final icon = weather?.conditionIcon ?? 'partly_cloudy_day';

    return Scaffold(
      backgroundColor: AkashiColors.background,
      appBar: AppBar(
        backgroundColor: AkashiColors.surfaceContainerHigh,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AkashiColors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.agriculture,
                  size: 18, color: AkashiColors.onPrimaryContainer),
            ),
            const SizedBox(width: 8),
            Text(
              BnStrings.appName,
              style: AkashiTextTheme.headlineMd.copyWith(
                color: AkashiColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AkashiColors.primary,
        onRefresh: () => context.read<WeatherProvider>().loadWeather(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Screen title
            Text(
              BnStrings.weatherTitle,
              style: AkashiTextTheme.headlineLgMobile,
            ),
            const SizedBox(height: 16),

            // ── Current Weather Hero Card ─────────────────────────────
            _CurrentWeatherCard(
              tempC: tempC,
              humidity: humidity,
              wind: wind,
              rainChance: rainChance,
              condition: condition,
              icon: icon,
            ),
            const SizedBox(height: 16),

            // ── Farming Advice ────────────────────────────────────────
            _FarmingAdviceCard(highRain: highRain),
            const SizedBox(height: 24),

            // ── 7-day Forecast ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(BnStrings.forecast7Day, style: AkashiTextTheme.titleLg),
                const Icon(Icons.calendar_month,
                    color: AkashiColors.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 12),
            _ForecastRow(forecasts: weather?.forecast ?? []),
            const SizedBox(height: 24),

            // ── Metrics Grid ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.air,
                    label: BnStrings.wind,
                    value:
                        '${wind.round()} ${BnStrings.windUnit}',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.water_drop,
                    label: BnStrings.humidity,
                    value:
                        '${BnStrings.toBengaliNumeral(humidity.round())}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Farm area image ───────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600&q=75',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: AkashiColors.surfaceContainer,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          BnStrings.yourFarmArea,
                          style: AkashiTextTheme.labelLg.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          condition,
                          style: AkashiTextTheme.titleLg.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Current Weather Hero ──────────────────────────────────────────────────────
class _CurrentWeatherCard extends StatelessWidget {
  final double tempC;
  final double humidity;
  final double wind;
  final double rainChance;
  final String condition;
  final String icon;

  const _CurrentWeatherCard({
    required this.tempC,
    required this.humidity,
    required this.wind,
    required this.rainChance,
    required this.condition,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AkashiColors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AkashiColors.outlineVariant),
      ),
      child: Stack(
        children: [
          // Background blur element
          Positioned(
            bottom: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Temp + rain
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      BnStrings.currentWeather,
                      style: AkashiTextTheme.titleLg.copyWith(
                        color: AkashiColors.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${BnStrings.toBengaliNumeral(tempC.round())}',
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w700,
                            color: AkashiColors.onSecondaryContainer,
                            height: 1,
                          ),
                        ),
                        Text(
                          '°C',
                          style: AkashiTextTheme.headlineLgMobile.copyWith(
                            color: AkashiColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.water_drop, size: 18,
                            color: AkashiColors.onSecondaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          '${BnStrings.rainChance}: ${BnStrings.toBengaliNumeral(rainChance.round())}%',
                          style: AkashiTextTheme.bodyLg.copyWith(
                            color: AkashiColors.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Icon + condition
              Column(
                children: [
                  const Icon(
                    Icons.cloud,
                    size: 72,
                    color: AkashiColors.onSecondaryContainer,
                  ),
                  Text(
                    condition,
                    style: AkashiTextTheme.labelLg.copyWith(
                      color: AkashiColors.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Farming Advice Card ───────────────────────────────────────────────────────
class _FarmingAdviceCard extends StatelessWidget {
  final bool highRain;

  const _FarmingAdviceCard({required this.highRain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AkashiColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AkashiColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  AkashiColors.onPrimaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tips_and_updates,
              color: AkashiColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  BnStrings.farmingAdvice,
                  style: AkashiTextTheme.labelLg.copyWith(
                    color: AkashiColors.onPrimaryContainer
                        .withValues(alpha: 0.8),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  highRain
                      ? BnStrings.rainWarning
                      : BnStrings.noRainAdvice,
                  style: AkashiTextTheme.bodyLg.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
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

// ── Forecast Row ──────────────────────────────────────────────────────────────
class _ForecastRow extends StatelessWidget {
  final List<DayForecast> forecasts;

  const _ForecastRow({required this.forecasts});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: forecasts.isNotEmpty ? forecasts.length : 7,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          if (forecasts.isEmpty) {
            return const _ForecastCard(
              dayName: '–',
              maxTemp: '–',
              minTemp: '–',
              icon: Icons.cloud,
            );
          }
          final day = forecasts[i];
          return _ForecastCard(
            dayName: day.dayName,
            maxTemp: '${day.maxTempC.round()}°',
            minTemp: '${day.minTempC.round()}°',
            icon: _iconData(day.icon),
            isToday: i == 0,
          );
        },
      ),
    );
  }

  IconData _iconData(String name) {
    switch (name) {
      case 'sunny':
        return Icons.wb_sunny;
      case 'partly_cloudy_day':
        return Icons.cloud;
      case 'rainy':
        return Icons.umbrella;
      case 'thunderstorm':
        return Icons.thunderstorm;
      default:
        return Icons.cloud;
    }
  }
}

class _ForecastCard extends StatelessWidget {
  final String dayName;
  final String maxTemp;
  final String minTemp;
  final IconData icon;
  final bool isToday;

  const _ForecastCard({
    required this.dayName,
    required this.maxTemp,
    required this.minTemp,
    required this.icon,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AkashiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? AkashiColors.primary.withValues(alpha: 0.4)
              : AkashiColors.outlineVariant.withValues(alpha: 0.3),
          width: isToday ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dayName,
            style: AkashiTextTheme.labelLg.copyWith(
              color: AkashiColors.onSurfaceVariant,
            ),
          ),
          Icon(icon, color: AkashiColors.secondary, size: 32),
          Text(
            maxTemp,
            style: AkashiTextTheme.titleLg,
          ),
          Text(
            minTemp,
            style: AkashiTextTheme.labelLg.copyWith(
              color: AkashiColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Metric Card ───────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AkashiColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AkashiColors.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AkashiColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(label, style: AkashiTextTheme.labelLgMuted),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AkashiTextTheme.titleLg),
        ],
      ),
    );
  }
}
