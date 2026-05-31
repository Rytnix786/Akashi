import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/l10n/bn_strings.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AkashiColors.background,
      appBar: AppBar(
        backgroundColor: AkashiColors.surfaceContainerHigh,
        elevation: 0,
        title: Text(
          BnStrings.privacyPolicyTitle,
          style: AkashiTextTheme.headlineMd.copyWith(
            color: AkashiColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AkashiColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Accent Bar with gradient
            Container(
              height: 6,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AkashiColors.primary,
                    AkashiColors.secondaryContainer,
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glassmorphic welcome banner card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AkashiColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AkashiColors.outlineVariant.withAlpha(120),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                color: AkashiColors.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'আপনার তথ্যের নিরাপত্তা আমাদের প্রতিশ্রুতি',
                                  style: AkashiTextTheme.titleLg.copyWith(
                                    color: AkashiColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'আকাশি (Akashi) আপনার গোপনীয়তা রক্ষা করতে এবং আপনার খামারের তথ্য নিরাপদে পরিচালনা করতে সম্পূর্ণ দায়বদ্ধ। নিচে আমাদের গোপনীয়তা নীতি বিস্তারিত দেওয়া হলো।',
                            style: AkashiTextTheme.bodyLg.copyWith(
                              height: 1.5,
                              color: AkashiColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Section 1: Information Collection
                    _buildSectionHeader('১. তথ্য সংগ্রহ ও ব্যবহার'),
                    _buildBulletItem(
                      'নিবন্ধন তথ্য',
                      'আপনার ফোন নম্বর, নাম, জেলা এবং উপজেলা সংগ্রহ করা হয় যাতে আপনার খামারের অবস্থান অনুযায়ী সঠিক আবহাওয়া এবং বন্যা সতর্কতা প্রেরণ করা সম্ভব হয়।',
                    ),
                    _buildBulletItem(
                      'স্যাটেলাইট ও NDVI ডেটা',
                      'আপনার চিহ্নিত জমির সীমারেখা ব্যবহার করে আমরা Sentinel-1 এবং Sentinel-2 স্যাটেলাইট থেকে ফসলের স্বাস্থ্য সূচক (NDVI) এবং জলীয় উপাদান পর্যবেক্ষণ করি।',
                    ),
                    _buildBulletItem(
                      'রোগ ও কীটপতঙ্গ স্ক্যান',
                      'পাতার রোগ নির্ণয়ের জন্য ক্যামেরায় তোলা ছবি তাৎক্ষণিকভাবে মোবাইলের অফলাইন মডেলে প্রক্রিয়া করা হয়। আপনার ছবি ও ফলাফল আমাদের সার্ভারে কোনো অপ্রয়োজনীয় উদ্দেশ্যে সংরক্ষণ করা হয় না।',
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Data Protection & ABAC
                    _buildSectionHeader('২. নিরাপত্তা ও ডাটা অ্যাক্সেস নীতি'),
                    _buildBulletItem(
                      'Strict ABAC (অ্যাক্সেস নিয়ন্ত্রণ)',
                      'আপনার ব্যক্তিগত তথ্য সম্পূর্ণ সুরক্ষিত। কৃষি সম্প্রসারণ অধিদপ্তরের (DAE) শুধুমাত্র আপনার নিজ অঞ্চলের নিয়োজিত উপ-সহকারী কৃষি কর্মকর্তা আপনার সামগ্রিক বা স্থানীয় সতর্কবার্তাগুলো দেখতে পারেন। বাইরের জেলা বা অন্য কোনো কর্মকর্তাদের আপনার ব্যক্তিগত খামারে প্রবেশাধিকার নেই।',
                    ),
                    _buildBulletItem(
                      'অডিট ট্রেইল ট্র্যাকিং',
                      'যেকোনো প্রশাসনিক কর্মকর্তা কর্তৃক আপনার এলাকার সামগ্রিক তথ্য অনুসন্ধানের সমস্ত কার্যকলাপ আমাদের সেন্ট্রাল অডিট লগে রেকর্ড করা হয় যাতে তথ্যের অপব্যবহার রোধ করা সম্ভব হয়।',
                    ),
                    const SizedBox(height: 24),

                    // Section 3: Third Party & Services
                    _buildSectionHeader('৩. তথ্য শেয়ারিং ও কুকি পলিসি'),
                    _buildBulletItem(
                      'তৃতীয় পক্ষ সুরক্ষা',
                      'আমরা কোনো বাণিজ্যিক স্বার্থে বা তৃতীয় পক্ষের কাছে আপনার মোবাইল নম্বর বা খামারের অবস্থান বিক্রি বা বিনিময় করি না।',
                    ),
                    _buildBulletItem(
                      'লোকাল ক্যাশিং',
                      'ইন্টারনেট সংযোগ না থাকলে নিরবচ্ছিন্ন সেবা দিতে আমরা আপনার ফোনের SharedPreferences মেমরিতে সাম্প্রতিক পরামর্শ ও আবহাওয়ার ডেটা সংরক্ষণ করি।',
                    ),
                    const SizedBox(height: 24),

                    // Section 4: Consent & Rights
                    _buildSectionHeader('৪. আপনার অধিকার ও সম্মতি'),
                    _buildBulletItem(
                      'সম্মতি প্রত্যাহার',
                      'আপনি যেকোনো সময় প্রোফাইল স্ক্রিন থেকে আপনার প্রদত্ত সম্মতি পরিবর্তন বা অ্যাকাউন্ট নিষ্ক্রিয় করার অনুরোধ করতে পারেন।',
                    ),
                    _buildBulletItem(
                      'যোগাযোগ',
                      'গোপনীয়তা নীতি সম্পর্কে যেকোনো প্রশ্ন থাকলে যোগাযোগ করুন: support@akashi.gov.bd',
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // Floating Close Button at the bottom
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AkashiColors.primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'পড়া সম্পন্ন হয়েছে',
                    style: AkashiTextTheme.titleLg.copyWith(
                      color: AkashiColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AkashiTextTheme.titleLg.copyWith(
              color: AkashiColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 48,
            height: 3,
            decoration: BoxDecoration(
              color: AkashiColors.primaryFixedDim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AkashiColors.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AkashiTextTheme.bodyLg.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AkashiColors.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AkashiTextTheme.bodyMd.copyWith(
                    height: 1.45,
                    color: AkashiColors.onSurfaceVariant,
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
