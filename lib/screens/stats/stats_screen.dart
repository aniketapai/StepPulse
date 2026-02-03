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

  // Time filter selection
  int _selectedFilter = 1; // 0=1d, 1=1w, 2=1m, 3=1y, 4=All Time
  final List<String> _filterLabels = ['1d', '1w', '1m', '1y', 'All'];

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

  /// Get data based on selected filter
  List<StepData> _getFilteredData(List<StepData> history, int todaySteps) {
    final now = DateTime.now();
    final todayDateStr = DateFormat('yyyy-MM-dd').format(now);

    // Filter out today from history to avoid duplicates
    final historyWithoutToday = history
        .where((item) => item.date != todayDateStr)
        .toList();

    int daysToShow;
    switch (_selectedFilter) {
      case 0: // 1 day - just today
        return [
          if (todaySteps > 0) StepData(date: todayDateStr, steps: todaySteps),
        ];
      case 1: // 1 week
        daysToShow = 7;
        break;
      case 2: // 1 month
        daysToShow = 30;
        break;
      case 3: // 1 year
        daysToShow = 365;
        break;
      case 4: // All time
        daysToShow = historyWithoutToday.length + 1;
        break;
      default:
        daysToShow = 7;
    }

    final data = historyWithoutToday
        .take(daysToShow - 1)
        .toList()
        .reversed
        .toList();

    // Add today's steps if available
    if (todaySteps > 0) {
      data.add(StepData(date: todayDateStr, steps: todaySteps));
    }

    return data;
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

    // Get filtered data for chart
    final chartData = _getFilteredData(history, todaySteps);

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
    final daysWithGoal =
        history.where((h) => h.steps >= settings.dailyGoal).length +
        (todaySteps >= settings.dailyGoal ? 1 : 0);

    return SafeArea(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Header with step count
              _buildAnimatedChild(
                0,
                _buildHeader(context, todaySteps, settings.dailyGoal),
              ),

              const SizedBox(height: 24),

              // Time filter tabs
              _buildAnimatedChild(1, _buildFilterTabs(context)),

              const SizedBox(height: 20),

              // Bar Chart Card
              _buildAnimatedChild(
                2,
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 220,
                    child: chartData.isEmpty
                        ? _buildEmptyChart(context)
                        : _buildBarChart(
                            chartData,
                            settings.dailyGoal,
                            theme,
                            accentColor,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Check if we have any data at all
              if (history.isEmpty && todaySteps == 0) ...[
                // Zero state - no data yet
                _buildAnimatedChild(
                  3,
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.directions_walk_rounded,
                          size: 48,
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your stats will appear after your first walk 👟',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Stats Grid - only show when data exists
                _buildAnimatedChild(
                  3,
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

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Best Day',
                        value: _formatNumber(bestDaySteps),
                        subtitle: 'personal best',
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
              ],

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int todaySteps, int goal) {
    final theme = Theme.of(context);
    final stepsLeft = (goal - todaySteps).clamp(0, goal);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.mintBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.directions_walk_rounded,
                color: AppTheme.accentBlack,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatNumber(todaySteps),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'steps',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          stepsLeft > 0
              ? 'Take $stepsLeft more steps today!'
              : 'Goal achieved! 🎉',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.mintBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(_filterLabels.length, (index) {
          final isSelected = _selectedFilter == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _filterLabels[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.accentBlack
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyChart(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 48,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
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
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(
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

    // Limit displayed bars for readability
    final displayData = data.length > 14
        ? data.sublist(data.length - 14)
        : data;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
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
        borderData: FlBorderData(show: false),
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
                if (index < 0 || index >= displayData.length) {
                  return const Text('');
                }

                final date = DateTime.parse(displayData[index].date);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: displayData.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isGoalMet = item.steps >= goal;

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: item.steps.toDouble(),
                width: displayData.length > 10 ? 12 : 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isGoalMet
                      ? [
                          AppTheme.accentBlack.withValues(alpha: 0.7),
                          AppTheme.accentBlack,
                        ]
                      : [
                          AppTheme.textSecondary.withValues(alpha: 0.4),
                          AppTheme.textSecondary.withValues(alpha: 0.6),
                        ],
                ),
              ),
            ],
          );
        }).toList(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => accentColor,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} steps',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
