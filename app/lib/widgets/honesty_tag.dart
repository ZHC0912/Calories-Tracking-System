import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A small muted chip that communicates how trustworthy a portion number is
/// (e.g. "from 250 g", "estimated"). Keeping this visible is the app's honesty
/// contract: it never dresses up an estimate as a precise measurement.
class HonestyTag extends StatelessWidget {
  final String label;
  final IconData icon;

  const HonestyTag({super.key, required this.label, this.icon = Icons.straighten});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.tagBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.tagText),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.tagText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
