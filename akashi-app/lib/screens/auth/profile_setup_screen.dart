/// Screen 4: Profile Setup
/// - Name (optional), District dropdown (64), Upazila dropdown, Crop type radio
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/l10n/bn_strings.dart';
import '../../providers/farmer_provider.dart';
import '../home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  String? _selectedDistrict;
  String? _selectedUpazila;
  String _selectedCropType = BnStrings.cropRice;
  bool _isLoading = false;

  // Upazila data per district — simplified for MVP
  // In production, load from Supabase or a complete JSON file
  final Map<String, List<String>> _upazilaByDistrict = {
    'ঢাকা': ['সাভার', 'ধামরাই', 'কেরানীগঞ্জ', 'নবাবগঞ্জ', 'দোহার'],
    'চট্টগ্রাম': ['হাটহাজারী', 'রাউজান', 'বোয়ালখালী', 'পটিয়া', 'চন্দনাইশ'],
    'রাজশাহী': ['পবা', 'মোহনপুর', 'চারঘাট', 'বাঘা', 'গোদাগাড়ী'],
    'খুলনা': ['ডুমুরিয়া', 'বটিয়াঘাটা', 'দাকোপ', 'পাইকগাছা', 'তেরখাদা'],
    'বরিশাল': ['বাকেরগঞ্জ', 'বাবুগঞ্জ', 'উজিরপুর', 'মুলাদী', 'হিজলা'],
    'সিলেট': ['দক্ষিণ সুরমা', 'বিশ্বনাথ', 'ওসমানীনগর', 'বালাগঞ্জ', 'গোলাপগঞ্জ'],
    'রংপুর': ['পীরগাছা', 'তারাগঞ্জ', 'বদরগঞ্জ', 'গঙ্গাচড়া', 'কাউনিয়া'],
    'ময়মনসিংহ': ['ভালুকা', 'গফরগাঁও', 'গৌরীপুর', 'হালুয়াঘাট', 'ঈশ্বরগঞ্জ'],
    'টাঙ্গাইল': ['বাসাইল', 'ভুয়াপুর', 'দেলদুয়ার', 'ধনবাড়ী', 'ঘাটাইল'],
    'বগুড়া': ['আদমদীঘি', 'বগুড়া সদর', 'ধুনট', 'গাবতলী', 'কাহালু'],
  };

  List<String> get _upazilas =>
      _selectedDistrict != null
          ? (_upazilaByDistrict[_selectedDistrict] ?? ['(অন্যান্য)'])
          : [];

  Future<void> _saveProfile() async {
    if (_selectedDistrict == null || _selectedUpazila == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('জেলা ও উপজেলা নির্বাচন করুন')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      await context.read<FarmerProvider>().createProfile(
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        district: _selectedDistrict!,
        upazila: _selectedUpazila!,
        cropType: _selectedCropType,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
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
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AkashiColors.background,
      appBar: AppBar(
        backgroundColor: AkashiColors.surfaceContainerHigh,
        title: Text(
          BnStrings.profileSetup,
          style: AkashiTextTheme.headlineMd.copyWith(color: AkashiColors.primary),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Name field (optional) ─────────────────────────────────
            Text('আপনার নাম', style: AkashiTextTheme.titleLg),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: AkashiTextTheme.bodyLg,
              decoration: InputDecoration(
                hintText: BnStrings.namePlaceholder,
                hintStyle: AkashiTextTheme.bodyLgMuted,
                filled: true,
                fillColor: AkashiColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AkashiColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AkashiColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AkashiColors.primary, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            // ── District Dropdown ─────────────────────────────────────
            Text(BnStrings.selectDistrict, style: AkashiTextTheme.titleLg),
            const SizedBox(height: 8),
            _AkashiDropdown<String>(
              value: _selectedDistrict,
              hint: BnStrings.selectDistrict,
              items: BnStrings.districts,
              onChanged: (val) => setState(() {
                _selectedDistrict = val;
                _selectedUpazila = null;
              }),
            ),
            const SizedBox(height: 24),

            // ── Upazila Dropdown ──────────────────────────────────────
            Text(BnStrings.selectUpazila, style: AkashiTextTheme.titleLg),
            const SizedBox(height: 8),
            _AkashiDropdown<String>(
              value: _selectedUpazila,
              hint: _selectedDistrict == null
                  ? 'আগে জেলা নির্বাচন করুন'
                  : BnStrings.selectUpazila,
              items: _upazilas,
              enabled: _selectedDistrict != null,
              onChanged: (val) => setState(() => _selectedUpazila = val),
            ),
            const SizedBox(height: 24),

            // ── Crop Type Radio ────────────────────────────────────────
            Text(BnStrings.cropType, style: AkashiTextTheme.titleLg),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BnStrings.cropTypes.map((crop) {
                final isSelected = _selectedCropType == crop;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCropType = crop),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AkashiColors.primaryContainer
                          : AkashiColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? AkashiColors.primary
                            : AkashiColors.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      crop,
                      style: AkashiTextTheme.bodyLg.copyWith(
                        color: isSelected
                            ? AkashiColors.onPrimaryContainer
                            : AkashiColors.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            // ── Save Button ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  backgroundColor: AkashiColors.primary,
                  foregroundColor: AkashiColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : Text(
                        BnStrings.letsStart,
                        style: AkashiTextTheme.titleLg.copyWith(
                          color: AkashiColors.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Reusable styled dropdown for Akashi
class _AkashiDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  const _AkashiDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? AkashiColors.surfaceContainerLowest
            : AkashiColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AkashiColors.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(hint, style: AkashiTextTheme.bodyLgMuted),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AkashiColors.onSurfaceVariant),
          style: AkashiTextTheme.bodyLg,
          onChanged: enabled ? onChanged : null,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString()),
            );
          }).toList(),
        ),
      ),
    );
  }
}
