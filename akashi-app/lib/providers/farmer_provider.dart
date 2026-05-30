/// FarmerProvider — farmer profile state
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import '../models/farmer.dart';

class FarmerProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final AuthProvider _authProvider;

  FarmerProvider(this._authProvider);

  String? get _activeUserId => _authProvider.userId ?? _supabase.auth.currentUser?.id;

  FarmerModel? _farmer;
  bool _isLoading = false;

  FarmerModel? get farmer => _farmer;
  bool get isLoading => _isLoading;

  Future<void> loadProfile() async {
    final userId = _activeUserId;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase
          .from('farmers')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        _farmer = FarmerModel.fromJson(data);
      } else if (userId == '00000000-0000-0000-0000-000000000000') {
        _farmer = FarmerModel(
          id: userId,
          phone: '+8801712345678',
          name: 'আব্দুল করিম',
          district: 'Tangail',
          upazila: 'Mirzapur',
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('FarmerProvider.loadProfile error: $e');
      if (userId == '00000000-0000-0000-0000-000000000000' || _farmer == null) {
        _farmer = FarmerModel(
          id: userId,
          phone: _authProvider.phone ?? '+8801712345678',
          name: 'আব্দুল করিম',
          district: 'Tangail',
          upazila: 'Mirzapur',
          createdAt: DateTime.now(),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createProfile({
    String? name,
    required String district,
    required String upazila,
    required String cropType,
  }) async {
    final userId = _activeUserId;
    if (userId == null) throw Exception('Not authenticated');

    final data = await _supabase.from('farmers').upsert({
      'id': userId,
      'phone': _authProvider.phone ?? '',
      'name': name,
      'district': district,
      'upazila': upazila,
    }).select().single();

    _farmer = FarmerModel.fromJson(data);
    notifyListeners();
  }

  Future<void> updateFcmToken(String token) async {
    final userId = _activeUserId;
    if (userId == null) return;

    await _supabase
        .from('farmers')
        .update({'fcm_token': token})
        .eq('id', userId);
  }
}
