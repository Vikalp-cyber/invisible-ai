import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/client_runtime_config.dart';
import '../../domain/models/groq_runtime_config.dart';
import '../groq_config_repository.dart';

export '../../../../core/providers/deepgram_runtime_provider.dart';

final clientConfigRepositoryProvider = Provider<ClientConfigRepository>((ref) {
  return ClientConfigRepository(
    ref.watch(dioProvider),
    ref.watch(desktopOAuthConfigProvider),
  );
});

/// Loads Groq + optional Deepgram after sign-in. Keys stay in memory only.
///
/// Does not auto-retry on failure (e.g. HTTP 503 MISSING_GROQ_KEYS) — call
/// [ClientRuntimeConfigNotifier.refresh] or invalidate after backend fixes keys.
class ClientRuntimeConfigNotifier extends AsyncNotifier<ClientRuntimeConfig?> {
  @override
  Future<ClientRuntimeConfig?> build() async {
    ref.keepAlive();

    final authed = ref.watch(authProvider.select((a) => a.isAuthenticated));
    if (!authed) {
      return null;
    }

    final repo = ref.read(clientConfigRepositoryProvider);
    return repo.fetchClientRuntimeConfig();
  }

  Future<void> refresh() async {
    final authed = ref.read(authProvider).isAuthenticated;
    if (!authed) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(clientConfigRepositoryProvider).fetchClientRuntimeConfig();
    });
  }
}

final clientRuntimeConfigProvider =
    AsyncNotifierProvider<ClientRuntimeConfigNotifier, ClientRuntimeConfig?>(
  ClientRuntimeConfigNotifier.new,
);

/// Groq slice of [clientRuntimeConfigProvider] (settings UI, etc.).
final groqClientConfigProvider = Provider<AsyncValue<GroqRuntimeConfig?>>((ref) {
  return ref.watch(clientRuntimeConfigProvider).when(
        data: (config) => AsyncData(config?.groq),
        loading: () => const AsyncLoading(),
        error: AsyncError.new,
      );
});
