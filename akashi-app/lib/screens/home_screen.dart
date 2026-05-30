/// Screen 5: Home Screen (Main Dashboard)
/// Design: Stitch farmer_home_healthy.html + farmer_home_needs_attention.html
/// - Top: AppBar with আকাশি logo + farmer greeting
/// - Weather snapshot card (secondary-fixed blue)
/// - Crop Health Card (hero) — green/yellow/red states
/// - Quick Actions grid
/// - Bottom Navigation Bar (হোম | খামার | আবহাওয়া | প্রোফাইল)
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/colors.dart';
import '../core/theme/typography.dart';
import '../core/l10n/bn_strings.dart';
import '../providers/farmer_provider.dart';
import '../providers/field_provider.dart';
import '../providers/weather_provider.dart';
import '../providers/auth_provider.dart';
import '../models/field.dart';
import '../models/health_reading.dart';
import 'field/add_field_screen.dart';
import 'field/field_detail_screen.dart';
import 'weather_screen.dart';
import 'profile_screen.dart';
import '../widgets/health_card_widget.dart';
import '../widgets/weather_strip_widget.dart';
import '../widgets/bottom_nav_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final fieldProvider = context.read<FieldProvider>();
    final farmerProvider = context.read<FarmerProvider>();
    final weatherProvider = context.read<WeatherProvider>();

    await Future.wait([
      farmerProvider.loadProfile(),
      fieldProvider.loadFields(),
      weatherProvider.loadWeather(),
    ]);
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AkashiColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const _HomeTab(),
          const _FarmTab(),
          const WeatherScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AkashiBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AkashiColors.primary,
      onRefresh: () async {
        await context.read<FieldProvider>().loadFields();
        await context.read<WeatherProvider>().loadWeather();
      },
      child: CustomScrollView(
        slivers: [
          // ─── SliverAppBar — sticky header ─────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AkashiColors.surfaceContainerHigh,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AkashiColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.agriculture,
                    size: 18,
                    color: AkashiColors.onPrimaryContainer,
                  ),
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
            actions: [
              TextButton(
                onPressed: () {}, // Language toggle (Phase 2)
                child: Text(
                  'English',
                  style: AkashiTextTheme.labelLg.copyWith(
                    color: AkashiColors.primary,
                  ),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Section 1: Farmer Greeting ────────────────────────
                const _FarmerGreeting(),
                const SizedBox(height: 24),

                // ─── Section 2: Weather Snapshot ───────────────────────
                const WeatherStripWidget(),
                const SizedBox(height: 24),

                // ─── Section 3: Crop Health Card (Hero) ────────────────
                Text(
                  BnStrings.cropHealth,
                  style: AkashiTextTheme.titleLg,
                ),
                const SizedBox(height: 12),
                const _CropHealthSection(),
                const SizedBox(height: 24),

                // ─── Quick Actions Grid ────────────────────────────────
                const _QuickActionsGrid(),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Farmer Greeting ───────────────────────────────────────────────────────────
class _FarmerGreeting extends StatelessWidget {
  const _FarmerGreeting();

  @override
  Widget build(BuildContext context) {
    final farmer = context.watch<FarmerProvider>().farmer;
    final name = farmer?.name ?? '';
    final district = farmer?.district ?? '';

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AkashiColors.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person,
            size: 32,
            color: AkashiColors.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${BnStrings.greeting}${name.isNotEmpty ? ', $name' : ''}',
                style: AkashiTextTheme.headlineMd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (district.isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: AkashiColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      district,
                      style: AkashiTextTheme.labelLgMuted,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Crop Health Section ───────────────────────────────────────────────────────
class _CropHealthSection extends StatelessWidget {
  const _CropHealthSection();

  @override
  Widget build(BuildContext context) {
    final fieldProvider = context.watch<FieldProvider>();

    if (fieldProvider.isLoading) {
      return const _LoadingCard();
    }

    if (fieldProvider.fields.isEmpty) {
      return const _AddFieldCard();
    }

    final primaryField = fieldProvider.fields.first;
    final latestReading = fieldProvider.getLatestReading(primaryField.id);

    return HealthCardWidget(
      field: primaryField,
      reading: latestReading,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FieldDetailScreen(field: primaryField),
        ),
      ),
    );
  }
}

// ── Add Field CTA ─────────────────────────────────────────────────────────────
class _AddFieldCard extends StatelessWidget {
  const _AddFieldCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddFieldScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AkashiColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AkashiColors.outlineVariant,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AkashiColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_location_alt,
                size: 32,
                color: AkashiColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              BnStrings.addField,
              style: AkashiTextTheme.titleLg.copyWith(
                color: AkashiColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              BnStrings.addFieldSubtitle,
              style: AkashiTextTheme.bodyMdMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading Card ──────────────────────────────────────────────────────────────
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AkashiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AkashiColors.primary),
      ),
    );
  }
}

// ── Quick Actions Grid ────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _QuickActionButton(
          icon: Icons.pest_control,
          label: BnStrings.pestControl,
          backgroundColor: AkashiColors.primaryFixedDim,
          iconColor: AkashiColors.primary,
          onTap: () {}, // Phase 2
        ),
        _QuickActionButton(
          icon: Icons.water_drop,
          label: BnStrings.irrigationAdvice,
          backgroundColor: AkashiColors.tertiaryFixedDim,
          iconColor: AkashiColors.tertiary,
          onTap: () {}, // Phase 2
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AkashiColors.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AkashiTextTheme.labelLg.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Farm Tab placeholder ──────────────────────────────────────────────────────
class _FarmTab extends StatelessWidget {
  const _FarmTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AkashiColors.background,
      appBar: AppBar(
        title: Text(BnStrings.navFarm,
            style: AkashiTextTheme.headlineMd.copyWith(color: AkashiColors.primary)),
        backgroundColor: AkashiColors.surfaceContainerHigh,
      ),
      body: Consumer<FieldProvider>(
        builder: (_, fieldProvider, __) {
          if (fieldProvider.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AkashiColors.primary));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: fieldProvider.fields.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == fieldProvider.fields.length) {
                return FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddFieldScreen()),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(BnStrings.addField),
                  style: FilledButton.styleFrom(
                    backgroundColor: AkashiColors.primary,
                    foregroundColor: AkashiColors.onPrimary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
              final field = fieldProvider.fields[index];
              final reading = fieldProvider.getLatestReading(field.id);
              return HealthCardWidget(
                field: field,
                reading: reading,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => FieldDetailScreen(field: field)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
