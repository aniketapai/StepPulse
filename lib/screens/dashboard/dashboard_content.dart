import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/step_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/step_xp_bridge_provider.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/progress_ring.dart';
import 'widgets/step_counter_display.dart';
import 'widgets/stat_card.dart';

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
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create staggered animations for 4 elements
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

    _slideAnimations = List.generate(4, (index) {
      final start = index * 0.15;
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
    final stepState = ref.watch(stepProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    // Watch the bridge provider to enable live XP updates when steps change
    ref.watch(stepXpBridgeProvider);

    return SafeArea(
      child: stepState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentBlack),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Header Row - animated
                    _buildAnimatedChild(0, _buildHeader(context)),

                    const SizedBox(height: 24),

                    // Main Card with Progress Ring - animated
                    _buildAnimatedChild(
                      1,
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: AppTheme.cardDecoration,
                        child: Column(
                          children: [
                            // Greeting
                            Text(
                              _getGreeting(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Progress Ring with Step Counter
                            ProgressRing(
                              progress: stepState.getProgress(
                                settings.dailyGoal,
                              ),
                              size: 220,
                              strokeWidth: 12,
                              backgroundColor: AppTheme.mintBackground,
                              progressColor: AppTheme.accentBlack,
                              child: StepCounterDisplay(
                                steps: stepState.todaySteps,
                                goal: settings.dailyGoal,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Goal indicator pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accentBlack,
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

                    const SizedBox(height: 20),

                    // Stats Cards Row - animated
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'Calories',
                              value: stepState.calories.round().toString(),
                              unit: 'kcal',
                              icon: Icons.local_fire_department_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Second row stats - animated
                    _buildAnimatedChild(
                      3,
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Active Time',
                              value: _estimateActiveTime(stepState.todaySteps),
                              unit: 'min',
                              icon: Icons.timer_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'Remaining',
                              value: _formatNumber(
                                stepState.getRemainingSteps(settings.dailyGoal),
                              ),
                              unit: 'steps',
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 120), // Space for bottom nav
                  ],
                ),
              ),
            ),
    );
  }

  /// Build header row
  Widget _buildHeader(BuildContext context) {
    return Center(
      child: Text(
        'StepPulse',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: AppTheme.textPrimary),
      ),
    );
  }

  /// Get time-based greeting
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning! 👋';
    } else if (hour < 17) {
      return 'Good afternoon! 👋';
    } else {
      return 'Good evening! 👋';
    }
  }

  /// Format number with commas
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// Estimate active time from steps (roughly 100 steps per minute)
  String _estimateActiveTime(int steps) {
    final minutes = (steps / 100).round();
    return minutes.toString();
  }
}
