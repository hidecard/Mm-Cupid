import 'package:intl/intl.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String? gender;
  final String? interestedIn;
  final String? birthday;
  final String? bio;
  final String? profilePic;
  final double? latitude;
  final double? longitude;
  final bool isOnboarded;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.gender,
    this.interestedIn,
    this.birthday,
    this.bio,
    this.profilePic,
    this.latitude,
    this.longitude,
    required this.isOnboarded,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      return false;
    }

    return User(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      gender: json['gender'] as String?,
      interestedIn: json['interested_in'] as String?,
      birthday: json['birthday'] as String?,
      bio: json['bio'] as String?,
      profilePic: json['profile_pic'] as String?,
      latitude: json['latitude'] != null
          ? double.parse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.parse(json['longitude'].toString())
          : null,
      isOnboarded: parseBool(json['is_onboarded']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'gender': gender,
      'interested_in': interestedIn,
      'birthday': birthday,
      'bio': bio,
      'profile_pic': profilePic,
      'latitude': latitude,
      'longitude': longitude,
      'is_onboarded': isOnboarded,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get displayName => name;

  String get displayBirthday {
    if (birthday == null) return '';
    try {
      final date = DateTime.parse(birthday!);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return birthday ?? '';
    }
  }

  int get age {
    if (birthday == null) return 0;
    try {
      final birth = DateTime.parse(birthday!);
      final today = DateTime.now();
      var age = today.year - birth.year;
      if (today.month < birth.month ||
          (today.month == birth.month && today.day < birth.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 0;
    }
  }
}
