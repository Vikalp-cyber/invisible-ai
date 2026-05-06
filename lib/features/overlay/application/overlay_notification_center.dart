import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class OverlayNotificationItem {
  const OverlayNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
}

class OverlayNotificationCenter extends Notifier<List<OverlayNotificationItem>> {
  @override
  List<OverlayNotificationItem> build() {
    ref.onDispose(() => _dismissTimer?.cancel());
    return const [];
  }

  Timer? _dismissTimer;

  void push({
    required String title,
    required String message,
    Duration autoDismiss = const Duration(seconds: 3),
  }) {
    final item = OverlayNotificationItem(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      message: message,
      createdAt: DateTime.now(),
    );
    state = [...state, item];
    _dismissTimer?.cancel();
    _dismissTimer = Timer(autoDismiss, () => remove(item.id));
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clear() {
    state = const [];
  }

}
