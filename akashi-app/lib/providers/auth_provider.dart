/// AuthProvider — Supabase Phone OTP authentication
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  static const _demoUserIdKey = 'demo_user_id';
  static const _demoPhoneKey = 'demo_phone';

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _userId;
  String? _phone;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get userId => _userId;
  String? get phone => _phone;
  String? get accessToken => _supabase.auth.currentSession?.accessToken;

  /// Check if a session already exists (called from splash screen)
  Future<void> checkExistingSession() async {
    final session = _supabase.auth.currentSession;
    if (session != null && !session.isExpired) {
      _isAuthenticated = true;
      _userId = session.user.id;
      _phone = session.user.phone;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final demoUserId = prefs.getString(_demoUserIdKey);
    final demoPhone = prefs.getString(_demoPhoneKey);
    if (demoUserId != null && demoPhone != null) {
      _isAuthenticated = true;
      _userId = demoUserId;
      _phone = demoPhone;
      notifyListeners();
    }
  }

  /// Send OTP to phone number (Supabase Phone Auth)
  Future<void> sendOtp(String phone) async {
    await _supabase.auth.signInWithOtp(phone: phone);
    _phone = phone;
    notifyListeners();
  }

  /// Demo-only auto login used from the OTP screen during local testing.
  /// Looks up the seeded farmer profile by phone and stores it locally.
  Future<bool> seedAutoLogin(String phone) async {
    try {
      final farmer = await _supabase
          .from('farmers')
          .select('id, phone')
          .eq('phone', phone)
          .maybeSingle();

      if (farmer != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_demoUserIdKey, farmer['id'] as String);
        await prefs.setString(_demoPhoneKey, phone);

        _isAuthenticated = true;
        _userId = farmer['id'] as String;
        _phone = phone;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('seedAutoLogin DB query error, falling back to mock: $e');
    }

    if (phone == '+8801712345678') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_demoUserIdKey, '00000000-0000-0000-0000-000000000000');
      await prefs.setString(_demoPhoneKey, phone);

      _isAuthenticated = true;
      _userId = '00000000-0000-0000-0000-000000000000';
      _phone = phone;
      notifyListeners();
      return true;
    }

    return false;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_demoUserIdKey);
    await prefs.remove(_demoPhoneKey);
    _isAuthenticated = false;
    _userId = null;
    _phone = null;
    notifyListeners();
  }
}
