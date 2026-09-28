import 'package:flutter/material.dart';
import '../../../../core/accessibility/accessibility_constants.dart';
import '../../../../core/audio/haptic_feedback_service.dart';
import '../../../../core/constants/app_colors.dart';

/// An accessibility-first large touch card designed for visually impaired users.
class AccessibleTouchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final String semanticHint;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final double minHeight;

  const AccessibleTouchCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    required this.semanticHint,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.surfaceBorder,
    this.textColor = AppColors.textLight,
    this.minHeight = AccessibilityConstants.primaryActionHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      enabled: true,
      excludeSemantics: true,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          AccessibilityConstants.borderRadius,
        ),
        child: InkWell(
          onTap: () {
            HapticFeedbackService.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(
            AccessibilityConstants.borderRadius,
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AccessibilityConstants.borderRadius,
              ),
              border: Border.all(
                color: borderColor,
                width: AccessibilityConstants.borderWidth,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 48.0, color: borderColor),
                const SizedBox(width: 20.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: AccessibilityConstants.titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: textColor.withAlpha(220),
                          fontSize: AccessibilityConstants.bodyFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
