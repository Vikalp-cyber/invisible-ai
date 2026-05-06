import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class DockHandle extends StatelessWidget {
  const DockHandle({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 5,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
