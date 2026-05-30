/// Farmer model
library;

class FarmerModel {
  final String id;
  final String phone;
  final String? name;
  final String district;
  final String upazila;
  final String? fcmToken;
  final DateTime createdAt;

  const FarmerModel({
    required this.id,
    required this.phone,
    this.name,
    required this.district,
    required this.upazila,
    this.fcmToken,
    required this.createdAt,
  });

  factory FarmerModel.fromJson(Map<String, dynamic> json) {
    return FarmerModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String?,
      district: json['district'] as String,
      upazila: json['upazila'] as String,
      fcmToken: json['fcm_token'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'district': district,
    'upazila': upazila,
    'fcm_token': fcmToken,
    'created_at': createdAt.toIso8601String(),
  };
}
