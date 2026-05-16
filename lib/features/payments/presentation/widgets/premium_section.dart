import 'package:flutter/material.dart';

import 'upgrade_card.dart';

/// Premium subscription block for the Settings dialog (General tab).
class PremiumSection extends StatelessWidget {
  const PremiumSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upgrade to Premium',
          style: TextStyle(
            color: Color(0xFFB0B3C5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        UpgradeCard(),
        SizedBox(height: 8),
      ],
    );
  }
}
