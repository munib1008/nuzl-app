import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user.dart';
import '../data/auth_repository.dart';

class AuthState {
  const AuthState({this.user, this.loading = false, this.error, this.initialized = false});
  final AppUser? user;
  final bool loading;
  final String? error;
  final bool initialized;

  bool get isAuthenticated => user != null;

  AuthState copyWith({AppUser? user, bool? loading, String? error, bool? initialized, bool clearUser = false}) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        loading: loading ?? this.loading,
        error: error,
        initialized: initialized ?? this.initialized,
      );
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController(ref));

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState()) {
    bootstrap();
  }
  final Ref _ref;
  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  /// Restore session from stored token on app start.
  Future<void> bootstrap() async {
    try {
      final user = await _repo.currentUser();
      state = state.copyWith(user: user, initialized: true);
    } catch (_) {
      state = state.copyWith(initialized: true, clearUser: true);
    }
  }

  Future<bool> login(String email, String password) => _run(() => _repo.login(email, password));
  Future<bool> register(String email, String password, String name) =>
      _run(() => _repo.register(email, password, name));
  Future<bool> loginWithGoogle(String idToken) => _run(() => _repo.loginWithGoogle(idToken));

  Future<bool> _run(Future<AppUser> Function() action) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final user = await action();
      state = state.copyWith(user: user, loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return false;
    }
  }

  /// Cancel a pending account deletion, then refresh the user so the
  /// reactivation banner disappears.
  Future<void> reactivate() async {
    await _repo.reactivate();
    await bootstrap();
  }

  /// Switch the active role + refresh so nav/dashboard reload (UAT #3).
  Future<void> switchRole(String role) async {
    await _repo.switchActiveRole(role);
    await bootstrap();
  }

  /// Set the account's primary role once at signup, then refresh.
  Future<void> setPrimaryRole(String role) async {
    await _repo.setPrimaryRole(role);
    await bootstrap();
  }

  Future<void> logout() async {
    await _repo.logout();
    state = state.copyWith(clearUser: true, loading: false);
  }
}
