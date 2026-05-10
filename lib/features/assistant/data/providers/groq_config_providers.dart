import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../groq_config_repository.dart';
import '../../domain/models/groq_runtime_config.dart';

final groqConfigRepositoryProvider = Provider<GroqConfigRepository>((ref) {
  return GroqConfigRepository(
    ref.watch(dioProvider),
    ref.watch(desktopOAuthConfigProvider),
  );
});

/// Loads Groq key + models after sign-in. Key stays in [AIRepository] memory only.
final groqClientConfigProvider =
    FutureProvider.autoDispose<GroqRuntimeConfig?>((ref) async {
  final authed = ref.watch(authProvider.select((a) => a.isAuthenticated));
  if (!authed) {
    return null;
  }
  final repo = ref.read(groqConfigRepositoryProvider);
  return repo.fetchClientConfig();
});
