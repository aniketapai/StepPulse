import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/history_provider.dart';
import '../../providers/step_provider.dart';
import '../../providers/settings_provider.dart';

/// Progress screen content (for use in nav shell)
class ProgressContent extends ConsumerStatefulWidget {
  const ProgressContent({super.key});

  @override
  ConsumerState<ProgressContent> createState() => _ProgressContentState();
}

class _ProgressContentState extends ConsumerState<ProgressContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create staggered fade animations for 5 elements
    _fadeAnimations = List.generate(5, (index) {
      final start = index * 0.12;
      final end = start + 0.4;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedChild(int index, Widget child) {
    return FadeTransition(opacity: _fadeAnimations[index], child: child);
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final settings = ref.watch(settingsProvider);
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    // Get history map for heatmap
    final historyMap = storage.getHistoryMap(days: 365);

    // Calculate stats
    final totalSteps = history.fold<int>(0, (sum, item) => sum + item.steps);
    final avgSteps = history.isNotEmpty ? totalSteps ~/ history.length : 0;
    final daysWithGoal = history
        .where((h) => h.steps >= settings.dailyGoal)
        .length;

    // Calculate current streak
    int currentStreak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final steps = historyMap[dateStr] ?? 0;
      if (steps > 0) {
        currentStreak++;
      } else if (i > 0) {
        break;
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        // ClampingScrollPhysics for smoother, more controlled scrolling
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Title - animated
            _buildAnimatedChild(
              0,
              Center(
                child: Text(
                  'Progress',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Quick Stats Row - animated
            _buildAnimatedChild(
              1,
              Row(
                children: [
                  _buildStatBox(
                    context,
                    value: currentStreak.toString(),
                    label: 'Day Streak',
                    icon: Icons.local_fire_department_rounded,
                  ),
                  const SizedBox(width: 12),
                  _buildStatBox(
                    context,
                    value: daysWithGoal.toString(),
                    label: 'Goals Hit',
                    icon: Icons.flag_rounded,
                  ),
                  const SizedBox(width: 12),
                  _buildStatBox(
                    context,
                    value: _formatNumber(avgSteps),
                    label: 'Avg Steps',
                    icon: Icons.trending_up_rounded,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Activity Heatmap
            Text(
              'Activity',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month labels
                  _buildMonthLabels(context),
                  const SizedBox(height: 8),
                  // Heatmap grid
                  _buildHeatmapGrid(context, historyMap, settings.dailyGoal),
                  const SizedBox(height: 16),
                  // Legend
                  _buildLegend(context),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Today's Activity
            Text(
              'Today\'s Activity',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildTodayCard(context, ref),

            const SizedBox(height: 24),

            // Recent Activity
            Text(
              'Recent Activity',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            if (history.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: AppTheme.cardDecoration,
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 48,
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No activity recorded yet',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check back tomorrow!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...history
                  .take(5)
                  .map(
                    (item) =>
                        _buildActivityItem(context, item, settings.dailyGoal),
                  ),

            const SizedBox(height: 120), // Space for nav bar
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Column(
          children: [
            Icon(icon, color: AppTheme.textSecondary, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthLabels(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final months = <String>[];

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat('MMM').format(month));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: months
          .map(
            (m) => Text(
              m,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildHeatmapGrid(
    BuildContext context,
    Map<String, int> historyMap,
    int goal,
  ) {
    final now = DateTime.now();
    final weeks = <List<DateTime>>[];

    // Build 26 weeks (roughly 6 months)
    for (int w = 25; w >= 0; w--) {
      final weekDays = <DateTime>[];
      for (int d = 0; d < 7; d++) {
        final date = now.subtract(Duration(days: w * 7 + (6 - d)));
        weekDays.add(date);
      }
      weeks.add(weekDays);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: weeks.map((week) {
          return Column(
            children: week.map((date) {
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final steps = historyMap[dateStr] ?? 0;
              final intensity = _getIntensity(steps, goal);

              return Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: _getColorForIntensity(intensity),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  int _getIntensity(int steps, int goal) {
    if (steps == 0) return 0;
    final ratio = steps / goal;
    if (ratio >= 1.0) return 4;
    if (ratio >= 0.75) return 3;
    if (ratio >= 0.5) return 2;
    if (ratio >= 0.25) return 1;
    return 1;
  }

  Color _getColorForIntensity(int intensity) {
    switch (intensity) {
      case 0:
        return AppTheme.mintBackground;
      case 1:
        return const Color(0xFFD0D0D0);
      case 2:
        return const Color(0xFFA0A0A0);
      case 3:
        return const Color(0xFF606060);
      case 4:
        return const Color(0xFF1A1A1A);
      default:
        return AppTheme.mintBackground;
    }
  }

  Widget _buildLegend(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Less',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(
          5,
          (i) => Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _getColorForIntensity(i),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'More',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Build Today's activity card showing current date and live steps
  Widget _buildTodayCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stepState = ref.watch(stepProvider);
    final settings = ref.watch(settingsProvider);
    final todaySteps = stepState.todaySteps;
    final isGoalMet = todaySteps >= settings.dailyGoal;
    final now = DateTime.now();
    final fullDate = DateFormat('EEEE, MMMM d, yyyy').format(now);

    return GestureDetector(
      onTap: () => _showActivityDialog(
        context,
        date: fullDate,
        steps: todaySteps,
        goal: settings.dailyGoal,
        isToday: true,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration.copyWith(
          border: Border.all(
            color: AppTheme.accentBlack.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isGoalMet
                    ? AppTheme.accentBlack
                    : AppTheme.mintBackground.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isGoalMet
                    ? Icons.emoji_events_rounded
                    : Icons.directions_walk_rounded,
                color: isGoalMet ? Colors.white : AppTheme.accentBlack,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Today',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlack.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat('MMM d').format(now),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.accentBlack,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatNumber(todaySteps)} steps',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Show activity detail dialog
  void _showActivityDialog(
    BuildContext context, {
    required String date,
    required int steps,
    required int goal,
    bool isToday = false,
  }) {
    final theme = Theme.of(context);
    final isGoalMet = steps >= goal;
    final xpEarned = (steps * 0.01).round() + (isGoalMet ? 50 : 0);
    final progress = goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isToday ? Icons.today_rounded : Icons.calendar_today_rounded,
              color: AppTheme.accentBlack,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                date,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Steps count
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.mintBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    _formatNumber(steps),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'steps',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.mintBackground,
                      valueColor: AlwaysStoppedAnimation(
                        isGoalMet
                            ? AppTheme.accentBlack
                            : AppTheme.textSecondary,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Goal and XP info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Goal: ${_formatNumber(goal)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '+$xpEarned XP',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.accentBlack,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isGoalMet) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlack,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Goal Achieved!',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppTheme.accentBlack)),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, dynamic item, int goal) {
    final theme = Theme.of(context);
    final date = DateTime.parse(item.date);
    final isGoalMet = item.steps >= goal;

    String dateLabel;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      dateLabel = 'Today';
    } else if (itemDate == today.subtract(const Duration(days: 1))) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('MMM d').format(date);
    }

    final fullDate = DateFormat('EEEE, MMMM d, yyyy').format(date);

    return GestureDetector(
      onTap: () => _showActivityDialog(
        context,
        date: fullDate,
        steps: item.steps,
        goal: goal,
        isToday: itemDate == today,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isGoalMet
                    ? AppTheme.accentBlack
                    : AppTheme.mintBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isGoalMet ? Icons.check_rounded : Icons.directions_walk_rounded,
                color: isGoalMet ? Colors.white : AppTheme.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${_formatNumber(item.steps)} steps',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '+${((item.steps * 0.01).round() + (isGoalMet ? 50 : 0))} XP',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppTheme.accentBlack,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
