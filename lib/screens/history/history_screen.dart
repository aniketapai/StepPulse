import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/step_data.dart';
import '../../core/theme/app_theme.dart';

/// History screen showing step history
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    // Get last 7 days for chart
    final chartData = history.take(7).toList().reversed.toList();

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
                    'Statistics',
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
              child: history.isEmpty
                  ? _buildEmptyState(theme)
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Chart card
                          if (chartData.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: AppTheme.cardDecoration,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Last 7 Days',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    height: 180,
                                    child: _buildChart(
                                      chartData,
                                      settings.dailyGoal,
                                      theme,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Activity Log header
                          Text(
                            'Activity Log',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // History list
                          ...history.asMap().entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildHistoryItem(
                                context,
                                entry.value,
                                settings.dailyGoal,
                                entry.key == 0,
                              ),
                            );
                          }),

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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(40),
        decoration: AppTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.mintBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                size: 48,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No history yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start walking to record your steps!',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build bar chart for history
  Widget _buildChart(List<StepData> data, int goal, ThemeData theme) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxSteps = data.fold<int>(
      goal,
      (max, item) => item.steps > max ? item.steps : max,
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: maxSteps * 1.2,
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isGoalMet = item.steps >= goal;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: item.steps.toDouble(),
                color: isGoalMet
                    ? AppTheme.accentBlack
                    : AppTheme.textSecondary,
                width: 24,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const Text('');

                final date = DateTime.parse(data[index].date);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('E').format(date),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: goal.toDouble(),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppTheme.textSecondary.withValues(alpha: 0.2),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppTheme.accentBlack,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final steps = rod.toY.toInt();
              return BarTooltipItem(
                '$steps steps',
                theme.textTheme.labelSmall!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build history list item
  Widget _buildHistoryItem(
    BuildContext context,
    StepData item,
    int goal,
    bool isToday,
  ) {
    final theme = Theme.of(context);
    final date = DateTime.parse(item.date);
    final progress = (item.steps / goal).clamp(0.0, 1.0);
    final isGoalMet = item.steps >= goal;

    // Format date label
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
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          // Date column
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLabel, style: theme.textTheme.titleSmall),
                if (!isToday)
                  Text(
                    DateFormat('EEEE').format(date),
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ),

          // Progress bar
          Expanded(
            child: Container(
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.mintBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: isGoalMet
                        ? AppTheme.accentBlack
                        : AppTheme.textSecondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          // Steps count
          Row(
            children: [
              Text(
                _formatNumber(item.steps),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              if (isGoalMet)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentBlack,
                  size: 18,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format number with commas
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
