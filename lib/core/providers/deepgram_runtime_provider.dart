import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/deepgram_runtime_holder.dart';

/// In-memory Deepgram key(s) from client config. Cleared on logout.
final deepgramRuntimeHolderProvider = Provider<DeepgramRuntimeHolder>((ref) {
  final holder = DeepgramRuntimeHolder();
  ref.onDispose(holder.clear);
  return holder;
});
