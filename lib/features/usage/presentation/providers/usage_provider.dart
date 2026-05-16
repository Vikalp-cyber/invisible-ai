import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/repositories/usage_repository.dart';
import '../../domain/models/token_usage.dart';
import '../../domain/models/usage_exception.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final usageRepositoryProvider = Provider<UsageRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return UsageRepository(dio);
});

class UsageState {
  final TokenUsage? usage;
  final bool isLoading;
  final String? error;

  const UsageState({
    this.usage,
    this.isLoading = false,
    this.error,
  });

  UsageState copyWith({
    TokenUsage? usage,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return UsageState(
      usage: usage ?? this.usage,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UsageNotifier extends Notifier<UsageState> {
  // Do not use `late final` here — [build] can run again when dependencies change.
  UsageRepository get _repository => ref.read(usageRepositoryProvider);

  @override
  UsageState build() {
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated) {
        if (previous?.isAuthenticated != true) {
          Future.microtask(() => refreshUsage());
        }
      } else {
        state = const UsageState();
      }
    });

    return const UsageState();
  }

  Future<void> refreshUsage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final usage = await _repository.fetchUsage();
      state = state.copyWith(usage: usage, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is UsageException ? e.message : e.toString(),
      );
    }
  }

  Future<void> consumeTokens(int tokens, {String? reason}) async {
    if (tokens <= 0) return;
    
    // Optimistic update (optional, but good for UI responsiveness)
    if (state.usage != null) {
      final current = state.usage!;
      final newUsed = current.tokensUsed + tokens;
      final newRemaining = (current.tokenLimit - newUsed).clamp(0, current.tokenLimit);
      state = state.copyWith(
        usage: current.copyWith(
          tokensUsed: newUsed,
          tokensRemaining: newRemaining,
        ),
      );
    }

    try {
      final usage = await _repository.consumeTokens(tokens: tokens, reason: reason);
      state = state.copyWith(usage: usage);
    } catch (e) {
      // Sync local state to inactive if we hit the limit
      if (e is UsageException && (e.code == 'TOKEN_LIMIT_EXCEEDED' || e.code == 'ACCOUNT_INACTIVE')) {
        if (state.usage != null) {
          state = state.copyWith(
            usage: state.usage!.copyWith(isActive: false, tokensRemaining: 0),
            error: e.message,
          );
        } else {
          state = state.copyWith(error: e.message);
        }
      } else {
        state = state.copyWith(
          error: e is UsageException ? e.message : e.toString(),
        );
      }
      // Re-throw so caller (like Chat) can handle 403s
      rethrow;
    }
  }
}

final usageProvider = NotifierProvider<UsageNotifier, UsageState>(UsageNotifier.new);
