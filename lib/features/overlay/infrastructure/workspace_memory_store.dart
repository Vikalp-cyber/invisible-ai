import 'dart:convert';
import 'dart:ui';

import '../../../core/constants/app_constants.dart';
import '../../../services/preference_service.dart';
import '../domain/models/overlay_layout_state.dart';
import '../domain/models/overlay_mode.dart';

class WorkspaceMemoryStore {
  WorkspaceMemoryStore(this._prefs);

  final PreferenceService _prefs;

  Future<void> save(OverlayLayoutState state) async {
    double finiteOr(double value, double fallback) {
      return value.isFinite ? value : fallback;
    }

    final payload = <String, dynamic>{
      'x': finiteOr(state.position.dx, 100),
      'y': finiteOr(state.position.dy, 100),
      'width': finiteOr(state.size.width, AppConstants.defaultWindowSize.width),
      'height': finiteOr(state.size.height, AppConstants.defaultWindowSize.height),
      'mode': state.mode.key,
      'dockEdge': state.dockEdge.name,
      'autoHideEnabled': state.autoHideEnabled,
      'expanded': state.expanded,
      'opacity': finiteOr(state.opacity, 1.0).clamp(0.2, 1.0),
      'workspaceId': state.workspaceId,
    };
    await _prefs.setString(AppConstants.keyOverlayWorkspaceState, jsonEncode(payload));
  }

  OverlayLayoutState? read() {
    final json = _prefs.getString(
      AppConstants.keyOverlayWorkspaceState,
      defaultValue: '',
    );
    if (json.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final dockName = (map['dockEdge'] as String?) ?? DockEdge.floating.name;
      double finiteDecoded(num? value, double fallback) {
        final decoded = value?.toDouble() ?? fallback;
        return decoded.isFinite ? decoded : fallback;
      }

      return OverlayLayoutState(
        position: Offset(
          finiteDecoded(map['x'] as num?, 100),
          finiteDecoded(map['y'] as num?, 100),
        ),
        size: Size(
          finiteDecoded(
            map['width'] as num?,
            AppConstants.defaultWindowSize.width,
          ),
          finiteDecoded(
            map['height'] as num?,
            AppConstants.defaultWindowSize.height,
          ),
        ),
        mode: OverlayModeX.fromKey((map['mode'] as String?) ?? OverlayMode.normal.key),
        dockEdge: DockEdge.values.firstWhere(
          (value) => value.name == dockName,
          orElse: () => DockEdge.floating,
        ),
        autoHideEnabled: (map['autoHideEnabled'] as bool?) ?? false,
        expanded: (map['expanded'] as bool?) ?? true,
        opacity: finiteDecoded(map['opacity'] as num?, 1.0).clamp(0.2, 1.0),
        workspaceId: (map['workspaceId'] as String?) ?? 'default',
      );
    } catch (_) {
      return null;
    }
  }
}
