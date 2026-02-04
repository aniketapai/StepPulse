import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sync_manager.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/update_service.dart';

/// Settings screen for app configuration
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late double _goalValue;
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _goalValue = ref.read(settingsProvider).dailyGoal.toDouble();
    _loadAppVersion();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    // final storage = ref.watch(storageServiceProvider); // Unused
    final theme = Theme.of(context);

    // Classic theme colors
    const accentColor = AppTheme.accentBlack;
    const backgroundColor = AppTheme.mintBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
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
              child: ListView(
                // Use ClampingScrollPhysics for smoother, more controlled scrolling
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                // Higher cacheExtent preloads more items for smoother scrolling
                cacheExtent: 1500,
                addAutomaticKeepAlives: true,
                children: [
                  // Goal section
                  RepaintBoundary(
                    child: _buildSection(
                      context,
                      title: 'Daily Step Goal',
                      icon: Icons.flag_rounded,
                      child: Column(
                        children: [
                          // Goal display
                          Text(
                            _formatNumber(_goalValue.round()),
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'steps per day',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Goal slider
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 10,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 14,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 28,
                              ),
                              activeTrackColor: accentColor,
                              inactiveTrackColor: Colors.grey.shade200,
                              thumbColor: accentColor,
                              overlayColor: accentColor.withValues(alpha: 0.2),
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
                                // Sync to cloud (debounced)
                                ref
                                    .read(syncManagerProvider)
                                    .onSettingsChanged();
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
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${kMaxGoal ~/ 1000}K',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Units section
                  RepaintBoundary(
                    child: _buildSection(
                      context,
                      title: 'Units',
                      icon: Icons.straighten_rounded,
                      child: _buildSettingRow(
                        context,
                        title: 'Use Metric System',
                        subtitle: settings.useMetric
                            ? 'Kilometers, cm, kg'
                            : 'Miles, inches, lbs',
                        trailing: Switch(
                          value: settings.useMetric,
                          onChanged: (value) async {
                            await ref
                                .read(settingsProvider.notifier)
                                .setUseMetric(value);
                            // Sync to cloud (debounced)
                            ref.read(syncManagerProvider).onSettingsChanged();
                          },
                          activeThumbColor: accentColor,
                          activeTrackColor: accentColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // App Updates section
                  RepaintBoundary(
                    child: _buildSection(
                      context,
                      title: 'App Updates',
                      icon: Icons.system_update_rounded,
                      child: Column(
                        children: [
                          _buildSettingRow(
                            context,
                            title: 'Current Version',
                            subtitle: 'v$_appVersion',
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  UpdateService.checkForUpdateManually(context),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Check for Updates'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentBlack,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Account section
                  RepaintBoundary(
                    child: _buildSection(
                      context,
                      title: 'Account',
                      icon: Icons.account_circle_rounded,
                      child: GestureDetector(
                        onTap: () => _handleSignOut(),
                        child: _buildSettingRow(
                          context,
                          title: 'Sign Out',
                          subtitle: 'Sign out of your account',
                          trailing: const Icon(
                            Icons.logout_rounded,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Export Data section
                  RepaintBoundary(
                    child: _buildSection(
                      context,
                      title: 'Export Data',
                      icon: Icons.download_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export your step history as a CSV file',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showExportDialog(),
                              icon: const Icon(Icons.file_download_rounded),
                              label: const Text('Export Step History'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentBlack,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // FAQ section
                  RepaintBoundary(
                    child: _buildSection(
                      context,
                      title: 'FAQ',
                      icon: Icons.help_outline_rounded,
                      child: Column(
                        children: [
                          _buildExpandableFaq(
                            'How accurate is step counting?',
                            'StepPulse uses your device\'s built-in step counter sensor (pedometer), which is typically 95-99% accurate for normal walking. Accuracy may vary based on phone placement and walking style.',
                          ),
                          const Divider(height: 16),
                          _buildExpandableFaq(
                            'How is XP calculated?',
                            'You earn 1 XP for every 100 steps walked. Additionally, you get +50 XP bonus when you hit your daily goal, and +10 XP per day for maintaining a streak.',
                          ),
                          const Divider(height: 16),
                          _buildExpandableFaq(
                            'Why did my steps reset?',
                            'Steps reset automatically at midnight each day. Your previous day\'s steps are saved to your history. If you reboot your phone, the step counter resets but StepPulse preserves your daily progress.',
                          ),
                          const Divider(height: 16),
                          _buildExpandableFaq(
                            'Does the app work in background?',
                            'Yes! StepPulse runs a foreground service to count your steps even when the app is closed. You\'ll see a notification showing your current step count.',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // About section
                  RepaintBoundary(
                    child: _buildSection(
                      context,
                      title: 'About',
                      icon: Icons.info_outline_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSettingRow(
                            context,
                            title: 'StepPulse',
                            subtitle: 'Version $_appVersion',
                          ),
                          const Divider(height: 24),
                          Text(
                            'Track your steps, earn XP, and achieve your fitness goals with StepPulse. A gamified step counter that makes walking fun!',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Developer section
                  RepaintBoundary(
                    child: _buildSection(
                      context,
                      title: 'Developer',
                      icon: Icons.code_rounded,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlack,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Aniket Pai',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      'Mobile App Developer',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTheme.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () =>
                                _launchUrl('https://github.com/aniketapai'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.mintBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.link_rounded,
                                    size: 20,
                                    color: AppTheme.accentBlack,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'github.com/aniketapai',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.accentBlack,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.open_in_new_rounded,
                                    size: 18,
                                    color: AppTheme.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildExpandableFaq(String question, String answer) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          question,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary),
        ),
        iconColor: AppTheme.textSecondary,
        collapsedIconColor: AppTheme.textSecondary,
        children: [
          Text(
            answer,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sign Out?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will need to sign in again to access your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (shouldSignOut == true && mounted) {
      // 1. Sign out from Firebase/Google
      final auth = ref.read(authServiceProvider);
      await auth.signOut();

      // 2. Update local storage state
      final storage = ref.read(storageServiceProvider);
      // We set onboarding to false so the app routes to OnboardingScreen on restart
      await storage.setOnboardingComplete(false);

      // 3. Navigate to Onboarding
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/sign-in', (route) => false);
      }
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _showExportDialog() {
    String selectedRange = '1 Month';
    final ranges = ['1 Week', '1 Month', '6 Months', '1 Year', 'All Time'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Export Step History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select time range to export',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ranges.map((range) {
                  final isSelected = range == selectedRange;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedRange = range),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentBlack
                            : AppTheme.mintBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        range,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _exportData(selectedRange);
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Export & Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlack,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _exportData(String range) {
    final storage = ref.read(storageServiceProvider);
    final settings = ref.read(settingsProvider);
    final goal = settings.dailyGoal;

    // Determine days based on range
    int days;
    switch (range) {
      case '1 Week':
        days = 7;
        break;
      case '1 Month':
        days = 30;
        break;
      case '6 Months':
        days = 180;
        break;
      case '1 Year':
        days = 365;
        break;
      default:
        days = 3650; // 10 years = effectively all time
    }

    // Get history as map
    final historyMap = storage.getHistoryMap(days: days);

    if (historyMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export for this period')),
      );
      return;
    }

    // Build CSV content
    final buffer = StringBuffer();
    buffer.writeln('Date,Steps,Goal,Goal Met');

    // Sort dates in descending order (newest first)
    final sortedDates = historyMap.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    for (final dateStr in sortedDates) {
      final steps = historyMap[dateStr] ?? 0;
      final goalMet = steps >= goal ? 'Yes' : 'No';
      buffer.writeln('$dateStr,$steps,$goal,$goalMet');
    }

    final csvContent = buffer.toString();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final filename = 'steppulse_export_$dateStr.csv';

    // Share as text with CSV content
    Share.share(csvContent, subject: filename);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${sortedDates.length} days of data'),
        backgroundColor: AppTheme.accentBlack,
      ),
    );
  }
}
