library;

class DemoAccount {
  final String phone;
  final String name;
  final String district;
  final String upazila;

  const DemoAccount({
    required this.phone,
    required this.name,
    required this.district,
    required this.upazila,
  });
}

const demoAccounts = [
  DemoAccount(
    phone: '+8801712345678',
    name: 'আব্দুল করিম',
    district: 'Tangail',
    upazila: 'Mirzapur',
  ),
  DemoAccount(
    phone: '+8801812345678',
    name: 'রহিমা বেগম',
    district: 'Mymensingh',
    upazila: 'Trishal',
  ),
  DemoAccount(
    phone: '+8801912345678',
    name: 'জামাল উদ্দিন',
    district: 'Dhaka',
    upazila: 'Savar',
  ),
];
