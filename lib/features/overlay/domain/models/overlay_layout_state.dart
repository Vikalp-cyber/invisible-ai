import 'dart:ui';

import 'overlay_mode.dart';

enum DockEdge {
  floating,
  left,
  right,
  top,
  bottom,
}

class OverlayLayoutState {
  const OverlayLayoutState({
    required this.position,
    required this.size,
    this.mode = OverlayMode.normal,
    this.dockEdge = DockEdge.floating,
    this.autoHideEnabled = false,
    this.expanded = true,
    this.opacity = 1.0,
    this.workspaceId = 'default',
  });

  final Offset position;
  final Size size;
  final OverlayMode mode;
  final DockEdge dockEdge;
  final bool autoHideEnabled;
  final bool expanded;
  final double opacity;
  final String workspaceId;

  OverlayLayoutState copyWith({
    Offset? position,
    Size? size,
    OverlayMode? mode,
    DockEdge? dockEdge,
    bool? autoHideEnabled,
    bool? expanded,
    double? opacity,
    String? workspaceId,
  }) {
    return OverlayLayoutState(
      position: position ?? this.position,
      size: size ?? this.size,
      mode: mode ?? this.mode,
      dockEdge: dockEdge ?? this.dockEdge,
      autoHideEnabled: autoHideEnabled ?? this.autoHideEnabled,
      expanded: expanded ?? this.expanded,
      opacity: opacity ?? this.opacity,
      workspaceId: workspaceId ?? this.workspaceId,
    );
  }
}
