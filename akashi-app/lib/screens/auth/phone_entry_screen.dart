/// Screen 2: Phone Entry Screen
/// - Bengali headline, +880 prefix locked
/// - Large touch-friendly input (min 48dp)
/// - 'OTP পাঠান' button
/// - [DEBUG ONLY] Auto-login panel via seedAutoLogin()
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/l10n/bn_strings.dart';
import '../../providers/auth_provider.dart';
import '../home_screen.dart';
import 'otp_screen.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isAutoLoginLoading = false;

  // ─── Mock credentials used by the backend bypass ─────────────────────────
  // Matches auth.py: mock_jwt_token_ bypass → phone +8801712345678
  static const String _devPhone = '+8801712345678';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final phone = '+880${_phoneController.text.trim()}';
    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.sendOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpScreen(phone: phone),
        ),
      );
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AkashiColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // Logo + app name
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AkashiColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.agriculture,
                        size: 24,
                        color: AkashiColors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      BnStrings.appName,
                      style: AkashiTextTheme.headlineMd.copyWith(
                        color: AkashiColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // Headline — Bengali large text
                Text(
                  BnStrings.enterPhone,
                  style: AkashiTextTheme.headlineLgMobile.copyWith(
                    color: AkashiColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'আপনার OTP কোড এই নম্বরে পাঠানো হবে',
                  style: AkashiTextTheme.bodyLgMuted,
                ),
                const SizedBox(height: 32),

                // Phone input — +880 prefix locked
                Container(
                  decoration: BoxDecoration(
                    color: AkashiColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AkashiColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      // Locked prefix — visual, not editable
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AkashiColors.surfaceContainer,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(11),
                            bottomLeft: Radius.circular(11),
                          ),
                          border: Border(
                            right: BorderSide(
                              color: AkashiColors.outlineVariant,
                            ),
                          ),
                        ),
                        child: Text(
                          BnStrings.phonePrefix,
                          style: AkashiTextTheme.bodyLg.copyWith(
                            color: AkashiColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Phone number input
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: AkashiTextTheme.bodyLg,
                          decoration: InputDecoration(
                            hintText: '1XXXXXXXXX',
                            hintStyle: AkashiTextTheme.bodyLg.copyWith(
                              color: AkashiColors.outline,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.length < 9) {
                              return 'সঠিক নম্বর দিন';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Send OTP Button — primary, full width, 48dp min height
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: FilledButton.styleFrom(
                      backgroundColor: AkashiColors.primary,
                      foregroundColor: AkashiColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            BnStrings.sendOtp,
                            style: AkashiTextTheme.titleLg.copyWith(
                              color: AkashiColors.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const Spacer(),

                // ─── [DEBUG ONLY] Auto-login panel ────────────────────────
                if (kDebugMode) _DevAutoLoginPanel(
                  devPhone: _devPhone,
                  isLoading: _isAutoLoginLoading,
                  onAutoLogin: _autoLogin,
                ),
                if (kDebugMode) const SizedBox(height: 16),

                // Bottom decorative element
                Center(
                  child: Text(
                    'আকাশি © 2025',
                    style: AkashiTextTheme.labelLgMuted,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// DEBUG-ONLY: Skip OTP, log in directly using seedAutoLogin.
  Future<void> _autoLogin() async {
    setState(() => _isAutoLoginLoading = true);
    final authProvider = context.read<AuthProvider>();
    try {
      final success = await authProvider.seedAutoLogin(_devPhone);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Dev auto-login failed — farmer not found in DB.\n'
              'Run the seed script or use a real phone.',
            ),
            backgroundColor: Color(0xFF7B5800),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dev login error: $e'),
          backgroundColor: AkashiColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAutoLoginLoading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEBUG-ONLY widget — never included in release builds (kDebugMode guard).
// ─────────────────────────────────────────────────────────────────────────────
class _DevAutoLoginPanel extends StatelessWidget {
  const _DevAutoLoginPanel({
    required this.devPhone,
    required this.isLoading,
    required this.onAutoLogin,
  });

  final String devPhone;
  final bool isLoading;
  final VoidCallback onAutoLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCA28), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFCA28).withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFCA28),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.developer_mode_rounded,
                  size: 18,
                  color: Color(0xFF5D4037),
                ),
                const SizedBox(width: 8),
                Text(
                  'DEV TOOLS — Debug Only',
                  style: AkashiTextTheme.labelLg.copyWith(
                    color: const Color(0xFF4E2500),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4E2500).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DEBUG',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4E2500),
                      letterSpacing: 1,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phone info row
                Row(
                  children: [
                    const Icon(
                      Icons.phone_android_rounded,
                      size: 15,
                      color: Color(0xFF7B5800),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mock farmer:',
                      style: AkashiTextTheme.labelLg.copyWith(
                        color: const Color(0xFF7B5800),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECB3),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: const Color(0xFFFFCA28), width: 1),
                      ),
                      child: Text(
                        devPhone,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4E2500),
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Bypasses OTP — queries farmers table directly.',
                  style: AkashiTextTheme.labelLg.copyWith(
                    color: const Color(0xFF9E7900),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),

                // Auto-login button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : onAutoLogin,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4E2500),
                            ),
                          )
                        : const Icon(
                            Icons.bolt_rounded,
                            size: 20,
                            color: Color(0xFF4E2500),
                          ),
                    label: Text(
                      isLoading ? 'Logging in...' : 'Auto Login (Skip OTP)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4E2500),
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFCA28),
                      disabledBackgroundColor:
                          const Color(0xFFFFCA28).withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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
