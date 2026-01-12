import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/step_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Settings screen for app configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late double _goalValue;

  @override
  void initState() {
    super.initState();
    _goalValue = ref.read(settingsProvider).dailyGoal.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

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
                    'Settings',
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Goal section
                    _buildSection(
                      context,
                      title: 'Daily Step Goal',
                      icon: Icons.flag_rounded,
                      child: Column(
                        children: [
                          // Goal display
                          Text(
                            '${_goalValue.round()}',
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'steps per day',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          // Goal slider
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 8,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 24,
                              ),
                            ),
                            child: Slider(
                              value: _goalValue,
                              min: kMinGoal.toDouble(),
                              max: kMaxGoal.toDouble(),
                              divisions: (kMaxGoal - kMinGoal) ~/ 500,
                              onChanged: (value) {
                                setState(() {
                                  _goalValue = value;
                                });
                              },
                              onChangeEnd: (value) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .setDailyGoal(value.round());
                              },
                            ),
                          ),
                          // Min/Max labels
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${kMinGoal ~/ 1000}K',
                                  style: theme.textTheme.labelSmall,
                                ),
                                Text(
                                  '${kMaxGoal ~/ 1000}K',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Units section
                    _buildSection(
                      context,
                      title: 'Units',
                      icon: Icons.straighten_rounded,
                      child: _buildSettingRow(
                        context,
                        title: 'Use Metric System',
                        subtitle: settings.useMetric ? 'Kilometers' : 'Miles',
                        trailing: Switch(
                          value: settings.useMetric,
                          onChanged: (value) {
                            ref
                                .read(settingsProvider.notifier)
                                .setUseMetric(value);
                          },
                          activeThumbColor: AppTheme.accentBlack,
                          activeTrackColor: AppTheme.accentBlack,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Data section
                    _buildSection(
                      context,
                      title: 'Data',
                      icon: Icons.storage_rounded,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showResetTodayDialog(context),
                            child: _buildSettingRow(
                              context,
                              title: 'Reset Today\'s Steps',
                              subtitle: 'Start counting from 0 today',
                              trailing: const Icon(
                                Icons.refresh_rounded,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          GestureDetector(
                            onTap: () => _showClearHistoryDialog(context),
                            child: _buildSettingRow(
                              context,
                              title: 'Clear History',
                              subtitle: 'Delete all step history data',
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // About section
                    _buildSection(
                      context,
                      title: 'About',
                      icon: Icons.info_outline_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSettingRow(
                            context,
                            title: 'StepPulse',
                            subtitle: 'Version 1.0.0',
                          ),
                          const Divider(height: 24),
                          Text(
                            'StepPulse uses your device\'s built-in step counter sensor to accurately track your daily steps.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

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

  /// Build a settings section
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.mintBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.textPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  /// Show dialog to confirm clearing history
  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Clear History?'),
        content: const Text(
          'This will permanently delete all your step history data. This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(historyProvider.notifier).clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('History cleared'),
                  backgroundColor: AppTheme.accentBlack,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Show dialog to confirm resetting today's steps
  void _showResetTodayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Reset Today\'s Steps?'),
        content: const Text(
          'This will reset your step count to 0 for today. The current sensor value will become your new baseline.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(stepProvider.notifier).resetToday();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Today\'s steps reset to 0'),
                  backgroundColor: AppTheme.accentBlack,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
