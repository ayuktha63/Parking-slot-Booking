// ─────────────────────────────────────────────────────────────────────────────
// TOKEN STORAGE
//
// The first persistence either app has ever had.
//
// Previously nothing was stored at all: identity was a `String phoneNumber` passed
// down eight constructors, so every cold start returned to the login screen and the
// user retyped their number. That is also why the 5.8-second splash was paid on
// every single launch.
//
// The refresh token is the long-lived credential, so it goes in the platform
// keystore/keychain via flutter_secure_storage. The access token lives in memory
// only — it expires in 15 minutes, and writing it to disk would add risk for no gain.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    this.role = 'customer',
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final String role;

  /// Treated as expired slightly early, so a request is not sent with a token that
  /// dies in flight.
  bool get isAccessExpired =>
      DateTime.now().toUtc().isAfter(
            accessExpiresAt.subtract(const Duration(seconds: 30)),
          );

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessExpiresAt,
    String? role,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessExpiresAt: accessExpiresAt ?? this.accessExpiresAt,
      role: role ?? this.role,
    );
  }
}

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _kRefreshToken = 'parqx.refresh_token';
  static const _kRole = 'parqx.role';

  /// Access token is deliberately memory-only.
  String? _accessToken;
  DateTime? _accessExpiresAt;
  String? _role;

  /// Restores a session at launch. Returns null when the user must sign in.
  ///
  /// Only the refresh token survives a restart; the caller exchanges it for a fresh
  /// access token, which is what makes "stay signed in" work at all.
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _kRefreshToken);
    } on Exception {
      // A corrupt keystore entry must not brick the app — treat it as signed out.
      await clear();
      return null;
    }
  }

  Future<String?> readRole() async {
    if (_role != null) return _role;
    try {
      _role = await _storage.read(key: _kRole);
      return _role;
    } on Exception {
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    _accessToken = session.accessToken;
    _accessExpiresAt = session.accessExpiresAt;
    _role = session.role;
    try {
      await _storage.write(key: _kRefreshToken, value: session.refreshToken);
      await _storage.write(key: _kRole, value: session.role);
    } on Exception {
      // Writing failed (locked keychain, restricted device). The in-memory session
      // still works for this run; the user signs in again next launch.
    }
  }

  /// Updates only the access token, after a refresh.
  void updateAccessToken(String token, DateTime expiresAt) {
    _accessToken = token;
    _accessExpiresAt = expiresAt;
  }

  String? get accessToken => _accessToken;

  bool get hasValidAccessToken {
    final token = _accessToken;
    final expiry = _accessExpiresAt;
    if (token == null || expiry == null) return false;
    return DateTime.now().toUtc().isBefore(expiry.subtract(const Duration(seconds: 30)));
  }

  Future<void> clear() async {
    _accessToken = null;
    _accessExpiresAt = null;
    _role = null;
    try {
      await _storage.delete(key: _kRefreshToken);
      await _storage.delete(key: _kRole);
    } on Exception {
      // Nothing further to do; the in-memory state is already cleared.
    }
  }
}

/// For tests: inject a fake secure-storage backend rather than subclassing.
///
/// `TokenStorage` takes a `FlutterSecureStorage` in its constructor precisely so
/// that tests never touch the real keychain.
///
/// ```dart
/// final storage = TokenStorage(storage: FakeSecureStorage());
/// ```
