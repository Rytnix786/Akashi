/// Screen 1: Splash Screen
/// Design: Stitch splash_screen/code.html
/// - Logo (agriculture icon) in primary-container rounded box
/// - 'আকাশি' headline in primary color
/// - Tagline: 'আপনার ফসলের চোখ আকাশে'
/// - Animated satellite field image at bottom
/// - Checks JWT → routes to Home or Phone Entry
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/colors.dart';
import '../core/theme/typography.dart';
import '../core/l10n/bn_strings.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'auth/phone_entry_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  int _dotCount = 0;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startDotAnimation();
    _navigate();
  }

  void _setupAnimations() {
    // Fade + slide up — matching Stitch's 'animate-fade-in-up 1.2s'
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08), // translateY(20px) equivalent
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Pulse for loading dots — matching 'animate-pulse-slow 4s'
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  void _startDotAnimation() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount + 1) % 4);
    });
  }

  Future<void> _navigate() async {
    // Wait for animation to play (2 seconds as per spec)
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.checkExistingSession();

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const PhoneEntryScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AkashiColors.background,
      body: Stack(
        children: [
          // ─── Decorative ambient orbs (from Stitch design) ──────────────
          Positioned(
            top: -MediaQuery.of(context).size.height * 0.1,
            right: -MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AkashiColors.primaryContainer.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -MediaQuery.of(context).size.height * 0.05,
            left: -MediaQuery.of(context).size.width * 0.05,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AkashiColors.secondaryContainer.withValues(alpha: 0.1),
              ),
            ),
          ),

          // ─── Main Content ─────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo container — rounded-3xl in Stitch
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AkashiColors.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AkashiColors.primary.withValues(alpha: 0.1),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.agriculture,
                        size: 48,
                        color: AkashiColors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App name — headline-lg-mobile, primary color
                    Text(
                      BnStrings.appName,
                      style: AkashiTextTheme.headlineLgMobile.copyWith(
                        color: AkashiColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Decorative divider — w-12 h-1 bg-secondary-container
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AkashiColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tagline — body-lg, on-surface-variant
                    Text(
                      BnStrings.tagline,
                      style: AkashiTextTheme.bodyLg.copyWith(
                        color: AkashiColors.onSurfaceVariant,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Bottom: Loading dots + satellite image ───────────────────
          Positioned(
            bottom: 48,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Loading dots with pulse animation
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final opacities = [0.2, 0.4, 0.2];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AkashiColors.primary
                                  .withValues(alpha: opacities[i]),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${BnStrings.loadingIntelligence}${'.' * _dotCount}',
                        style: AkashiTextTheme.labelLg.copyWith(
                          color: AkashiColors.outline,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Satellite field image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AkashiColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AkashiColors.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const _FieldImage(),
                      ),
                      // Gradient overlay (bottom)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AkashiColors.background.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
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
    );
  }
}

/// Satellite field image — shows a beautiful agricultural field.
/// Uses a placeholder decoration if network unavailable.
class _FieldImage extends StatelessWidget {
  const _FieldImage();

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=800&q=80',
      fit: BoxFit.cover,
      width: double.infinity,
      height: 160,
      colorBlendMode: BlendMode.multiply,
      color: Colors.white.withValues(alpha: 0.9), // slight desaturation like grayscale-[0.2] contrast-[1.1]
      errorBuilder: (_, __, ___) => Container(
        height: 160,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AkashiColors.primaryContainer,
              AkashiColors.secondaryContainer,
            ],
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.landscape,
            size: 64,
            color: AkashiColors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
