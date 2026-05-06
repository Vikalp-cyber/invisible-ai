import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/overlay_layout_state.dart';

class SnapPreviewOverlay extends StatelessWidget {
  const SnapPreviewOverlay({
    super.key,
    required this.edge,
  });

  final DockEdge edge;

  @override
  Widget build(BuildContext context) {
    if (edge == DockEdge.floating) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
          color: AppColors.primary.withValues(alpha: 0.06),
        ),
      ),
    );
  }
}
