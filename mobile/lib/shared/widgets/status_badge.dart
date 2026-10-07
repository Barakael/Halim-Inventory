import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = _colors(status.toUpperCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, Color) _colors(String s) {
    switch (s) {
      case 'VERIFIED':
        return (AppColors.success, AppColors.success.withAlpha(25));
      case 'SUBMITTED':
        return (AppColors.statusSubmitted, AppColors.statusSubmitted.withAlpha(25));
      case 'REJECTED':
        return (AppColors.error, AppColors.error.withAlpha(25));
      case 'CANCELLED':
        return (AppColors.grey500, AppColors.grey100);
      default:
        return (AppColors.grey600, AppColors.grey100);
    }
  }
}
