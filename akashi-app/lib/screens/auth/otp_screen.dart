/// Screen 3: OTP Verification Screen
/// - 6-digit PIN input with large tap targets (48dp+)
/// - 2-minute countdown timer with resend
/// - Auto-advance to Profile Setup on correct OTP
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/l10n/bn_strings.dart';
import '../../core/config/demo_accounts.dart';
import '../../providers/auth_provider.dart';
import 'profile_setup_screen.dart';
import '../home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _hasError = false;
  int _secondsLeft = 120; // 2 minutes
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _timerText {
    final min = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final sec = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '($min:$sec)';
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final authProvider = context.read<AuthProvider>();
    try {
      final isNewUser = await authProvider.verifyOtp(widget.phone, _otp);
      if (!mounted) return;

      if (isNewUser) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      // Clear OTP fields on error
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.sendOtp(widget.phone);
    setState(() => _secondsLeft = 120);
    _timer?.cancel();
    _startTimer();
  }

  Future<void> _autoLoginDemo(DemoAccount account) async {
    final authProvider = context.read<AuthProvider>();
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final success = await authProvider.seedAutoLogin(account.phone);
      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${account.phone} এর ডেমো ডেটা খুঁজে পাওয়া যায়নি'),
            backgroundColor: AkashiColors.error,
          ),
        );
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
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

  void _onDigitEntered(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Auto-verify when all 6 digits entered
    if (_otp.length == 6) {
      _verifyOtp();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AkashiColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AkashiColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              Text(
                BnStrings.otpTitle,
                style: AkashiTextTheme.headlineLgMobile.copyWith(
                  color: AkashiColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                BnStrings.otpSubtitle,
                style: AkashiTextTheme.bodyLgMuted,
              ),
              const SizedBox(height: 8),
              // Show the phone number
              Text(
                widget.phone,
                style: AkashiTextTheme.bodyLg.copyWith(
                  color: AkashiColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 40),

              // ── 6-digit OTP boxes — large tap targets ────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return _OtpBox(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    hasError: _hasError,
                    onChanged: (val) => _onDigitEntered(index, val),
                  );
                }),
              ),

              // ── Error message ─────────────────────────────────────────
              if (_hasError) ...[
                const SizedBox(height: 12),
                Text(
                  BnStrings.otpError,
                  style: AkashiTextTheme.bodyMd.copyWith(
                    color: AkashiColors.error,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Verify button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: (_isLoading || _otp.length < 6) ? null : _verifyOtp,
                  style: FilledButton.styleFrom(
                    backgroundColor: AkashiColors.primary,
                    foregroundColor: AkashiColors.onPrimary,
                    disabledBackgroundColor:
                        AkashiColors.primary.withValues(alpha: 0.4),
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
                          BnStrings.verify,
                          style: AkashiTextTheme.titleLg.copyWith(
                            color: AkashiColors.onPrimary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Resend OTP with countdown ─────────────────────────────
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        '${BnStrings.resendOtp} $_timerText',
                        style: AkashiTextTheme.bodyMd.copyWith(
                          color: AkashiColors.onSurfaceVariant,
                        ),
                      )
                    : TextButton(
                        onPressed: _resendOtp,
                        child: Text(
                          BnStrings.resendOtp,
                          style: AkashiTextTheme.bodyMd.copyWith(
                            color: AkashiColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),

              if (kDebugMode) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AkashiColors.secondaryContainer.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AkashiColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seeded auto login',
                        style: AkashiTextTheme.titleLg.copyWith(
                          color: AkashiColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'এখান থেকে seeded test farmer দিয়ে সরাসরি home screen এ ঢোকা যাবে।',
                        style: AkashiTextTheme.bodyMd.copyWith(
                          color: AkashiColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...demoAccounts.map(
                        (account) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : () => _autoLoginDemo(account),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AkashiColors.primary.withValues(alpha: 0.35)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                '${account.name} • ${account.phone}',
                                style: AkashiTextTheme.bodyMd.copyWith(
                                  color: AkashiColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Single OTP digit box — large, accessible tap target
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: AkashiTextTheme.headlineMd.copyWith(
          color: AkashiColors.primary,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasError
              ? AkashiColors.errorContainer
              : AkashiColors.surfaceContainerLowest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: hasError ? AkashiColors.error : AkashiColors.outlineVariant,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: hasError ? AkashiColors.error : AkashiColors.outlineVariant,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: hasError ? AkashiColors.error : AkashiColors.primary,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
