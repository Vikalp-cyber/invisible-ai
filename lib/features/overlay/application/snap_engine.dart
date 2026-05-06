import 'dart:ui';

import '../domain/models/overlay_layout_state.dart';

class SnapResult {
  const SnapResult({
    required this.position,
    required this.edge,
  });

  final Offset position;
  final DockEdge edge;
}

class SnapEngine {
  const SnapEngine({this.threshold = 28});

  final double threshold;

  SnapResult resolve({
    required Offset position,
    required Size size,
    required Size screenSize,
  }) {
    final nearLeft = position.dx <= threshold;
    final nearRight = (screenSize.width - (position.dx + size.width)) <= threshold;
    final nearTop = position.dy <= threshold;
    final nearBottom = (screenSize.height - (position.dy + size.height)) <= threshold;

    if (nearLeft) {
      return const SnapResult(position: Offset(0, 0), edge: DockEdge.left);
    }
    if (nearRight) {
      return SnapResult(
        position: Offset(screenSize.width - size.width, 0),
        edge: DockEdge.right,
      );
    }
    if (nearTop) {
      return const SnapResult(position: Offset(0, 0), edge: DockEdge.top);
    }
    if (nearBottom) {
      return SnapResult(
        position: Offset(0, screenSize.height - size.height),
        edge: DockEdge.bottom,
      );
    }
    return SnapResult(position: position, edge: DockEdge.floating);
  }
}
