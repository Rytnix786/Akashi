/// Bottom Navigation Bar — Akashi Design System
/// Design: Stitch farmer_home_healthy.html nav bar
/// 4 items: হোম | খামার | আবহাওয়া | প্রোফাইল
/// Active item: primary-container pill background
library;

import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/l10n/bn_strings.dart';

class AkashiBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AkashiBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: AkashiColors.surfaceContainer,
      indicatorColor: AkashiColors.primaryContainer,
      elevation: 3,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: BnStrings.navHome,
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: BnStrings.navFarm,
        ),
        NavigationDestination(
          icon: Icon(Icons.cloud_outlined),
          selectedIcon: Icon(Icons.cloud),
          label: BnStrings.navWeather,
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: BnStrings.navProfile,
        ),
      ],
    );
  }
}
