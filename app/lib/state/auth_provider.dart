import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';

// --- infrastructure providers ------------------------------------------------

/// The JWT lives in the OS keystore/keychain — never SharedPreferences.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// One shared [ApiClient] (and therefore one dio) for the whole app, so the
/// bearer token set after login applies everywhere.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.read(apiClientProvider)),
);

// --- auth state --------------------------------------------------------------

/// Authentication state. `initializing` is true only during the one-time read
/// of the persisted token at startup, so the gate can show a splash.
class AuthState {
  final String? token;
  final String? email;
  final bool initializing;

  const AuthState({this.token, this.email, this.initializing = false});

  bool get isAuthenticated => token != null;

  AuthState copyWith({String? token, String? email, bool? initializing}) {
    return AuthState(
      token: token ?? this.token,
      email: email ?? this.email,
      initializing: initializing ?? this.initializing,
    );
  }
}

/// Owns login/register/logout and token persistence. On any auth change it also
/// updates the shared [ApiClient]'s bearer token.
class AuthController extends Notifier<AuthState> {
  static const _kToken = 'jwt';
  static const _kEmail = 'email';

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  AuthState build() {
    // Kick off the async load; start in the initializing state.
    _restore();
    return const AuthState(initializing: true);
  }

  Future<void> _restore() async {
    final token = await _storage.read(key: _kToken);
    final email = await _storage.read(key: _kEmail);
    _api.token = token;
    state = AuthState(token: token, email: email, initializing: false);
  }

  Future<void> register(String email, String password) async {
    final res = await ref.read(authApiProvider).register(email, password);
    await _persist(res.accessToken, email);
  }

  Future<void> login(String email, String password) async {
    final res = await ref.read(authApiProvider).login(email, password);
    await _persist(res.accessToken, email);
  }

  Future<void> logout() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kEmail);
    _api.token = null;
    state = const AuthState(initializing: false);
  }

  Future<void> _persist(String token, String email) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kEmail, value: email);
    _api.token = token;
    state = AuthState(token: token, email: email, initializing: false);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
