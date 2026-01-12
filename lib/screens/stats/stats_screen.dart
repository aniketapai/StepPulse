import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/step_provider.dart';
import '../../models/step_data.dart';

/// Stats screen content (for use in nav shell)
class StatsContent extends ConsumerWidget {
  const StatsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final settings = ref.watch(settingsProvider);
    final stepState = ref.watch(stepProvider);
    final theme = Theme.of(context);

    // Include today's steps in calculations
    final todaySteps = stepState.todaySteps;

    // Calculate stats (including today)
    final totalSteps =
        history.fold<int>(0, (sum, item) => sum + item.steps) + todaySteps;
    final daysCount = history.length + (todaySteps > 0 ? 1 : 0);
    final avgSteps = daysCount > 0 ? totalSteps ~/ daysCount : 0;
    final bestDayFromHistory = history.isNotEmpty
        ? history.reduce((a, b) => a.steps > b.steps ? a : b)
        : null;
    final bestDaySteps = bestDayFromHistory != null
        ? (todaySteps > bestDayFromHistory.steps
              ? todaySteps
              : bestDayFromHistory.steps)
        : todaySteps;
    final bestDayLabel = bestDayFromHistory != null
        ? (todaySteps > bestDayFromHistory.steps
              ? 'Today'
              : DateFormat(
                  'MMM d',
                ).format(DateTime.parse(bestDayFromHistory.date)))
        : (todaySteps > 0 ? 'Today' : 'no data');
    final daysWithGoal =
        history.where((h) => h.steps >= settings.dailyGoal).length +
        (todaySteps >= settings.dailyGoal ? 1 : 0);

    // Get weekly data for chart (including today)
    final weeklyDataFromHistory = history.take(6).toList().reversed.toList();
    final weeklyData = [
      ...weeklyDataFromHistory,
      if (todaySteps > 0)
        StepData(
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          steps: todaySteps,
        ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Title
              Center(
                child: Text(
                  'Statistics',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Weekly Graph Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Week',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 200,
                      child: weeklyData.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.show_chart_rounded,
                                    size: 48,
                                    color: AppTheme.textSecondary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No activity yet',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Start walking to see your chart!',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildLineChart(
                              weeklyData,
                              settings.dailyGoal,
                              theme,
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Total Steps',
                      value: _formatNumber(totalSteps),
                      subtitle: 'all time',
                      icon: Icons.directions_walk_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Average',
                      value: _formatNumber(avgSteps),
                      subtitle: 'per day',
                      icon: Icons.analytics_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Best Day',
                      value: _formatNumber(bestDaySteps),
                      subtitle: bestDayLabel,
                      icon: Icons.emoji_events_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Goals Hit',
                      value: daysWithGoal.toString(),
                      subtitle: 'of ${history.length} days',
                      icon: Icons.flag_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Weekly Comparison
              Text(
                'Daily Breakdown',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration,
                child: weeklyData.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 40,
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Your daily activity will appear here',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: weeklyData.map((day) {
                          return _buildDayRow(context, day, settings.dailyGoal);
                        }).toList(),
                      ),
              ),

              const SizedBox(height: 120), // Space for nav bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(List<StepData> data, int goal, ThemeData theme) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxY =
        data.fold<int>(
          goal,
          (max, item) => item.steps > max ? item.steps : max,
        ) *
        1.2;

    return LineChart(
      LineChartData(
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
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          // Goal line
          LineChartBarData(
            spots: List.generate(
              data.length,
              (i) => FlSpot(i.toDouble(), goal.toDouble()),
            ),
            isCurved: false,
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
            barWidth: 1,
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
          ),
          // Steps line
          LineChartBarData(
            spots: data.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.steps.toDouble());
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppTheme.accentBlack,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: AppTheme.accentBlack,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.accentBlack.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.accentBlack,
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toInt()} steps',
                  TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.mintBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.textPrimary, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(BuildContext context, StepData day, int goal) {
    final theme = Theme.of(context);
    final date = DateTime.parse(day.date);
    final progress = (day.steps / goal).clamp(0.0, 1.0);
    final isGoalMet = day.steps >= goal;

    // Format date
    String dateLabel;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      dateLabel = 'Today';
    } else if (itemDate == today.subtract(const Duration(days: 1))) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('EEEE').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              dateLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
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
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              _formatNumber(day.steps),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isGoalMet ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: isGoalMet ? AppTheme.accentBlack : AppTheme.textSecondary,
            size: 16,
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
