/// Health Card Widget — The centerpiece of the Akashi UI
/// Design: Stitch farmer_home_healthy.html — hero card with image, status badge, details
/// Supports: green / yellow / red / unknown states
library;

import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/typography.dart';
import '../core/l10n/bn_strings.dart';
import '../models/field.dart';
import '../models/health_reading.dart';

class HealthCardWidget extends StatelessWidget {
  final FieldModel field;
  final HealthReading? reading;
  final VoidCallback? onTap;

  const HealthCardWidget({
    super.key,
    required this.field,
    this.reading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = reading?.healthStatus ?? 'unknown';
    final cloudCover = reading?.cloudCover ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AkashiColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AkashiColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image header with gradient overlay ────────────────────
            _FieldImageHeader(
              status: status,
              fieldName: field.name,
              cropType: field.cropType,
            ),

            // ── Card body ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status headline
                  Text(
                    _statusHeadline(status),
                    style: AkashiTextTheme.headlineMd.copyWith(
                      color: _statusColor(status),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusSubtitle(status, cloudCover),
                    style: AkashiTextTheme.bodyLgMuted,
                  ),

                  // Cloud cover warning
                  if (cloudCover > 70) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            AkashiColors.secondaryFixed.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud,
                              size: 14, color: AkashiColors.secondary),
                          const SizedBox(width: 4),
                          Text(
                            BnStrings.partialDataCloud,
                            style: AkashiTextTheme.labelLg.copyWith(
                              color: AkashiColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(
                      color: AkashiColors.outlineVariant, height: 1),
                  const SizedBox(height: 16),

                  // Footer row
                  Row(
                    children: [
                      const Icon(Icons.update,
                          size: 14,
                          color: AkashiColors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _lastUpdatedText(reading),
                          style: AkashiTextTheme.labelLgMuted,
                        ),
                      ),
                      if (onTap != null)
                        Icon(
                          Icons.chevron_right,
                          color: AkashiColors.primary,
                          size: 24,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusHeadline(String status) {
    switch (status) {
      case 'green':
        return BnStrings.cropGood;
      case 'yellow':
        return BnStrings.statusYellow;
      case 'red':
        return BnStrings.statusRed;
      default:
        return BnStrings.statusUnknown;
    }
  }

  String _statusSubtitle(String status, double cloudCover) {
    if (cloudCover > 70) return 'মেঘাচ্ছন্ন আকাশের কারণে তথ্য সীমিত';
    switch (status) {
      case 'green':
        return BnStrings.noActionNeeded;
      case 'yellow':
        return 'দ্রুত পদক্ষেপ নেওয়া প্রয়োজন';
      case 'red':
        return 'জরুরি ভিত্তিতে কৃষি বিশেষজ্ঞের সাথে যোগাযোগ করুন';
      default:
        return 'পরবর্তী স্যাটেলাইট পাসের জন্য অপেক্ষা করুন';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'green':
        return AkashiColors.primary;
      case 'yellow':
        return AkashiColors.tertiaryContainer;
      case 'red':
        return AkashiColors.error;
      default:
        return AkashiColors.onSurfaceVariant;
    }
  }

  String _lastUpdatedText(HealthReading? reading) {
    if (reading == null) return 'আপডেট হয়নি';
    final date = reading.readingDate;
    return '${BnStrings.lastUpdated}: ${BnStrings.toBengaliNumeral(date.day)} ${_bengaliMonth(date.month)}';
  }

  String _bengaliMonth(int month) {
    const months = [
      '', 'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
    ];
    return months[month];
  }
}

/// Image header for the health card
class _FieldImageHeader extends StatelessWidget {
  final String status;
  final String fieldName;
  final String cropType;

  const _FieldImageHeader({
    required this.status,
    required this.fieldName,
    required this.cropType,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Field image
        ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
          child: SizedBox(
            height: 192,
            width: double.infinity,
            child: Image.network(
              _getFieldImageUrl(status),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AkashiColors.surfaceContainer,
                child: const Icon(Icons.grass,
                    size: 64, color: AkashiColors.onSurfaceVariant),
              ),
            ),
          ),
        ),
        // Gradient overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
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
        // Status badge
        Positioned(
          bottom: 16,
          left: 16,
          child: _StatusBadge(status: status),
        ),
      ],
    );
  }

  String _getFieldImageUrl(String status) {
    // Unsplash: lush green field for healthy, amber for attention, dry for critical
    switch (status) {
      case 'green':
        return 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600&q=75';
      case 'yellow':
        return 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=600&q=75';
      case 'red':
        return 'https://images.unsplash.com/photo-1523348837708-15d4a09cfac2?w=600&q=75';
      default:
        return 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600&q=75';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'green':
        bg = AkashiColors.primaryFixed;
        fg = AkashiColors.onPrimaryFixed;
        icon = Icons.check_circle;
        label = BnStrings.statusSafe;
        break;
      case 'yellow':
        bg = AkashiColors.tertiaryFixed;
        fg = AkashiColors.onTertiaryFixed;
        icon = Icons.warning;
        label = 'সতর্কতা';
        break;
      case 'red':
        bg = AkashiColors.errorContainer;
        fg = AkashiColors.onErrorContainer;
        icon = Icons.error;
        label = 'জরুরি';
        break;
      default:
        bg = AkashiColors.surfaceContainerHigh;
        fg = AkashiColors.onSurfaceVariant;
        icon = Icons.help_outline;
        label = 'অজানা';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AkashiTextTheme.labelLg.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
