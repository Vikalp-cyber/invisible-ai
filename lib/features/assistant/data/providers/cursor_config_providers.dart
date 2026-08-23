import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/common_providers.dart';
import '../../domain/models/cursor_runtime_config.dart';
import '../../../../services/secure_storage_service.dart';

/// Local Cursor API keys loaded from [SecureStorageService] (no backend).
class LocalCursorKeysNotifier extends AsyncNotifier<List<String>> {
  SecureStorageService get _storage => ref.read(secureStorageServiceProvider);

  @override
  Future<List<String>> build() async {
    ref.keepAlive();
    return _storage.getCursorApiKeys();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_storage.getCursorApiKeys);
  }

  Future<void> addKey(String apiKey) async {
    final next = await _storage.addCursorApiKey(apiKey);
    state = AsyncData(next);
  }

  Future<void> removeAt(int index) async {
    final next = await _storage.removeCursorApiKeyAt(index);
    state = AsyncData(next);
  }
}

final localCursorKeysProvider =
    AsyncNotifierProvider<LocalCursorKeysNotifier, List<String>>(
  LocalCursorKeysNotifier.new,
);

final localCursorRuntimeConfigProvider =
    Provider<AsyncValue<CursorRuntimeConfig?>>(
  (ref) {
    return ref.watch(localCursorKeysProvider).when(
          data: (keys) {
            if (keys.isEmpty) {
              return const AsyncData(null);
            }
            return AsyncData(
              CursorRuntimeConfig(apiKeys: keys),
            );
          },
          loading: () => const AsyncLoading(),
          error: AsyncError.new,
        );
  },
);
