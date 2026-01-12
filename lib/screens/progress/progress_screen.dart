import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/xp_provider.dart';

/// Progress screen with GitHub-style activity heatmap
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final settings = ref.watch(settingsProvider);
    final xp = ref.watch(xpProvider);
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

    return Scaffold(
      backgroundColor: AppTheme.mintBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    'Progress',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // XP & Level Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.cardDecoration,
                      child: Column(
                        children: [
                          // Level badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlack,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Level ${xp.level} • ${xp.levelTitle}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // XP display
                          Text(
                            '${xp.totalXp}',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text('Total XP', style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 20),

                          // Level progress bar
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Level ${xp.level}',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                  Text(
                                    'Level ${xp.level + 1}',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppTheme.mintBackground,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: xp.levelProgress,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentBlack,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  '${xp.xpForNextLevel - xp.totalXp} XP to next level',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Stats Row
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
                          _buildHeatmapGrid(
                            context,
                            historyMap,
                            settings.dailyGoal,
                          ),
                          const SizedBox(height: 16),
                          // Legend
                          _buildLegend(context),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Recent Activity
                    Text(
                      'Recent Activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...history
                        .take(7)
                        .map(
                          (item) => _buildActivityItem(
                            context,
                            item,
                            settings.dailyGoal,
                          ),
                        ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
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
              ),
            ),
            Text(label, style: theme.textTheme.labelSmall),
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
          .map((m) => Text(m, style: theme.textTheme.labelSmall))
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

              return GestureDetector(
                onTap: () => _showDateDetails(context, date, steps, goal),
                child: Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: _getColorForIntensity(intensity),
                    borderRadius: BorderRadius.circular(2),
                  ),
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
        return const Color(0xFFD0D0D0); // Light grey
      case 2:
        return const Color(0xFFA0A0A0); // Medium grey
      case 3:
        return const Color(0xFF606060); // Dark grey
      case 4:
        return const Color(0xFF1A1A1A); // Black
      default:
        return AppTheme.mintBackground;
    }
  }

  Widget _buildLegend(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Less', style: theme.textTheme.labelSmall),
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
        Text('More', style: theme.textTheme.labelSmall),
      ],
    );
  }

  void _showDateDetails(
    BuildContext context,
    DateTime date,
    int steps,
    int goal,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(date),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              _formatNumber(steps),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text('steps', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (steps / goal).clamp(0.0, 1.0),
              backgroundColor: AppTheme.mintBackground,
              valueColor: AlwaysStoppedAnimation(
                steps >= goal ? AppTheme.accentBlack : AppTheme.textSecondary,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              steps >= goal
                  ? 'Goal reached! 🎉'
                  : '${goal - steps} steps to goal',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
          ],
        ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isGoalMet ? AppTheme.accentBlack : AppTheme.mintBackground,
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
                Text(dateLabel, style: theme.textTheme.titleSmall),
                Text(
                  '${_formatNumber(item.steps)} steps',
                  style: theme.textTheme.bodySmall,
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
        ],
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
