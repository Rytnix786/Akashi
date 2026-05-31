/// Akashi — All Bengali text strings (localization)
/// Rule: Every user-facing string is in this file. Never hardcode Bengali in widgets.
library;

class BnStrings {
  BnStrings._();

  // ─── App ───────────────────────────────────────────────────────────────────
  static const String appName = 'আকাশি';
  static const String tagline = 'আপনার ফসলের চোখ আকাশে';
  static const String loadingIntelligence = 'Loading Intelligence';
  static const String poweredBySatellite = 'Powered by High-Utility Satellite Data';

  // ─── Auth ──────────────────────────────────────────────────────────────────
  static const String enterPhone = 'আপনার মোবাইল নম্বর দিন';
  static const String phonePlaceholder = 'মোবাইল নম্বর';
  static const String phonePrefix = '+880';
  static const String sendOtp = 'OTP পাঠান';
  static const String otpTitle = 'OTP যাচাই করুন';
  static const String otpSubtitle = 'আপনার ফোনে পাঠানো ৬ সংখ্যার কোডটি দিন';
  static const String resendOtp = 'OTP পুনরায় পাঠান';
  static const String otpError = 'OTP সঠিক নয়';
  static const String verify = 'যাচাই করুন';

  // ─── Profile Setup ─────────────────────────────────────────────────────────
  static const String profileSetup = 'আপনার পরিচয়';
  static const String namePlaceholder = 'আপনার নাম (ঐচ্ছিক)';
  static const String selectDistrict = 'জেলা নির্বাচন করুন';
  static const String selectUpazila = 'উপজেলা নির্বাচন করুন';
  static const String cropType = 'প্রধান ফসল';
  static const String letsStart = 'শুরু করুন';

  // ─── Crop Types ────────────────────────────────────────────────────────────
  static const String cropRice = 'ধান';
  static const String cropWheat = 'গম';
  static const String cropJute = 'পাট';
  static const String cropVegetable = 'সবজি';
  static const String cropOther = 'অন্যান্য';
  static const List<String> cropTypes = [
    cropRice, cropWheat, cropJute, cropVegetable, cropOther,
  ];

  // ─── Home Screen ──────────────────────────────────────────────────────────
  static const String greeting = 'আসসালামু আলাইকুম';
  static const String goodMorning = 'শুভ সকাল';
  static const String addField = 'জমি যোগ করুন';
  static const String addFieldSubtitle = 'আপনার জমি নিবন্ধন করুন';
  static const String cropHealth = 'ফসল স্বাস্থ্য';
  static const String lastUpdated = 'সর্বশেষ আপডেট';
  static const String seeDetails = 'বিস্তারিত দেখুন';
  static const String pestControl = 'কীটপতঙ্গ পরীক্ষা';
  static const String irrigationAdvice = 'সেচ পরামর্শ';
  static const String recentUpdates = 'সাম্প্রতিক আপডেট';

  // ─── Health Status ─────────────────────────────────────────────────────────
  static const String statusGreen = 'ফসল সুস্থ আছে ✓';
  static const String statusYellow = 'সতর্কতা প্রয়োজন';
  static const String statusRed = 'জরুরি যত্ন নিন';
  static const String statusUnknown = 'তথ্য পাওয়া যায়নি';
  static const String statusSafe = 'নিরাপদ';
  static const String cropGood = 'আপনার ফসল ভালো আছে';
  static const String noActionNeeded = 'কোনো ব্যবস্থা নেওয়ার প্রয়োজন নেই';
  static const String attentionNeeded = 'মনোযোগ দিন';
  static const String partialDataCloud = 'মেঘের কারণে এই তথ্য আংশিক';

  // ─── NDVI Labels ──────────────────────────────────────────────────────────
  static const String ndviWeak = 'দুর্বল';
  static const String ndviMedium = 'মাঝারি';
  static const String ndviStrong = 'শক্তিশালী';
  static const String ndviLabel = 'NDVI সূচক';

  // ─── Field Registration ────────────────────────────────────────────────────
  static const String addFieldTitle = 'জমি যোগ করুন';
  static const String findMyLocation = 'আমার অবস্থান খুঁজুন';
  static const String tapToAddPoints = 'মানচিত্রে ট্যাপ করুন — জমির কোণ চিহ্নিত করুন';
  static const String fieldArea = 'জমির পরিমাণ';
  static const String acres = 'একর';
  static const String bigha = 'বিঘা';
  static const String fieldName = 'জমির নাম';
  static const String defaultFieldName = 'আমার জমি ১';
  static const String cropSeason = 'ফসলের মৌসুম';
  static const String saveField = 'জমি সংরক্ষণ করুন';
  static const String minPointsRequired = 'কমপক্ষে ৩টি কোণ চিহ্নিত করুন';
  static const String seasonBoro = 'বোরো';
  static const String seasonAman = 'আমন';
  static const String seasonAush = 'আউশ';
  static const String seasonRabi = 'রবি';
  static const List<String> seasons = [
    seasonBoro, seasonAman, seasonAush, seasonRabi,
  ];

  // ─── Field Detail ──────────────────────────────────────────────────────────
  static const String currentStatus = 'বর্তমান অবস্থা';
  static const String cropHealthGood = 'ফসলের স্বাস্থ্য: ভালো';
  static const String history7Days = 'গত ৭ দিনের রেকর্ড';
  static const String weatherAlert = 'আবহাওয়া সতর্কবার্তা';
  static const String specialAdvice = 'বিশেষ পরামর্শ';
  static const String soilNutrients = 'মাটির পুষ্টিগুণ';
  static const String humidity = 'আর্দ্রতা';
  static const String nitrogen = 'নাইট্রোজেন';
  static const String nitrogenMedium = 'মধ্যম';

  // ─── Weather ───────────────────────────────────────────────────────────────
  static const String weatherTitle = 'আবহাওয়া';
  static const String currentWeather = 'এখনকার অবস্থা';
  static const String rainChance = 'বৃষ্টির সম্ভাবনা';
  static const String forecast7Day = '৭ দিনের পূর্বাভাস';
  static const String farmingAdvice = 'কৃষি পরামর্শ';
  static const String wind = 'বাতাস';
  static const String windUnit = 'কিমি/ঘণ্টা';
  static const String tempUnit = '°C';
  static const String yourFarmArea = 'আপনার খামার এলাকা';
  static const String rainWarning =
      'পরবর্তী ৩ দিন বৃষ্টির সম্ভাবনা বেশি — সার দেওয়া পরিহার করুন';
  static const String noRainAdvice = 'বৃষ্টির সম্ভাবনা নেই, তাই আজ সেচ দিতে পারেন।';

  // ─── Navigation ────────────────────────────────────────────────────────────
  static const String navHome = 'হোম';
  static const String navFarm = 'খামার';
  static const String navWeather = 'আবহাওয়া';
  static const String navProfile = 'প্রোফাইল';

  // ─── Days of Week (Bengali) ───────────────────────────────────────────────
  static const List<String> weekDays = [
    'শনি', 'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র',
  ];
  static const List<String> weekDaysFull = [
    'শনিবার', 'রবিবার', 'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার',
  ];
  static const String today = 'আজ';

  // ─── Bengali numerals ─────────────────────────────────────────────────────
  /// Converts an integer to Bengali numeral string.
  static String toBengaliNumeral(int n) {
    const digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    return n.toString().split('').map((d) {
      final code = int.tryParse(d);
      return code != null ? digits[code] : d;
    }).join();
  }

  // ─── Districts (all 64) ───────────────────────────────────────────────────
  static const List<String> districts = [
    'ঢাকা', 'চট্টগ্রাম', 'রাজশাহী', 'খুলনা', 'বরিশাল', 'সিলেট',
    'রংপুর', 'ময়মনসিংহ', 'কুমিল্লা', 'নারায়ণগঞ্জ', 'গাজীপুর', 'টাঙ্গাইল',
    'ফরিদপুর', 'মানিকগঞ্জ', 'মুন্সিগঞ্জ', 'নরসিংদী', 'শরীয়তপুর', 'মাদারীপুর',
    'গোপালগঞ্জ', 'কিশোরগঞ্জ', 'নেত্রকোণা', 'জামালপুর', 'শেরপুর',
    'ব্রাহ্মণবাড়িয়া', 'চাঁদপুর', 'লক্ষ্মীপুর', 'নোয়াখালী', 'ফেনী',
    'খাগড়াছড়ি', 'রাঙামাটি', 'বান্দরবান', "কক্সবাজার", 'বগুড়া',
    'জয়পুরহাট', 'নওগাঁ', 'নাটোর', 'চাঁপাইনবাবগঞ্জ', 'পাবনা', 'সিরাজগঞ্জ',
    'বাগেরহাট', 'চুয়াডাঙ্গা', 'যশোর', 'ঝিনাইদহ', 'কুষ্টিয়া',
    'মাগুরা', 'মেহেরপুর', 'নড়াইল', 'সাতক্ষীরা', 'বরগুনা',
    'ভোলা', 'ঝালকাঠি', 'পটুয়াখালী', 'পিরোজপুর', 'হবিগঞ্জ',
    'মৌলভীবাজার', 'সুনামগঞ্জ', 'দিনাজপুর', 'গাইবান্ধা', 'কুড়িগ্রাম',
    'লালমনিরহাট', 'নীলফামারী', 'পঞ্চগড়', 'ঠাকুরগাঁও',
  ];

  // ─── Privacy Policy Consent (Session F) ──────────────────────────────────
  static const String privacyPolicyTitle = 'গোপনীয়তা নীতি এবং শর্তাবলী';
  static const String privacyConsentLabel = 'আমি আকাশি-র গোপনীয়তা নীতি এবং শর্তাবলীতে সম্মতি দিচ্ছি';
  static const String readPrivacyPolicy = 'গোপনীয়তা নীতি পড়ুন';
  static const String consentRequiredError = 'এগিয়ে যাওয়ার আগে গোপনীয়তা নীতিতে সম্মতি প্রদান করতে হবে।';

  // ─── Error Messages ────────────────────────────────────────────────────────
  static const String genericError = 'একটি সমস্যা হয়েছে। আবার চেষ্টা করুন।';
  static const String networkError = 'ইন্টারনেট সংযোগ নেই।';
  static const String retryButton = 'আবার চেষ্টা করুন';
  static const String loading = 'লোড হচ্ছে...';
}
