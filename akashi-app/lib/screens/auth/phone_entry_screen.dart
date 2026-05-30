/// Screen 2: Phone Entry Screen
/// - Bengali headline, +880 prefix locked
/// - Large touch-friendly input (min 48dp)
/// - 'OTP পাঠান' button
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/l10n/bn_strings.dart';
import '../../providers/auth_provider.dart';
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
}
