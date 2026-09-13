// ─────────────────────────────────────────────────────────────────────────────
// AUTH REPOSITORY
//
// The only place that knows the shape of /api/v1/auth/*.
// ─────────────────────────────────────────────────────────────────────────────

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/models/user.dart';

class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStorage tokens})
      : _api = api,
        _tokens = tokens {
    // Wiring the refresh callback here — rather than inside ApiClient — keeps the
    // client free of any dependency on this repository, so there is no import cycle.
    _api.refreshSession = _refreshSession;
  }

  final ApiClient _api;
  final TokenStorage _tokens;

  /// Sends a one-time code. Never reveals whether the number already has an account.
  Future<OtpChallenge> requestOtp(String phone) async {
    return _api.post<OtpChallenge>(
      '/auth/otp/request',
      body: {'phone': phone},
      parse: (data) => OtpChallenge.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// Verifies the code and establishes a session.
  ///
  /// The account is created on first successful verification, so there is no
  /// separate registration step — and therefore no way to end up "registered but
  /// not signed in", which is exactly where the old register screen left people.
  Future<AuthResult> verifyOtp({
    required String phone,
    required String otp,
    required String requestId,
    String? name,
  }) async {
    final result = await _api.post<AuthResult>(
      '/auth/otp/verify',
      body: {
        'phone': phone,
        'otp': otp,
        'request_id': requestId,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
      parse: (data) => AuthResult.fromJson((data as Map).cast<String, dynamic>()),
    );

    await _tokens.save(AuthSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      accessExpiresAt: result.expiresAt,
    ));

    return result;
  }

  /// Restores a session at launch from the stored refresh token.
  ///
  /// Returns null when there is nothing to restore, which the router reads as
  /// "show sign-in". This is what removes the retype-your-number-every-launch
  /// behaviour the app had, since it stored nothing at all.
  Future<AppUser?> restoreSession() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return null;

    final session = await _refreshSession(refreshToken);
    if (session == null) {
      await _tokens.clear();
      return null;
    }

    await _tokens.save(session);

    try {
      return await fetchMe();
    } on Object {
      // The tokens are valid but the profile call failed (offline, server blip).
      // Keep the session: the user is signed in, and the profile will load later.
      return null;
    }
  }

  /// Exchanges a refresh token for a new pair. Wired into ApiClient for the
  /// transparent-refresh path as well as being callable directly at launch.
  Future<AuthSession?> _refreshSession(String refreshToken) async {
    try {
      return await _api.post<AuthSession>(
        '/auth/refresh',
        body: {'refresh_token': refreshToken},
        parse: (data) {
          final json = (data as Map).cast<String, dynamic>();
          return AuthSession(
            accessToken: json['access_token'] as String? ?? '',
            refreshToken: json['refresh_token'] as String? ?? '',
            accessExpiresAt: DateTime.now()
                .toUtc()
                .add(Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 900)),
          );
        },
      );
    } on Object {
      // A failed refresh is a signed-out state, not an error to surface.
      return null;
    }
  }

  Future<AppUser> fetchMe() async {
    return _api.get<AppUser>(
      '/me',
      parse: (data) {
        final json = (data as Map).cast<String, dynamic>();
        return AppUser.fromJson((json['user'] as Map).cast<String, dynamic>());
      },
    );
  }

  Future<List<Vehicle>> fetchVehicles() async {
    return _api.get<List<Vehicle>>(
      '/me/vehicles',
      parse: (data) => ((data as List?) ?? const [])
          .map((v) => Vehicle.fromJson((v as Map).cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  /// Updates the profile.
  ///
  /// Reaches `PATCH /api/v1/me`, which actually exists — the old Settings screen
  /// called `PUT /api/users/profile`, an endpoint the live backend never had, so
  /// "Edit Name" had never once worked in production.
  Future<AppUser> updateProfile({String? name}) async {
    return _api.patch<AppUser>(
      '/me',
      body: {if (name != null) 'name': name.trim()},
      parse: (data) {
        final json = (data as Map).cast<String, dynamic>();
        return AppUser.fromJson((json['user'] as Map).cast<String, dynamic>());
      },
    );
  }

  Future<Vehicle> addVehicle({
    required String vehicleType,
    required String numberPlate,
    String? label,
    bool isDefault = false,
  }) async {
    return _api.post<Vehicle>(
      '/me/vehicles',
      body: {
        'vehicle_type': vehicleType,
        'number_plate': numberPlate,
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
        'is_default': isDefault,
      },
      parse: (data) => Vehicle.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  Future<void> deleteVehicle(int vehicleId) async {
    await _api.delete<void>('/me/vehicles/$vehicleId', parse: (_) {});
  }

  Future<Vehicle> setDefaultVehicle(int vehicleId) async {
    return _api.post<Vehicle>(
      '/me/vehicles/$vehicleId/default',
      parse: (data) => Vehicle.fromJson((data as Map).cast<String, dynamic>()),
    );
  }

  /// Signs out. Revokes server-side first, then clears local state.
  ///
  /// Local state is cleared even if the network call fails — a user who taps
  /// "Log out" must end up signed out regardless.
  Future<void> logout({bool allDevices = false}) async {
    final refreshToken = await _tokens.readRefreshToken();
    try {
      await _api.post<void>(
        '/auth/logout',
        body: {
          if (refreshToken != null) 'refresh_token': refreshToken,
          'all_devices': allDevices,
        },
        parse: (_) {},
      );
    } on Object {
      // Ignored deliberately — see above.
    } finally {
      await _tokens.clear();
    }
  }
}
