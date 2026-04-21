import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final double defaultSavingsRatio;

  const UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
    required this.defaultSavingsRatio,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      defaultSavingsRatio: (json['default_savings_ratio'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'default_savings_ratio': defaultSavingsRatio,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarUrl,
    double? defaultSavingsRatio,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      defaultSavingsRatio: defaultSavingsRatio ?? this.defaultSavingsRatio,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    avatarUrl,
    defaultSavingsRatio,
  ];
}
