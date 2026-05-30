/// FarmerProvider — farmer profile state
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/farmer.dart';

class FarmerProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  FarmerModel? _farmer;
  bool _isLoading = false;

  FarmerModel? get farmer => _farmer;
  bool get isLoading => _isLoading;

  Future<void> loadProfile() async {
    final userId = _supabase.auth.currentUser?.id;
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
      }
    } catch (e) {
      debugPrint('FarmerProvider.loadProfile error: $e');
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
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final data = await _supabase.from('farmers').upsert({
      'id': user.id,
      'phone': user.phone ?? '',
      'name': name,
      'district': district,
      'upazila': upazila,
    }).select().single();

    _farmer = FarmerModel.fromJson(data);
    notifyListeners();
  }

  Future<void> updateFcmToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('farmers')
        .update({'fcm_token': token})
        .eq('id', userId);
  }
}
