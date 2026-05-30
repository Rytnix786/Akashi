/// AuthProvider — Supabase Phone OTP authentication
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _userId;
  String? _phone;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get userId => _userId;
  String? get phone => _phone;

  /// Check if a session already exists (called from splash screen)
  Future<void> checkExistingSession() async {
    final session = _supabase.auth.currentSession;
    if (session != null && !session.isExpired) {
      _isAuthenticated = true;
      _userId = session.user.id;
      _phone = session.user.phone;
      notifyListeners();
    }
  }

  /// Send OTP to phone number (Supabase Phone Auth)
  Future<void> sendOtp(String phone) async {
    await _supabase.auth.signInWithOtp(phone: phone);
    _phone = phone;
    notifyListeners();
  }

  /// Verify OTP — returns true if this is a NEW user (profile setup needed)
  Future<bool> verifyOtp(String phone, String token) async {
    final response = await _supabase.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );

    if (response.session != null) {
      _isAuthenticated = true;
      _userId = response.session!.user.id;
      _phone = phone;
      notifyListeners();

      // Check if farmer profile exists
      final farmer = await _supabase
          .from('farmers')
          .select('id')
          .eq('id', _userId!)
          .maybeSingle();

      return farmer == null; // true = new user, needs profile setup
    }

    throw Exception('OTP verification failed');
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _isAuthenticated = false;
    _userId = null;
    _phone = null;
    notifyListeners();
  }
}
