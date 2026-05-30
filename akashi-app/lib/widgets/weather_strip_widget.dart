/// Weather Strip Widget — compact weather card for home screen
/// Design: Stitch farmer_home_healthy.html Section 2
/// secondary-fixed background, cloud icon, temp, humidity, wind
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/colors.dart';
import '../core/theme/typography.dart';
import '../core/l10n/bn_strings.dart';
import '../providers/weather_provider.dart';

class WeatherStripWidget extends StatelessWidget {
  const WeatherStripWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>().weather;

    final tempC = weather?.tempC ?? 28;
    final humidity = weather?.humidity ?? 65;
    final wind = weather?.windKmh ?? 12;
    final condition = weather?.condition ?? 'আংশিক মেঘলা';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AkashiColors.secondaryFixed,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Weather icon
          const Icon(
            Icons.cloud,
            size: 48,
            color: AkashiColors.onSecondaryFixed,
          ),
          const SizedBox(width: 16),

          // Temp + condition
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${BnStrings.toBengaliNumeral(tempC.round())}°সে.',
                    style: AkashiTextTheme.headlineLgMobile.copyWith(
                      color: AkashiColors.onSecondaryFixed,
                    ),
                  ),
                ],
              ),
              Text(
                condition,
                style: AkashiTextTheme.bodyLg.copyWith(
                  color: AkashiColors.onSecondaryFixedVariant,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Humidity + wind
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'আর্দ্রতা: ${BnStrings.toBengaliNumeral(humidity.round())}%',
                style: AkashiTextTheme.labelLg.copyWith(
                  color: AkashiColors.onSecondaryFixedVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'বাতাস: ${BnStrings.toBengaliNumeral(wind.round())} ${BnStrings.windUnit}',
                style: AkashiTextTheme.labelLg.copyWith(
                  color: AkashiColors.onSecondaryFixedVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
