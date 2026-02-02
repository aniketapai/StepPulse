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
class StatsContent extends ConsumerStatefulWidget {
  const StatsContent({super.key});

  @override
  ConsumerState<StatsContent> createState() => _StatsContentState();
}

class _StatsContentState extends ConsumerState<StatsContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create staggered animations for 5 elements
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

    _slideAnimations = List.generate(5, (index) {
      final start = index * 0.12;
      final end = start + 0.4;
      return Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(
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
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(position: _slideAnimations[index], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final settings = ref.watch(settingsProvider);
    final stepState = ref.watch(stepProvider);
    final theme = Theme.of(context);

    // Classic theme colors
    const accentColor = AppTheme.accentBlack;
    const accentBgColor = AppTheme.mintBackground;

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
    // Filter out today from history to avoid duplicates (we add today's live steps separately)
    final todayDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final weeklyDataFromHistory = history
        .where((item) => item.date != todayDateStr)
        .take(6)
        .toList()
        .reversed
        .toList();
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
        // ClampingScrollPhysics for smoother, more predictable scrolling
        physics: const ClampingScrollPhysics(),
        child: Padding(
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
                    'Statistics',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Weekly Graph Card - animated
              _buildAnimatedChild(
                1,
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
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Start walking to see your chart!',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondary
                                                .withValues(alpha: 0.7),
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            : _buildLineChart(
                                weeklyData,
                                settings.dailyGoal,
                                theme,
                                accentColor,
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Stats Grid - animated
              _buildAnimatedChild(
                2,
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Total Steps',
                        value: _formatNumber(totalSteps),
                        subtitle: 'all time',
                        icon: Icons.directions_walk_rounded,
                        accentColor: accentColor,
                        accentBgColor: accentBgColor,
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
                        accentColor: accentColor,
                        accentBgColor: accentBgColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _buildAnimatedChild(
                3,
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Best Day',
                        value: _formatNumber(bestDaySteps),
                        subtitle: bestDayLabel,
                        icon: Icons.emoji_events_rounded,
                        accentColor: accentColor,
                        accentBgColor: accentBgColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Goals Hit',
                        value: daysWithGoal.toString(),
                        subtitle: 'total',
                        icon: Icons.flag_rounded,
                        accentColor: accentColor,
                        accentBgColor: accentBgColor,
                      ),
                    ),
                  ],
                ),
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
                          return _buildDayRow(
                            context,
                            day,
                            settings.dailyGoal,
                            accentColor,
                          );
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

  Widget _buildLineChart(
    List<StepData> data,
    int goal,
    ThemeData theme,
    Color accentColor,
  ) {
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
            color: accentColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: accentColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: accentColor.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => accentColor,
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
    required Color accentColor,
    required Color accentBgColor,
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
              color: accentBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 20),
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

  Widget _buildDayRow(
    BuildContext context,
    StepData day,
    int goal,
    Color accentColor,
  ) {
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
                    color: isGoalMet ? accentColor : AppTheme.textSecondary,
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
            color: isGoalMet ? accentColor : AppTheme.textSecondary,
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
