/// Screen 7: Profile / Account Screen
/// - Displays farmer's name, phone, district, and upazila configurations
/// - Allows logging out cleanly
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../core/theme/colors.dart';
import '../core/theme/typography.dart';
import '../core/l10n/bn_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/farmer_provider.dart';
import 'auth/phone_entry_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final farmerProvider = context.watch<FarmerProvider>();
    final authProvider = context.watch<AuthProvider>();
    final farmer = farmerProvider.farmer;

    final name = farmer?.name ?? 'সম্মানিত কৃষক';
    final phone = farmer?.phone ?? authProvider.phone ?? '–';
    final district = farmer?.district ?? '–';
    final upazila = farmer?.upazila ?? '–';
    final dateStr = farmer != null
        ? DateFormat('dd MMM yyyy').format(farmer.createdAt)
        : '–';

    return Scaffold(
      backgroundColor: AkashiColors.background,
      appBar: AppBar(
        backgroundColor: AkashiColors.surfaceContainerHigh,
        title: Text(
          'প্রোফাইল',
          style: AkashiTextTheme.headlineMd.copyWith(
            color: AkashiColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.person, color: AkashiColors.primary),
          ),
        ],
      ),
      body: farmerProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AkashiColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 1: Profile Card (Avatar + Contact info) ──────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AkashiColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AkashiColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_circle,
                          size: 40,
                          color: AkashiColors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AkashiTextTheme.titleLg.copyWith(
                                color: AkashiColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phone,
                              style: AkashiTextTheme.bodyLg.copyWith(
                                color: AkashiColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 2: Farm Location Information ─────────────────────────────
                _InfoSection(
                  title: 'খামার বিবরণ',
                  children: [
                    _InfoRow(
                      icon: Icons.map,
                      label: 'জেলা',
                      value: district,
                    ),
                    const Divider(height: 1, color: AkashiColors.outlineVariant),
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'উপজেলা',
                      value: upazila,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 3: Other App details ─────────────────────────────────────
                _InfoSection(
                  title: 'অন্যান্য তথ্য',
                  children: [
                    _InfoRow(
                      icon: Icons.calendar_month,
                      label: 'রেজিস্ট্রেশন তারিখ',
                      value: dateStr,
                    ),
                    const Divider(height: 1, color: AkashiColors.outlineVariant),
                    const _InfoRow(
                      icon: Icons.info_outline,
                      label: 'অ্যাপ সংস্করণ',
                      value: '1.0.0',
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // ── 4: Logout Button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // Perform signout
                      await authProvider.signOut();
                      if (!context.mounted) return;
                      // Redirect to phone entry screen and clear stack
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const PhoneEntryScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout, color: AkashiColors.error),
                    label: Text(
                      'লগ আউট',
                      style: AkashiTextTheme.titleLg.copyWith(
                        color: AkashiColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AkashiColors.error, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AkashiColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AkashiColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: AkashiTextTheme.labelLgUppercase.copyWith(
                fontWeight: FontWeight.bold,
                color: AkashiColors.primary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AkashiColors.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: AkashiTextTheme.bodyLg.copyWith(
              color: AkashiColors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AkashiTextTheme.bodyLg.copyWith(
              fontWeight: FontWeight.bold,
              color: AkashiColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
