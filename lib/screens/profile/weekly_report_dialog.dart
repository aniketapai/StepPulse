import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class WeeklyReportDialog extends StatefulWidget {
  final List<Map<String, dynamic>> weeklyData;
  final Map<String, int> allTimeHistory;
  final int dailyGoal;
  final VoidCallback onDismiss;

  const WeeklyReportDialog({
    super.key,
    required this.weeklyData,
    required this.allTimeHistory,
    required this.dailyGoal,
    required this.onDismiss,
  });

  @override
  State<WeeklyReportDialog> createState() => _WeeklyReportDialogState();
}

class _WeeklyReportDialogState extends State<WeeklyReportDialog>
    with TickerProviderStateMixin {
  bool _showContent = false;
  late AnimationController _typingController;
  late AnimationController _contentController;
  late Animation<double> _contentAnimation;

  @override
  void initState() {
    super.initState();

    // Typing indicator animation
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    // Content fade-in animation
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _contentAnimation = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    );

    // Show typing for 1.2 seconds, then reveal content
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _showContent = true);
        _contentController.forward();
      }
    });
  }

  @override
  void dispose() {
    _typingController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _calculateStats();
    final deepInsights = _computeDeepInsights();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bot header
            _buildBotHeader(theme),

            // Chat area
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_showContent) _buildTypingIndicator(),
                  if (_showContent) ...[
                    FadeTransition(
                      opacity: _contentAnimation,
                      child: _buildBotContent(theme, stats, deepInsights),
                    ),
                  ],
                ],
              ),
            ),

            // Close button
            if (_showContent)
              FadeTransition(
                opacity: _contentAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent(context),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Thanks, StepBot! 👋',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accent(context),
            AppTheme.accent(context).withValues(alpha: 0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          // Bot avatar with glow
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.subtleBg(context).withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              color: AppTheme.accent(context),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'StepBot',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Your fitness assistant',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // Close button
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.sheetBg(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _typingController,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final delay = index * 0.2;
              final value = ((_typingController.value + delay) % 1.0);
              final bounce = value < 0.5 ? value * 2 : (1 - value) * 2;
              return Container(
                margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                child: Transform.translate(
                  offset: Offset(0, -3 * bounce),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondaryC(
                        context,
                      ).withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildBotContent(
    ThemeData theme,
    _WeeklyStats stats,
    _DeepInsights insights,
  ) {
    final greeting = _getGreeting();
    final dateRange = _getDateRange();
    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting bubble
        _buildChatBubble(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting 👋',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryC(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Here's your weekly report for $dateRange:",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryC(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Stats bubble
        _buildChatBubble(
          child: Column(
            children: [
              // Mini bar chart
              SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(widget.weeklyData.length, (index) {
                    final day = widget.weeklyData[index];
                    final steps = day['steps'] as int? ?? 0;
                    final goal = day['goal'] as int? ?? kDefaultDailyGoal;
                    final hitGoal = steps >= goal;
                    final maxSteps = stats.maxSteps > 0 ? stats.maxSteps : goal;
                    final barHeight = (steps / maxSteps * 60).clamp(4.0, 60.0);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: hitGoal
                                    ? Colors.green.shade400
                                    : AppTheme.grey300(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dayNames[index % 7],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: hitGoal
                                    ? Colors.green.shade600
                                    : AppTheme.textSecondaryC(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Stats row
              Row(
                children: [
                  _buildMiniStat(
                    icon: Icons.directions_walk_rounded,
                    value: _formatNumber(stats.totalSteps),
                    label: 'steps',
                    color: AppTheme.accent(context),
                  ),
                  _buildMiniStat(
                    icon: Icons.flag_rounded,
                    value: '${stats.goalsHit}/${widget.weeklyData.length}',
                    label: 'goals',
                    color: Colors.orange,
                  ),
                  _buildMiniStat(
                    icon: Icons.local_fire_department_rounded,
                    value: _formatNumber(stats.totalCalories),
                    label: 'cal',
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Insights bubble
        _buildChatBubble(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stats.bestDayIndex >= 0) ...[
                Row(
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Best day: ${stats.bestDayName} with ${_formatNumber(stats.maxSteps)} steps!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textPrimaryC(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.goalsHit >= 5
                        ? '🔥'
                        : stats.goalsHit >= 3
                        ? '💪'
                        : '🚶',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getInsight(stats),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textPrimaryC(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Deep Insights bubble
        _buildDeepInsights(theme, insights),
      ],
    );
  }

  Widget _buildChatBubble({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.sheetBg(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryC(context),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondaryC(context),
            ),
          ),
        ],
      ),
    );
  }

  _WeeklyStats _calculateStats() {
    int totalSteps = 0;
    int goalsHit = 0;
    int totalCalories = 0;
    int maxSteps = 0;
    int bestDayIndex = -1;

    for (var i = 0; i < widget.weeklyData.length; i++) {
      final day = widget.weeklyData[i];
      final steps = day['steps'] as int? ?? 0;
      final goal = day['goal'] as int? ?? kDefaultDailyGoal;

      totalSteps += steps;
      totalCalories += (steps * kCaloriesPerStep).round();

      if (steps >= goal) goalsHit++;
      if (steps > maxSteps) {
        maxSteps = steps;
        bestDayIndex = i;
      }
    }

    // Get best day name
    String bestDayName = '';
    if (bestDayIndex >= 0 && widget.weeklyData.isNotEmpty) {
      final dateStr = widget.weeklyData[bestDayIndex]['date'] as String?;
      if (dateStr != null) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          final dayNames = [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];
          bestDayName = dayNames[date.weekday - 1];
        }
      }
    }

    return _WeeklyStats(
      totalSteps: totalSteps,
      goalsHit: goalsHit,
      totalCalories: totalCalories,
      maxSteps: maxSteps,
      bestDayIndex: bestDayIndex,
      bestDayName: bestDayName,
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getDateRange() {
    if (widget.weeklyData.isEmpty) return 'this week';

    final firstDate = widget.weeklyData.first['date'] as String?;
    final lastDate = widget.weeklyData.last['date'] as String?;

    if (firstDate == null || lastDate == null) return 'this week';

    final first = DateTime.tryParse(firstDate);
    final last = DateTime.tryParse(lastDate);

    if (first == null || last == null) return 'this week';

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[first.month - 1]} ${first.day} - ${months[last.month - 1]} ${last.day}';
  }

  String _formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  String _getInsight(_WeeklyStats stats) {
    final avgSteps = widget.weeklyData.isNotEmpty
        ? stats.totalSteps ~/ widget.weeklyData.length
        : 0;

    if (stats.goalsHit == widget.weeklyData.length) {
      return "Perfect week! You hit every single goal. You're on fire! 🎉";
    }
    if (stats.goalsHit >= 5) {
      return "Amazing consistency! ${stats.goalsHit} goals hit. Keep this momentum going!";
    }
    if (stats.goalsHit >= 3) {
      return "Good effort! You're building a solid habit. Aim for more goals next week!";
    }
    if (avgSteps > 5000) {
      return "You're staying active! Try to hit your daily goal more often for extra XP.";
    }
    return "Every step counts! Let's aim to hit more goals next week. You've got this! 💪";
  }

  /// Compute deep insights from full history
  _DeepInsights _computeDeepInsights() {
    final history = widget.allTimeHistory;
    final goal = widget.dailyGoal;
    final now = DateTime.now();

    // --- Week-over-week trend ---
    final thisWeekTotal = widget.weeklyData.fold<int>(
      0,
      (sum, d) => sum + ((d['steps'] as int?) ?? 0),
    );

    // Get last week's data
    int lastWeekTotal = 0;
    final lastWeekStart = now.subtract(Duration(days: now.weekday + 6));
    for (int i = 0; i < 7; i++) {
      final date = lastWeekStart.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      lastWeekTotal += history[dateStr] ?? 0;
    }

    double weekOverWeekChange = 0;
    if (lastWeekTotal > 0) {
      weekOverWeekChange =
          ((thisWeekTotal - lastWeekTotal) / lastWeekTotal) * 100;
    }

    // --- Best weekday pattern (last 4 weeks) ---
    final weekdayTotals = List<int>.filled(7, 0);
    final weekdayCounts = List<int>.filled(7, 0);
    final fourWeeksAgo = now.subtract(const Duration(days: 28));

    for (final entry in history.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date != null && date.isAfter(fourWeeksAgo)) {
        weekdayTotals[date.weekday - 1] += entry.value;
        weekdayCounts[date.weekday - 1]++;
      }
    }

    int bestWeekdayIndex = 0;
    double bestWeekdayAvg = 0;
    final weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    for (int i = 0; i < 7; i++) {
      final avg = weekdayCounts[i] > 0
          ? weekdayTotals[i] / weekdayCounts[i]
          : 0.0;
      if (avg > bestWeekdayAvg) {
        bestWeekdayAvg = avg;
        bestWeekdayIndex = i;
      }
    }

    // --- Consistency (last 28 days) ---
    int daysWithGoal = 0;
    int totalDaysTracked = 0;
    for (int i = 0; i < 28; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final steps = history[dateStr];
      if (steps != null && steps > 0) {
        totalDaysTracked++;
        if (steps >= goal) daysWithGoal++;
      }
    }
    final consistencyPct = totalDaysTracked > 0
        ? (daysWithGoal / totalDaysTracked * 100).round()
        : 0;

    // --- PR detection this week ---
    int allTimeMax = 0;
    for (final steps in history.values) {
      if (steps > allTimeMax) allTimeMax = steps;
    }
    String? prDay;
    for (final day in widget.weeklyData) {
      final steps = day['steps'] as int? ?? 0;
      if (steps >= allTimeMax && steps > 0) {
        final dateStr = day['date'] as String?;
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            prDay = weekdayNames[date.weekday - 1];
          }
        }
        break;
      }
    }

    // --- Weekday vs Weekend average ---
    int weekdaySteps = 0, weekdayDays = 0;
    int weekendSteps = 0, weekendDays = 0;
    for (final entry in history.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date != null && date.isAfter(fourWeeksAgo) && entry.value > 0) {
        if (date.weekday >= 6) {
          weekendSteps += entry.value;
          weekendDays++;
        } else {
          weekdaySteps += entry.value;
          weekdayDays++;
        }
      }
    }
    final weekdayAvg = weekdayDays > 0 ? weekdaySteps ~/ weekdayDays : 0;
    final weekendAvg = weekendDays > 0 ? weekendSteps ~/ weekendDays : 0;

    return _DeepInsights(
      weekOverWeekChange: weekOverWeekChange,
      lastWeekTotal: lastWeekTotal,
      bestWeekday: weekdayNames[bestWeekdayIndex],
      bestWeekdayAvg: bestWeekdayAvg.round(),
      consistencyPct: consistencyPct,
      prDay: prDay,
      weekdayAvg: weekdayAvg,
      weekendAvg: weekendAvg,
    );
  }

  /// Build the deep insights chat bubble
  Widget _buildDeepInsights(ThemeData theme, _DeepInsights insights) {
    final insightRows = <Widget>[];

    // Week-over-week trend
    if (insights.lastWeekTotal > 0) {
      final isUp = insights.weekOverWeekChange >= 0;
      final changeStr =
          '${insights.weekOverWeekChange.abs().toStringAsFixed(0)}%';
      insightRows.add(
        _buildInsightRow(
          theme,
          emoji: isUp ? '📈' : '📉',
          text: isUp
              ? 'You walked $changeStr more than last week — keep it up!'
              : 'You walked $changeStr less than last week. Let\'s bounce back!',
        ),
      );
    }

    // PR this week
    if (insights.prDay != null) {
      insightRows.add(
        _buildInsightRow(
          theme,
          emoji: '🏆',
          text:
              'New personal best this ${insights.prDay}! You\'re unstoppable!',
        ),
      );
    }

    // Consistency
    insightRows.add(
      _buildInsightRow(
        theme,
        emoji: insights.consistencyPct >= 70 ? '🎯' : '📊',
        text:
            'Monthly consistency: ${insights.consistencyPct}% of days you hit your goal.',
      ),
    );

    // Best weekday
    insightRows.add(
      _buildInsightRow(
        theme,
        emoji: '⭐',
        text:
            'Your strongest day is ${insights.bestWeekday} (avg ${_formatNumber(insights.bestWeekdayAvg)} steps).',
      ),
    );

    // Weekday vs Weekend
    if (insights.weekdayAvg > 0 && insights.weekendAvg > 0) {
      final moreActive = insights.weekdayAvg > insights.weekendAvg
          ? 'weekdays'
          : 'weekends';
      insightRows.add(
        _buildInsightRow(
          theme,
          emoji: '🔄',
          text:
              'You\'re more active on $moreActive (${_formatNumber(insights.weekdayAvg)} vs ${_formatNumber(insights.weekendAvg)} avg).',
        ),
      );
    }

    return _buildChatBubble(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: const Color(0xFFFFD700),
              ),
              const SizedBox(width: 6),
              Text(
                'Deep Insights',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryC(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...insightRows,
        ],
      ),
    );
  }

  Widget _buildInsightRow(
    ThemeData theme, {
    required String emoji,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimaryC(context),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyStats {
  final int totalSteps;
  final int goalsHit;
  final int totalCalories;
  final int maxSteps;
  final int bestDayIndex;
  final String bestDayName;

  _WeeklyStats({
    required this.totalSteps,
    required this.goalsHit,
    required this.totalCalories,
    required this.maxSteps,
    required this.bestDayIndex,
    required this.bestDayName,
  });
}

class _DeepInsights {
  final double weekOverWeekChange;
  final int lastWeekTotal;
  final String bestWeekday;
  final int bestWeekdayAvg;
  final int consistencyPct;
  final String? prDay;
  final int weekdayAvg;
  final int weekendAvg;

  _DeepInsights({
    required this.weekOverWeekChange,
    required this.lastWeekTotal,
    required this.bestWeekday,
    required this.bestWeekdayAvg,
    required this.consistencyPct,
    required this.prDay,
    required this.weekdayAvg,
    required this.weekendAvg,
  });
}
