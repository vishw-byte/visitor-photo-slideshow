import 'package:flutter/material.dart';
import '../../data/models/photo_model.dart';
import '../../core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final PhotoStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case PhotoStatus.approved:
        bgColor = AppTheme.successColor.withAlpha(30);
        textColor = const Color(0xFF047857); // Emerald 700
        icon = Icons.check_circle_outline;
        break;
      case PhotoStatus.rejected:
        bgColor = AppTheme.errorColor.withAlpha(30);
        textColor = const Color(0xFFB91C1C); // Red 700
        icon = Icons.highlight_off;
        break;
      case PhotoStatus.pending:
        bgColor = AppTheme.warningColor.withAlpha(35);
        textColor = const Color(0xFFB45309); // Amber 700
        icon = Icons.schedule;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withAlpha(50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(
            status.displayName,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
