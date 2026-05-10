import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_data_providers.dart';
import '../../domain/models/auth_exception.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthState {
  final bool isLoading;
  final AuthSession? session;
  final String? error;

  const AuthState({this.isLoading = false, this.session, this.error});

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    bool? isLoading,
    AuthSession? session,
    String? error,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
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
    return const AuthState(isLoading: true);
  }

  Future<void> _restoreSession() async {
    try {
      final session = await _authRepository.tryRestoreSession();
      state = state.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
        clearSession: session == null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _toMessage(e),
        clearSession: true,
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _authRepository.signInWithGoogle();
      state = state.copyWith(isLoading: false, session: session);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _toMessage(e),
        clearSession: true,
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepository.logout();
      state = state.copyWith(isLoading: false, clearSession: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _toMessage(e));
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
      isLoading: false,
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
