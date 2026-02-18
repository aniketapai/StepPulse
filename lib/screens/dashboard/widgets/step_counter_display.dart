import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Animated step counter display widget
class StepCounterDisplay extends StatelessWidget {
  final int steps;
  final int goal;
  final Color? accentColor;
  final Color? accentBgColor;

  const StepCounterDisplay({
    super.key,
    required this.steps,
    required this.goal,
    this.accentColor,
    this.accentBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = ((steps / goal) * 100).clamp(0, 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated step count
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: steps),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Text(
              _formatNumber(value),
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryC(context),
                fontSize: 48,
                letterSpacing: -1,
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        // Steps label with percentage
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'steps',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryC(context),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accentBgColor ?? AppTheme.bg(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$percentage%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accentColor ?? AppTheme.textSecondaryC(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Format number with space separators (like in reference: 6 859)
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}
