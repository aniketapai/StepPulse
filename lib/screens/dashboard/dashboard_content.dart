import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/step_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/step_xp_bridge_provider.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/progress_ring.dart';
import 'widgets/step_counter_display.dart';
import 'widgets/stat_card.dart';
import '../fitness_chat_screen.dart';

/// Dashboard content (for use in nav shell - no bottom nav)
class DashboardContent extends ConsumerStatefulWidget {
  const DashboardContent({super.key});

  @override
  ConsumerState<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<DashboardContent>
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

    _fadeAnimations = List.generate(4, (index) {
      final start = index * 0.15;
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
    final stepState = ref.watch(stepProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    ref.watch(stepXpBridgeProvider);

    // Classic theme colors
    const accentColor = AppTheme.accentBlack;
    const ringBgColor = AppTheme.mintBackground;

    // Get screen dimensions for responsive sizing
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive values
    final horizontalPadding = screenWidth * 0.05; // 5% of screen width
    final topSpacing = screenHeight * 0.02; // 2% of screen height
    final cardSpacing = screenHeight * 0.025; // 2.5% of screen height
    final cardPadding = screenWidth * 0.06; // 6% of screen width

    // Responsive ring size - scales with screen size but constrained
    final ringSize = (screenWidth * 0.5).clamp(180.0, 240.0);
    final ringStrokeWidth = (ringSize * 0.05).clamp(10.0, 14.0);

    // Responsive spacing inside main card
    final cardInnerSpacing = (screenHeight * 0.03).clamp(20.0, 32.0);

    return SafeArea(
      child: stepState.isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    SizedBox(height: topSpacing),

                    // Header Row - same layout
                    _buildAnimatedChild(0, _buildHeader(context)),

                    SizedBox(height: cardSpacing),

                    // Main Card with Progress Ring
                    _buildAnimatedChild(
                      1,
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _getGreeting(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            SizedBox(height: cardInnerSpacing * 0.75),
                            ProgressRing(
                              progress: stepState.getProgress(
                                settings.dailyGoal,
                              ),
                              size: ringSize,
                              strokeWidth: ringStrokeWidth,
                              backgroundColor: ringBgColor,
                              progressColor: accentColor,
                              child: StepCounterDisplay(
                                steps: stepState.todaySteps,
                                goal: settings.dailyGoal,
                              ),
                            ),
                            SizedBox(height: cardInnerSpacing),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.flag_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Goal: ${_formatNumber(settings.dailyGoal)}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: cardSpacing * 0.8),

                    // Stats Cards Row
                    _buildAnimatedChild(
                      2,
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Distance',
                              value: stepState
                                  .getDistance(useMetric: settings.useMetric)
                                  .toStringAsFixed(1),
                              unit: settings.useMetric ? 'km' : 'mi',
                              icon: Icons.directions_walk_rounded,
                              accentColor: accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'Calories',
                              value: stepState.calories.round().toString(),
                              unit: 'kcal',
                              icon: Icons.local_fire_department_rounded,
                              accentColor: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: cardSpacing * 0.5),

                    // Active Time - full width since we removed Remaining
                    _buildAnimatedChild(
                      3,
                      StatCard(
                        title: 'Active Time',
                        value: _estimateActiveTime(stepState.todaySteps),
                        unit: 'min',
                        icon: Icons.timer_outlined,
                        accentColor: accentColor,
                      ),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(width: 48), // Balance for symmetry
        Text(
          'StepPulse',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppTheme.textPrimary),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, _, __) => const FitnessChatScreen(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentBlack,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning! 👋';
    if (hour < 17) return 'Good afternoon! 👋';
    return 'Good evening! 👋';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _estimateActiveTime(int steps) {
    return (steps / 100).round().toString();
  }
}
