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
final clientRuntimeConfigProvider =
    FutureProvider.autoDispose<ClientRuntimeConfig?>((ref) async {
  final authed = ref.watch(authProvider.select((a) => a.isAuthenticated));
  if (!authed) {
    return null;
  }
  final repo = ref.read(clientConfigRepositoryProvider);
  return repo.fetchClientRuntimeConfig();
});

/// Groq slice of [clientRuntimeConfigProvider] (settings UI, etc.).
final groqClientConfigProvider =
    FutureProvider.autoDispose<GroqRuntimeConfig?>((ref) async {
  final full = await ref.watch(clientRuntimeConfigProvider.future);
  return full?.groq;
});
