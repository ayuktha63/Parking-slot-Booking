// ─────────────────────────────────────────────────────────────────────────────
// CORE PROVIDERS
//
// Infrastructure singletons and the authentication state machine.
//
// Riverpod replaces the pattern where every screen hand-rolled `bool isLoading`,
// a `catch (_) {}`, and its own copy of the data. `AsyncValue` gives loading,
// success and error as one value that widgets switch on, so a screen physically
// cannot forget an error state.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../shared/models/user.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../storage/token_storage.dart';

/* ── infrastructure ────────────────────────────────────────────────────────── */

final Provider<TokenStorage> tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

// Explicitly typed: these three providers reference one another (client →
// controller → repository → client), and Dart cannot infer a type through a
// cycle. The annotation is what makes the cycle legal rather than a compile
// error; the dependency itself is deliberate.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    // Fired when a refresh fails: the session is genuinely over, so drop auth state
    // and let the router redirect. One place decides this, not each screen.
    onSessionExpired: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
  ref.onDispose(client.close);
  return client;
});

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    tokens: ref.watch(tokenStorageProvider),
  );
});

/* ── authentication state ──────────────────────────────────────────────────── */

enum AuthStatus {
  /// Restoring a session at launch. The router shows a brief branded boot screen.
  restoring,

  /// No valid session.
  signedOut,

  /// Signed in, but the profile is incomplete — first run.
  needsProfile,

  /// Fully signed in.
  signedIn,
}

@immutable
class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.vehicles = const [],
    this.error,
  });

  const AuthState.restoring() : this(status: AuthStatus.restoring);
  const AuthState.signedOut({ApiException? error})
      : this(status: AuthStatus.signedOut, error: error);

  final AuthStatus status;
  final AppUser? user;
  final List<Vehicle> vehicles;
  final ApiException? error;

  bool get isAuthenticated =>
      status == AuthStatus.signedIn || status == AuthStatus.needsProfile;
  bool get isRestoring => status == AuthStatus.restoring;

  Vehicle? defaultVehicleFor(String vehicleType) {
    for (final v in vehicles) {
      if (v.vehicleType.wire == vehicleType && v.isDefault) return v;
    }
    for (final v in vehicles) {
      if (v.vehicleType.wire == vehicleType) return v;
    }
    return null;
  }

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    List<Vehicle>? vehicles,
    ApiException? error,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        vehicles: vehicles ?? this.vehicles,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Owns the session for the whole app.
///
/// Everything that depends on "is the user signed in" watches this, including the
/// router's redirect. There is no second source of truth.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState.restoring()) {
    _restore();
  }

  final AuthRepository _repository;

  /// Held between requesting and verifying a code.
  OtpChallenge? _pendingChallenge;
  String? _pendingPhone;

  OtpChallenge? get pendingChallenge => _pendingChallenge;
  String? get pendingPhone => _pendingPhone;

  /// Launch path: restore, or fall through to signed-out.
  ///
  /// Replaces a 5.8-second unskippable splash that ran on every cold start because
  /// nothing was persisted and there was nothing to restore.
  Future<void> _restore() async {
    try {
      final user = await _repository.restoreSession();
      if (user == null) {
        state = const AuthState.signedOut();
        return;
      }
      final vehicles = await _safeVehicles();
      state = AuthState(
        status: user.needsProfile ? AuthStatus.needsProfile : AuthStatus.signedIn,
        user: user,
        vehicles: vehicles,
      );
    } on Object {
      state = const AuthState.signedOut();
    }
  }

  Future<List<Vehicle>> _safeVehicles() async {
    try {
      return await _repository.fetchVehicles();
    } on Object {
      // A missing vehicle list must not block sign-in.
      return const [];
    }
  }

  /// Step 1 — request a code.
  Future<OtpChallenge> requestOtp(String phone) async {
    state = state.copyWith(clearError: true);
    final challenge = await _repository.requestOtp(phone);
    _pendingChallenge = challenge;
    _pendingPhone = phone;
    return challenge;
  }

  /// Step 2 — verify and sign in.
  Future<void> verifyOtp(String otp, {String? name}) async {
    final challenge = _pendingChallenge;
    final phone = _pendingPhone;
    if (challenge == null || phone == null) {
      throw ApiException(
        kind: ApiErrorKind.validation,
        message: 'Request a new code to continue.',
        code: 'NO_PENDING_CHALLENGE',
      );
    }

    final result = await _repository.verifyOtp(
      phone: phone,
      otp: otp,
      requestId: challenge.requestId,
      name: name,
    );

    _pendingChallenge = null;
    _pendingPhone = null;

    final user = result.user;
    final vehicles = await _safeVehicles();

    state = AuthState(
      status: (result.needsProfile || (user?.needsProfile ?? true))
          ? AuthStatus.needsProfile
          : AuthStatus.signedIn,
      user: user,
      vehicles: vehicles,
    );
  }

  /// Completes first-run setup: a name, and optionally a first vehicle.
  Future<void> completeProfile({
    required String name,
    String? vehicleType,
    String? numberPlate,
  }) async {
    final user = await _repository.updateProfile(name: name);

    var vehicles = state.vehicles;
    if (vehicleType != null && numberPlate != null && numberPlate.trim().isNotEmpty) {
      try {
        await _repository.addVehicle(
          vehicleType: vehicleType,
          numberPlate: numberPlate,
          isDefault: true,
        );
        vehicles = await _safeVehicles();
      } on ApiException {
        // A rejected plate should not block finishing sign-up; the user can add a
        // vehicle later from Profile.
      }
    }

    state = AuthState(status: AuthStatus.signedIn, user: user, vehicles: vehicles);
  }

  Future<void> refreshProfile() async {
    if (!state.isAuthenticated) return;
    try {
      final user = await _repository.fetchMe();
      final vehicles = await _safeVehicles();
      state = state.copyWith(
        user: user,
        vehicles: vehicles,
        status: user.needsProfile ? AuthStatus.needsProfile : AuthStatus.signedIn,
      );
    } on ApiException catch (e) {
      state = state.copyWith(error: e);
    }
  }

  Future<void> updateName(String name) async {
    final user = await _repository.updateProfile(name: name);
    state = state.copyWith(user: user, status: AuthStatus.signedIn);
  }

  Future<void> addVehicle({
    required String vehicleType,
    required String numberPlate,
    String? label,
    bool isDefault = false,
  }) async {
    await _repository.addVehicle(
      vehicleType: vehicleType,
      numberPlate: numberPlate,
      label: label,
      isDefault: isDefault,
    );
    state = state.copyWith(vehicles: await _safeVehicles());
  }

  Future<void> removeVehicle(int vehicleId) async {
    await _repository.deleteVehicle(vehicleId);
    state = state.copyWith(vehicles: await _safeVehicles());
  }

  Future<void> setDefaultVehicle(int vehicleId) async {
    await _repository.setDefaultVehicle(vehicleId);
    state = state.copyWith(vehicles: await _safeVehicles());
  }

  /// Signs out.
  ///
  /// Replaces `Navigator.pushNamedAndRemoveUntil(context, "/login")` against a route
  /// that was never registered — which meant the customer app had no working way to
  /// log out at all.
  Future<void> logout({bool allDevices = false}) async {
    await _repository.logout(allDevices: allDevices);
    _pendingChallenge = null;
    _pendingPhone = null;
    state = const AuthState.signedOut();
  }

  /// Called by ApiClient when a refresh fails mid-session.
  void onSessionExpired() {
    if (state.status == AuthStatus.signedOut) return;
    _pendingChallenge = null;
    _pendingPhone = null;
    state = AuthState.signedOut(
      error: ApiException(
        kind: ApiErrorKind.unauthenticated,
        message: 'Your session ended. Please sign in again.',
        code: 'SESSION_EXPIRED',
      ),
    );
  }
}

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

/// Convenience selectors — widgets watch the narrowest thing they need, so a
/// vehicle-list change does not rebuild every screen that only wanted the name.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authControllerProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isAuthenticated;
});

final userVehiclesProvider = Provider<List<Vehicle>>((ref) {
  return ref.watch(authControllerProvider).vehicles;
});
