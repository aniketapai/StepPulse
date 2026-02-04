import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class WeeklyReportDialog extends StatefulWidget {
  final List<Map<String, dynamic>> weeklyData;
  final VoidCallback onDismiss;

  const WeeklyReportDialog({
    super.key,
    required this.weeklyData,
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
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
                      child: _buildBotContent(theme, stats),
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
                        backgroundColor: AppTheme.accentBlack,
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
            AppTheme.accentBlack,
            AppTheme.accentBlack.withValues(alpha: 0.85),
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
                  color: AppTheme.mintBackground.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: AppTheme.accentBlack,
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
        color: Colors.white,
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
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
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

  Widget _buildBotContent(ThemeData theme, _WeeklyStats stats) {
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
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Here's your weekly report for $dateRange:",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
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
                                    : Colors.grey.shade300,
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
                                    : AppTheme.textSecondary,
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
                    color: AppTheme.accentBlack,
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
                    const Text('🏆', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Best day: ${stats.bestDayName} with ${_formatNumber(stats.maxSteps)} steps!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textPrimary,
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
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getInsight(stats),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
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
