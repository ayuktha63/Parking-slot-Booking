// ─────────────────────────────────────────────────────────────────────────────
// USER & VEHICLE MODELS
//
// Mirrors GET /api/v1/me.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import 'parking.dart' show VehicleType, formatPlate;

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.phone,
    this.name,
    this.phoneVerified = false,
    this.onboarded = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] as num).toInt(),
        phone: json['phone'] as String? ?? '',
        name: json['name'] as String?,
        phoneVerified: json['phone_verified'] == true,
        onboarded: json['onboarded'] == true,
      );

  final int id;
  final String phone;
  final String? name;
  final bool phoneVerified;
  final bool onboarded;

  /// True while the account still carries the backend's placeholder name, which is
  /// how the app knows to show the one-time profile step rather than greeting
  /// somebody as "User".
  bool get needsProfile => name == null || name!.trim().isEmpty || name == 'User';

  /// First name for greetings; null when there is nothing real to use.
  String? get greetingName {
    if (needsProfile) return null;
    return name!.trim().split(RegExp(r'\s+')).first;
  }

  /// "+91 98765 43210"
  String get displayPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return phone;
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }

  AppUser copyWith({String? name, bool? onboarded}) => AppUser(
        id: id,
        phone: phone,
        name: name ?? this.name,
        phoneVerified: phoneVerified,
        onboarded: onboarded ?? this.onboarded,
      );
}

@immutable
class Vehicle {
  const Vehicle({
    required this.id,
    required this.vehicleType,
    required this.numberPlate,
    this.label,
    this.isDefault = false,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: (json['id'] as num).toInt(),
        vehicleType: VehicleType.parse(json['vehicle_type'] as String?),
        numberPlate: json['number_plate'] as String? ?? '',
        label: json['label'] as String?,
        isDefault: json['is_default'] == true,
      );

  final int id;
  final VehicleType vehicleType;
  final String numberPlate;
  final String? label;
  final bool isDefault;

  /// "KL 01 AB 1234" — see [formatPlate].
  String get displayPlate => formatPlate(numberPlate);

  String get title => label?.trim().isNotEmpty == true ? label! : vehicleType.label;
}

/// The result of a successful sign-in.
@immutable
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.user,
    this.isNewAccount = false,
    this.needsProfile = false,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['access_token'] as String? ?? '',
        refreshToken: json['refresh_token'] as String? ?? '',
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 900,
        user: json['user'] is Map
            ? AppUser.fromJson((json['user'] as Map).cast<String, dynamic>())
            : null,
        isNewAccount: json['is_new_account'] == true,
        needsProfile: json['needs_profile'] == true,
      );

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AppUser? user;
  final bool isNewAccount;
  final bool needsProfile;

  DateTime get expiresAt => DateTime.now().toUtc().add(Duration(seconds: expiresIn));
}

/// Response from requesting an OTP.
@immutable
class OtpChallenge {
  const OtpChallenge({
    required this.requestId,
    required this.expiresIn,
    required this.resendAfterSeconds,
    this.devOtp,
  });

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        requestId: json['request_id'] as String? ?? '',
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 300,
        resendAfterSeconds: (json['resend_after_seconds'] as num?)?.toInt() ?? 30,
        // Present only outside production. Used to prefill the field in development
        // so nobody waits on a WhatsApp message; never shown in a release build.
        devOtp: json['dev_otp'] as String?,
      );

  final String requestId;
  final int expiresIn;
  final int resendAfterSeconds;
  final String? devOtp;

  DateTime get expiresAt => DateTime.now().add(Duration(seconds: expiresIn));
}
