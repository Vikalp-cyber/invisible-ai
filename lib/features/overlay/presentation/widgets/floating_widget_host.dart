import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class FloatingWidgetHost extends StatelessWidget {
  const FloatingWidgetHost({
    super.key,
    required this.visible,
  });

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: 10,
      top: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.glassBorder, width: 1),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            'Focus Widget',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 11),
          ),
        ),
      ),
    );
  }
}
