import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/xp_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/step_provider.dart';
import '../../models/xp_data.dart';
import '../../services/foreground_service.dart';

/// Enhanced Profile screen content (for use in nav shell)
class ProfileContent extends ConsumerStatefulWidget {
  const ProfileContent({super.key});

  @override
  ConsumerState<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<ProfileContent> {
  final _nameController = TextEditingController();
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      _nameController.text = storage.profileName;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xp = ref.watch(xpProvider);
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    // Parse member since date for display
    final memberSince = storage.memberSince;
    final memberSinceDate = DateTime.tryParse(memberSince) ?? DateTime.now();
    final memberDays = DateTime.now().difference(memberSinceDate).inDays + 1;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Title
            Text(
              'Profile',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 24),

            // Profile Card with Avatar and Name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlack,
                            shape: BoxShape.circle,
                            image: storage.profilePhotoPath != null
                                ? DecorationImage(
                                    image: FileImage(
                                      File(storage.profilePhotoPath!),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: storage.profilePhotoPath == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 50,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlack,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Editable Name
                  _isEditingName
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 150,
                              child: TextField(
                                controller: _nameController,
                                textAlign: TextAlign.center,
                                autofocus: true,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: AppTheme.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onSubmitted: (_) => _saveName(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_rounded),
                              color: AppTheme.accentBlack,
                              onPressed: _saveName,
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: () => setState(() => _isEditingName = true),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                storage.profileName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    'Member for $memberDays days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // XP & Level Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  // Level badge with info icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlack,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Level ${xp.level} • ${xp.levelTitle}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showXpInfoPopup(context),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // XP display
                  Text(
                    '${xp.totalXp}',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Total XP Earned',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Level progress bar
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 10,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              Container(
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: xp.levelProgress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentBlack,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${xp.xpForNextLevel - xp.totalXp} XP to Level ${xp.level + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Streaks Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: AppTheme.accentBlack,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${xp.currentStreak}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Current\nStreak',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: AppTheme.mintBackground,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: AppTheme.accentBlack,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${xp.longestStreak}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Longest\nStreak',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: AppTheme.mintBackground,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: AppTheme.accentBlack,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${xp.totalDaysActive}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Days\nActive',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Danger Zone - Reset Progress
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Danger Zone',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reset all your progress including XP, levels, streaks, and history. Your profile info will be kept.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmResetProgress(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        side: BorderSide(color: Colors.red.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset All Progress'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 120), // Space for nav bar
          ],
        ),
      ),
    );
  }

  void _showXpInfoPopup(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: Colors.amber.shade600,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'XP System',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // XP Earning - horizontal text format
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.mintBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '👣 100 steps = +1 XP   🎯 Goal = +50 XP   🔥 Streak = +10 XP/day',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // Level Ranks title
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Levels',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Compact level grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(kLevelTitles.length, (index) {
                final xpRequired = index < kLevelThresholds.length
                    ? kLevelThresholds[index]
                    : 18000;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}. ${kLevelTitles[index]} · ${_formatNumber(xpRequired)} XP',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}k';
    }
    return number.toString();
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );

    if (image != null) {
      final storage = ref.read(storageServiceProvider);
      await storage.setProfilePhotoPath(image.path);
      setState(() {});
    }
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final storage = ref.read(storageServiceProvider);
      storage.setProfileName(name);
    }
    setState(() => _isEditingName = false);
  }

  Future<void> _confirmResetProgress(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Everything?'),
        content: const Text(
          'This will permanently delete:\n'
          '• All XP and levels\n'
          '• All streaks\n'
          '• All step history\n'
          '• Your profile info\n'
          '• All settings\n'
          '• Stop background tracking\n\n'
          'Note: App permissions cannot be revoked by the app.\n'
          'You\'ll be taken back to onboarding.\n\n'
          'This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      final storage = ref.read(storageServiceProvider);

      // Stop background service
      await ForegroundStepService().stop();

      // Clear ALL data from storage
      await storage.clearAllData();

      // Reset all provider states to clear in-memory cache
      ref.read(xpProvider.notifier).reset();
      ref.read(historyProvider.notifier).clearHistory();
      ref.read(stepProvider.notifier).resetToday();
      ref.read(settingsProvider.notifier).resetSettings();

      if (!context.mounted) return;

      // Navigate to onboarding and clear navigation stack
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/onboarding', (route) => false);
    }
  }
}
