import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';

import '../../providers/step_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/history_provider.dart';

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
  late DateTime _selectedMonth; // For calendar navigation

  // Motivational quotes carousel
  static const List<String> _quotes = [
    '"The journey of a thousand miles begins with a single step." - Lao Tzu',
    '"Walking is man\'s best medicine." - Hippocrates',
    '"An early-morning walk is a blessing for the whole day." - Henry David Thoreau',
    '"All truly great thoughts are conceived while walking." - Friedrich Nietzsche',
    '"Walking is the best possible exercise." - Thomas Jefferson',
    '"Every step is progress, no matter how small."',
    '"Your body can stand almost anything. It\'s your mind you need to convince."',
    '"The only bad workout is the one that didn\'t happen."',
    '"Believe you can and you\'re halfway there." - Theodore Roosevelt',
    '"One step at a time is all it takes to get you there." - Emily Dickinson',
  ];

  late PageController _quoteController;
  Timer? _autoScrollTimer;
  int _currentQuoteIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now(); // Start with current month
    _quoteController = PageController();
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
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_quoteController.hasClients) {
        _currentQuoteIndex = (_currentQuoteIndex + 1) % _quotes.length;
        _quoteController.animateToPage(
          _currentQuoteIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _quoteController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedChild(int index, Widget child) {
    return FadeTransition(opacity: _fadeAnimations[index], child: child);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final storage = ref.watch(storageServiceProvider);
    final stepState = ref.watch(stepProvider);
    final theme = Theme.of(context);

    // Get history map for heatmap and include today's live steps
    final historyMap = Map<String, int>.from(storage.getHistoryMap(days: 365));
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    historyMap[todayStr] = stepState.todaySteps;

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

            // Motivational Quotes Carousel
            _buildQuotesCarousel(theme),

            const SizedBox(height: 16),

            // Activity Calendar
            Text(
              'Activity',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Interactive Calendar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  // Month navigation header
                  _buildCalendarHeader(context),
                  const SizedBox(height: 16),
                  // Day of week labels
                  _buildDayLabels(context),
                  const SizedBox(height: 8),
                  // Calendar grid
                  _buildCalendarGrid(context, historyMap, settings.dailyGoal),
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

            // Steps History section
            _buildStepsHistorySection(context, ref, settings.dailyGoal),

            const SizedBox(height: 120), // Space for nav bar
          ],
        ),
      ),
    );
  }

  /// Build calendar header with month navigation
  Widget _buildCalendarHeader(BuildContext context) {
    final theme = Theme.of(context);
    final monthYear = DateFormat('MMMM yyyy').format(_selectedMonth);
    final now = DateTime.now();
    final canGoNext =
        _selectedMonth.year < now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
              );
            });
          },
          icon: const Icon(Icons.chevron_left_rounded),
          color: AppTheme.accentBlack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Text(
          monthYear,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        IconButton(
          onPressed: canGoNext
              ? () {
                  setState(() {
                    _selectedMonth = DateTime(
                      _selectedMonth.year,
                      _selectedMonth.month + 1,
                    );
                  });
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: canGoNext ? AppTheme.accentBlack : Colors.grey.shade300,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  /// Build day of week labels
  Widget _buildDayLabels(BuildContext context) {
    final theme = Theme.of(context);
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days
          .map(
            (d) => SizedBox(
              width: 36,
              child: Center(
                child: Text(
                  d,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  /// Build calendar grid for the selected month
  Widget _buildCalendarGrid(
    BuildContext context,
    Map<String, int> historyMap,
    int goal,
  ) {
    final now = DateTime.now();
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday % 7; // 0 = Sunday

    // Build calendar rows
    final rows = <Widget>[];
    var currentDay = 1 - firstWeekday;

    while (currentDay <= daysInMonth) {
      final week = <Widget>[];
      for (var i = 0; i < 7; i++) {
        if (currentDay < 1 || currentDay > daysInMonth) {
          // Empty cell
          week.add(const SizedBox(width: 36, height: 36));
        } else {
          final date = DateTime(
            _selectedMonth.year,
            _selectedMonth.month,
            currentDay,
          );
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final steps = historyMap[dateStr] ?? 0;
          final intensity = _getIntensity(steps, goal);
          final isToday =
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
          final isFuture = date.isAfter(now);

          week.add(
            GestureDetector(
              onTap: isFuture
                  ? null
                  : () => _showActivityDialog(
                      context,
                      date: DateFormat('EEEE, MMMM d, yyyy').format(date),
                      steps: steps,
                      goal: goal,
                      isToday: isToday,
                    ),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isFuture
                      ? Colors.grey.shade100
                      : _getColorForIntensity(intensity),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday
                      ? Border.all(color: AppTheme.accentBlack, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$currentDay',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isFuture
                          ? Colors.grey.shade400
                          : intensity >= 3
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        currentDay++;
      }
      rows.add(
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: week),
      );
    }

    return Column(children: rows);
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
    // Classic theme colors
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
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _getColorForIntensity(i),
              borderRadius: BorderRadius.circular(3),
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

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildStepsHistorySection(
    BuildContext context,
    WidgetRef ref,
    int goal,
  ) {
    final theme = Theme.of(context);
    final history = ref.watch(historyProvider);
    final stepState = ref.watch(stepProvider);
    final todaySteps = stepState.todaySteps;
    final now = DateTime.now();
    final todayDateStr = DateFormat('yyyy-MM-dd').format(now);

    // Combine today with history (limit to 7 items)
    final allData = <dynamic>[
      if (todaySteps > 0) {'date': todayDateStr, 'steps': todaySteps},
      ...history.where((item) => item.date != todayDateStr).take(6),
    ];

    if (allData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Steps History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...allData.map((item) {
          final steps = item is Map ? item['steps'] as int : item.steps as int;
          final dateStr = item is Map
              ? item['date'] as String
              : item.date as String;
          return _buildHistoryItem(context, dateStr, steps, goal);
        }),
      ],
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    String dateStr,
    int steps,
    int goal,
  ) {
    final theme = Theme.of(context);
    final date = DateTime.parse(dateStr);
    final isGoalMet = steps >= goal;
    final stepsLeft = (goal - steps).clamp(0, goal);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);

    String dateLabel;
    if (itemDate == today) {
      dateLabel = 'Today';
    } else if (itemDate == today.subtract(const Duration(days: 1))) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('MMM d').format(date);
    }

    return GestureDetector(
      onTap: () => _showActivityDialog(
        context,
        date: DateFormat('EEEE, MMMM d, yyyy').format(date),
        steps: steps,
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
                    isGoalMet
                        ? '${_formatNumber(steps)} steps • Goal met! 🎉'
                        : '${_formatNumber(steps)} steps • ${_formatNumber(stepsLeft)} left',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isGoalMet
                          ? Colors.green.shade600
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildQuotesCarousel(ThemeData theme) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentBlack.withValues(alpha: 0.9),
            AppTheme.accentBlack,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentBlack.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Quotes PageView
          PageView.builder(
            controller: _quoteController,
            onPageChanged: (index) {
              setState(() => _currentQuoteIndex = index);
            },
            itemCount: _quotes.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Center(
                  child: Text(
                    _quotes[index],
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          ),
          // Page Indicators
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _quotes.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: _currentQuoteIndex == index ? 12 : 6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: _currentQuoteIndex == index ? 0.9 : 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
