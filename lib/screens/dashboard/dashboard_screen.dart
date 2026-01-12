import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/step_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/progress_ring.dart';
import 'widgets/step_counter_display.dart';
import 'widgets/stat_card.dart';

/// Main dashboard screen showing step count and stats
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stepState = ref.watch(stepProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.mintBackground,
      body: SafeArea(
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

                      // Header Row
                      _buildHeader(context),

                      const SizedBox(height: 24),

                      // Main Card with Progress Ring
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

                            // Goal indicator pill - tappable to change goal
                            GestureDetector(
                              onTap: () => _showGoalChangeDialog(
                                context,
                                ref,
                                settings.dailyGoal,
                              ),
                              child: Container(
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
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white70,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Stats Cards Row
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

                      const SizedBox(height: 12),

                      // Second row stats
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

                      const SizedBox(height: 100), // Space for bottom nav
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  /// Build header row
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button placeholder
        Container(
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

        // Title
        Text('StepPulse', style: Theme.of(context).textTheme.titleLarge),

        // Settings button
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/settings'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.settings_outlined,
              size: 20,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// Build bottom navigation bar
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            context,
            icon: Icons.home_rounded,
            label: 'Home',
            isSelected: true,
            onTap: () {},
          ),
          _buildNavItem(
            context,
            icon: Icons.bar_chart_rounded,
            label: 'Stats',
            isSelected: false,
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          _buildNavItem(
            context,
            icon: Icons.show_chart_rounded,
            label: 'Progress',
            isSelected: false,
            onTap: () => Navigator.pushNamed(context, '/progress'),
          ),
          _buildNavItem(
            context,
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            isSelected: false,
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.6),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
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

  /// Show dialog to change daily step goal
  void _showGoalChangeDialog(
    BuildContext context,
    WidgetRef ref,
    int currentGoal,
  ) {
    final goals = [5000, 8000, 10000, 12000, 15000];
    int selectedGoal = currentGoal;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Change Daily Goal',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select how many steps you want to achieve each day',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Goal options
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: goals.map((goal) {
                      final isSelected = selectedGoal == goal;
                      return GestureDetector(
                        onTap: () => setState(() => selectedGoal = goal),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accentBlack
                                : AppTheme.mintBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accentBlack
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            _formatNumber(goal),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(settingsProvider.notifier)
                            .setDailyGoal(selectedGoal);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlack,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Goal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
