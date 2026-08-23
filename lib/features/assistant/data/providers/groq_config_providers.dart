import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/common_providers.dart';
import '../../domain/models/groq_runtime_config.dart';
import '../../../../services/secure_storage_service.dart';

export '../../../../core/providers/deepgram_runtime_provider.dart';

/// Local Groq API keys loaded from [SecureStorageService] (no backend).
///
/// Order is the fallback rotation order used by [AIRepository].
class LocalGroqKeysNotifier extends AsyncNotifier<List<String>> {
  SecureStorageService get _storage => ref.read(secureStorageServiceProvider);

  @override
  Future<List<String>> build() async {
    ref.keepAlive();
    return _storage.getGroqApiKeys();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_storage.getGroqApiKeys);
  }

  Future<void> setKeys(List<String> keys) async {
    await _storage.saveGroqApiKeys(keys);
    state = AsyncData(await _storage.getGroqApiKeys());
  }

  Future<void> addKey(String apiKey) async {
    final next = await _storage.addGroqApiKey(apiKey);
    state = AsyncData(next);
  }

  Future<void> removeAt(int index) async {
    final next = await _storage.removeGroqApiKeyAt(index);
    state = AsyncData(next);
  }
}

final localGroqKeysProvider =
    AsyncNotifierProvider<LocalGroqKeysNotifier, List<String>>(
  LocalGroqKeysNotifier.new,
);

/// Runtime config built from locally stored Groq keys.
final localGroqRuntimeConfigProvider = Provider<AsyncValue<GroqRuntimeConfig?>>(
  (ref) {
    return ref.watch(localGroqKeysProvider).when(
          data: (keys) {
            if (keys.isEmpty) {
              return const AsyncData(null);
            }
            return AsyncData(
              GroqRuntimeConfig(
                apiKeys: keys,
                models: const [
                  GroqModelOption(
                    id: GroqModelIds.defaultChat,
                    label: 'GPT-OSS 120B',
                  ),
                  GroqModelOption(
                    id: 'openai/gpt-oss-20b',
                    label: 'GPT-OSS 20B',
                  ),
                ],
                defaultModel: GroqModelIds.defaultChat,
                chatModel: GroqModelIds.defaultChat,
              ),
            );
          },
          loading: () => const AsyncLoading(),
          error: AsyncError.new,
        );
  },
);

/// Backward-compatible alias used by payment/settings code paths.
final groqClientConfigProvider = localGroqRuntimeConfigProvider;
