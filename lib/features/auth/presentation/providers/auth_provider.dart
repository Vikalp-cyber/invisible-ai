import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_data_providers.dart';
import '../../domain/models/auth_exception.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/providers/common_providers.dart';

enum AuthStatus {
  initial,
  bootstrapping,
  waitingForBrowser,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final AuthSession? session;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.error,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && session != null;
  bool get isBootstrapping => status == AuthStatus.bootstrapping;
  bool get isWaitingForBrowser => status == AuthStatus.waitingForBrowser;
  bool get isLoading => isBootstrapping || isWaitingForBrowser;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? error,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _authRepository;
  StreamSubscription<AuthSession?>? _sessionSubscription;

  @override
  AuthState build() {
    _authRepository = ref.watch(authRepositoryProvider);
    final tokenStorage = ref.watch(tokenStorageProvider);
    _sessionSubscription ??= tokenStorage.sessionChanges.listen(_syncSession);
    ref.onDispose(() => _sessionSubscription?.cancel());
    Future<void>.microtask(_restoreSession);
    return const AuthState(status: AuthStatus.bootstrapping);
  }

  Future<void> _restoreSession() async {
    try {
      final session = await _authRepository.tryRestoreSession();
      state = state.copyWith(
        status: session != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        session: session,
        clearError: true,
        clearSession: session == null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _toMessage(e),
        clearSession: true,
      );
    }
  }

  Future<void> signInWithGoogle() async {
    if (state.status == AuthStatus.waitingForBrowser) return;

    state = state.copyWith(status: AuthStatus.waitingForBrowser, clearError: true);
    try {
      final session = await _authRepository.signInWithGoogle();
      state = state.copyWith(status: AuthStatus.authenticated, session: session);
      
      // Auto-focus the app window on successful login.
      unawaited(ref.read(windowServiceProvider).bringToFront());
    } catch (e) {
      // If the user cancelled via the UI, we already updated the state.
      if (state.status != AuthStatus.waitingForBrowser) return;

      state = state.copyWith(
        status: AuthStatus.error,
        error: _toMessage(e),
        clearSession: true,
      );
    }
  }

  Future<void> cancelLogin() async {
    if (state.status == AuthStatus.waitingForBrowser) {
      await _authRepository.cancelSignIn();
      state = state.copyWith(status: AuthStatus.unauthenticated, clearError: true);
    }
  }

  void signInWithMock() {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      session: const AuthSession(
        accessToken: 'mock_access_token',
        refreshToken: 'mock_refresh_token',
        user: AuthUser(
          id: 'dev_user',
          email: 'dev@invisible-ai.com',
          displayName: 'Developer (Mock)',
        ),
      ),
    );
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.unauthenticated, clearError: true, clearSession: true);
    try {
      await _authRepository.logout();
    } catch (e) {
      state = state.copyWith(status: AuthStatus.error, error: _toMessage(e));
    }
  }

  Future<void> refreshSession() => _restoreSession();

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void _syncSession(AuthSession? session) {
    state = state.copyWith(
      status: session != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      session: session,
      clearSession: session == null,
      clearError: session != null,
    );
  }

  String _toMessage(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    return raw;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
