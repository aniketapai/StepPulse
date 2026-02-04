import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/xp_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_manager.dart';
import '../../providers/step_provider.dart';
import 'package:intl/intl.dart';
import '../../models/xp_data.dart';
import 'weekly_report_dialog.dart';
import 'leaderboard_sheet.dart';
import '../../providers/leaderboard_provider.dart';

/// Enhanced Profile screen content (for use in nav shell)
class ProfileContent extends ConsumerStatefulWidget {
  const ProfileContent({super.key});

  @override
  ConsumerState<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<ProfileContent>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _badgesExpanded = false;

  // Animation controllers
  late AnimationController _animController;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      _nameController.text = storage.profileName;
    });

    // Set up staggered animations for 5 elements
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

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
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedChild(int index, Widget child) {
    return FadeTransition(opacity: _fadeAnimations[index], child: child);
  }

  @override
  Widget build(BuildContext context) {
    final xp = ref.watch(xpProvider);
    final storage = ref.watch(storageServiceProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    // Classic theme colors
    const accentColor = AppTheme.accentBlack;
    const accentBgColor = AppTheme.mintBackground;
    final isGoogleUser = ref.read(authServiceProvider).isGoogleUser;

    // Parse member since date for display
    final memberSince = storage.memberSince;
    final memberSinceDate = DateTime.tryParse(memberSince) ?? DateTime.now();
    final memberDays = DateTime.now().difference(memberSinceDate).inDays + 1;

    return SafeArea(
      child: SingleChildScrollView(
        // ClampingScrollPhysics for smoother, more controlled scrolling
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Title with Settings icon - animated
            _buildAnimatedChild(
              0,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bot Button
                  GestureDetector(
                    onTap: _showWeeklyReport,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.smart_toy_rounded,
                            size: 24,
                            color: AppTheme.accentBlack,
                          ),
                          // Notification dot (Always visible & glowing)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.6,
                                    ),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Profile',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
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
                        Icons.settings_rounded,
                        size: 20,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Profile Card with Avatar and Name - animated
            _buildAnimatedChild(
              1,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: isGoogleUser ? null : _pickProfilePhoto,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: accentColor,
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
                          if (!isGoogleUser)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlack,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
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
                            onTap: isGoogleUser
                                ? null
                                : () => setState(() => _isEditingName = true),
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
                                if (!isGoogleUser) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                ],
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

                    // Achievement Badges Section
                    const SizedBox(height: 16),
                    _buildBadgesSection(context, theme, xp, storage),
                  ],
                ),
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
                                    color: accentColor,
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
                  const SizedBox(height: 16),

                  // Leaderboard rank row
                  _buildLeaderboardRow(context, theme),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Progressive disclosure: lock streak features until first activity
            if (xp.totalDaysActive == 0) ...[
              // Locked state - no activity yet
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Complete your first day to unlock streaks 🔥',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start walking to track your progress and earn streak rewards!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Streaks Card - only show when user has activity
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

              const SizedBox(height: 16),

              // Streak Calendar - Row of fire icons for recent days
              _buildStreakCalendar(context, storage, theme, settings.dailyGoal),

              const SizedBox(height: 16),

              // Streak Freeze Card
              _buildStreakFreezeCard(context, xp, accentColor, theme),

              const SizedBox(height: 16),

              // Rest Day Toggle Card
              _buildRestDayCard(context, theme),
            ],

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

  /// Build the leaderboard rank row with View All button
  Widget _buildLeaderboardRow(BuildContext context, ThemeData theme) {
    final leaderboard = ref.watch(leaderboardProvider);

    // Auto-fetch leaderboard if not loaded yet
    if (leaderboard.entries.isEmpty && !leaderboard.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(leaderboardProvider.notifier).fetchLeaderboard();
      });
    }

    return GestureDetector(
      onTap: () => showLeaderboardSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.mintBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Trophy icon
            Icon(
              Icons.emoji_events_rounded,
              color: Colors.amber.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),

            // Rank text
            if (leaderboard.isLoading && leaderboard.userRank == null)
              Text(
                'Loading rank...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              )
            else if (leaderboard.userRank != null)
              Text(
                '#${leaderboard.userRank} of ${leaderboard.totalUsers} walkers',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              )
            else
              Text(
                'View Leaderboard',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),

            const Spacer(),

            // View All button
            Text(
              'View All',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.accentBlack,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.accentBlack,
              size: 18,
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

      // Sync change to cloud (debounced)
      ref.read(syncManagerProvider).onSettingsChanged();

      setState(() {});
    }
  }

  // Badge definitions
  static const List<Map<String, dynamic>> _badgeDefinitions = [
    {
      'id': 'first_flame',
      'icon': Icons.local_fire_department_rounded,
      'name': 'First Flame',
      'desc': 'Complete your first day',
      'colors': [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
    },
    {
      'id': 'goal_getter',
      'icon': Icons.flag_rounded,
      'name': 'Goal Getter',
      'desc': 'Hit daily goal 7 times',
      'colors': [Color(0xFF7B68EE), Color(0xFF9D4EDD)],
    },
    {
      'id': 'marathon',
      'icon': Icons.directions_run_rounded,
      'name': 'Marathon',
      'desc': 'Walk 42,195 total steps',
      'colors': [Color(0xFF00C9A7), Color(0xFF00BFA6)],
    },
    {
      'id': 'week_warrior',
      'icon': Icons.bolt_rounded,
      'name': 'Week Warrior',
      'desc': 'Achieve a 7-day streak',
      'colors': [Color(0xFFFFD93D), Color(0xFFFF9F1C)],
    },
    {
      'id': 'month_master',
      'icon': Icons.emoji_events_rounded,
      'name': 'Month Master',
      'desc': 'Achieve a 30-day streak',
      'colors': [Color(0xFFFF6B6B), Color(0xFFEE5A5A)],
    },
    {
      'id': 'centurion',
      'icon': Icons.military_tech_rounded,
      'name': 'Centurion',
      'desc': '100 total days active',
      'colors': [Color(0xFF4ECDC4), Color(0xFF2EC4B6)],
    },
    {
      'id': 'club_100k',
      'icon': Icons.workspace_premium_rounded,
      'name': '100K Club',
      'desc': 'Walk 100,000 total steps',
      'colors': [Color(0xFF845EC2), Color(0xFFB39CD0)],
    },
    {
      'id': 'half_million',
      'icon': Icons.star_rounded,
      'name': 'Half Million',
      'desc': '500,000 total steps',
      'colors': [Color(0xFFFF6F91), Color(0xFFFF9671)],
    },
    {
      'id': 'millionaire',
      'icon': Icons.diamond_rounded,
      'name': 'Millionaire',
      'desc': '1,000,000 total steps',
      'colors': [Color(0xFFFFC75F), Color(0xFFFFE66D)],
    },
    {
      'id': 'early_bird',
      'icon': Icons.wb_sunny_rounded,
      'name': 'Early Bird',
      'desc': 'Complete goal before noon',
      'colors': [Color(0xFFFFD166), Color(0xFFFCAB10)],
    },
    {
      'id': 'overachiever',
      'icon': Icons.rocket_launch_rounded,
      'name': 'Overachiever',
      'desc': 'Exceed daily goal by 50%',
      'colors': [Color(0xFF06D6A0), Color(0xFF1B9AAA)],
    },
    {
      'id': 'consistent',
      'icon': Icons.repeat_rounded,
      'name': 'Consistent',
      'desc': 'Hit goal 3 days in a row',
      'colors': [Color(0xFF118AB2), Color(0xFF073B4C)],
    },
  ];

  Set<String> _getUnlockedBadges(XpData xp, dynamic storage) {
    final unlocked = <String>{};
    final historyMap = storage.getHistoryMap(days: 365);

    // Calculate total steps from history
    int totalSteps = 0;
    int goalsHit = 0;
    int consecutiveGoalDays = 0;
    int maxConsecutiveGoals = 0;
    final dailyGoal = ref.read(settingsProvider).dailyGoal;

    final sortedDates = historyMap.keys.toList()..sort();
    for (final dateStr in sortedDates) {
      final steps = (historyMap[dateStr] ?? 0) as int;
      totalSteps += steps;

      if (steps >= dailyGoal) {
        goalsHit++;
        consecutiveGoalDays++;
        if (consecutiveGoalDays > maxConsecutiveGoals) {
          maxConsecutiveGoals = consecutiveGoalDays;
        }
      } else {
        consecutiveGoalDays = 0;
      }
    }

    // Check unlock conditions
    if (xp.totalDaysActive >= 1) unlocked.add('first_flame');
    if (goalsHit >= 7) unlocked.add('goal_getter');
    if (totalSteps >= 42195) unlocked.add('marathon');
    if (xp.longestStreak >= 7) unlocked.add('week_warrior');
    if (xp.longestStreak >= 30) unlocked.add('month_master');
    if (xp.totalDaysActive >= 100) unlocked.add('centurion');
    if (totalSteps >= 100000) unlocked.add('club_100k');
    if (totalSteps >= 500000) unlocked.add('half_million');
    if (totalSteps >= 1000000) unlocked.add('millionaire');
    if (maxConsecutiveGoals >= 3) unlocked.add('consistent');

    // Early bird & overachiever - check today's data
    final todaySteps = ref.read(stepProvider).todaySteps;
    final now = DateTime.now();
    if (todaySteps >= dailyGoal && now.hour < 12) unlocked.add('early_bird');
    if (todaySteps >= (dailyGoal * 1.5)) unlocked.add('overachiever');

    return unlocked;
  }

  Widget _buildBadgesSection(
    BuildContext context,
    ThemeData theme,
    XpData xp,
    dynamic storage,
  ) {
    final unlockedBadges = _getUnlockedBadges(xp, storage);
    final unlockedCount = unlockedBadges.length;

    return Column(
      children: [
        // Expandable header
        GestureDetector(
          onTap: () => setState(() => _badgesExpanded = !_badgesExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.mintBackground.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emoji_events_rounded,
                  size: 16,
                  color: AppTheme.accentBlack,
                ),
                const SizedBox(width: 6),
                Text(
                  '$unlockedCount / ${_badgeDefinitions.length} Badges',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.accentBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _badgesExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppTheme.accentBlack,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded badges grid
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _badgesExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _badgeDefinitions.map((badge) {
                final isUnlocked = unlockedBadges.contains(badge['id']);
                return _buildBadgeItem(badge, isUnlocked, theme);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeItem(
    Map<String, dynamic> badge,
    bool isUnlocked,
    ThemeData theme,
  ) {
    final colors = badge['colors'] as List<Color>;

    return GestureDetector(
      onLongPress: () => _showBadgeTooltip(context, badge, isUnlocked),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: isUnlocked
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                )
              : null,
          color: isUnlocked ? null : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: colors[0].withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              badge['icon'] as IconData,
              size: 26,
              color: isUnlocked ? Colors.white : Colors.grey.shade400,
            ),
            if (!isUnlocked)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showBadgeTooltip(
    BuildContext context,
    Map<String, dynamic> badge,
    bool isUnlocked,
  ) {
    final colors = badge['colors'] as List<Color>;

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: isUnlocked
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        )
                      : null,
                  color: isUnlocked ? null : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: colors[0].withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  badge['icon'] as IconData,
                  size: 36,
                  color: isUnlocked ? Colors.white : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                badge['name'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                badge['desc'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                isUnlocked ? '✓ Unlocked!' : '🔒 Keep walking to unlock',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isUnlocked ? Colors.green : Colors.grey,
                ),
              ),
              if (isUnlocked) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _shareBadge(badge);
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors[0],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _shareBadge(Map<String, dynamic> badge) {
    final name = badge['name'] as String;
    final desc = badge['desc'] as String;
    final text =
        '🏆 I just unlocked the "$name" badge in StepPulse!\n\n'
        '$desc\n\n'
        '#StepPulse #WalkingChallenge #FitnessGoals';
    Share.share(text);
  }

  Widget _buildRestDayCard(BuildContext context, ThemeData theme) {
    final storage = ref.watch(storageServiceProvider);
    final isRestDay = storage.isTodayRestDay;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isRestDay
            ? Border.all(color: Colors.purple.shade300, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isRestDay
                  ? Colors.purple.shade50
                  : AppTheme.mintBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.bedtime_rounded,
              color: isRestDay ? Colors.purple.shade600 : AppTheme.accentBlack,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rest Day',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRestDay
                      ? 'Today is a rest day - streak protected'
                      : 'Rest days won\'t break your streak',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isRestDay
                        ? Colors.purple.shade600
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Toggle Switch
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: isRestDay,
              onChanged: (value) async {
                await storage.toggleTodayRestDay();
                setState(() {});
              },
              activeThumbColor: Colors.purple.shade600,
              activeTrackColor: Colors.purple.shade200,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWeeklyReport() async {
    final storage = ref.read(storageServiceProvider);
    final settings = ref.read(settingsProvider);
    final now = DateTime.now();

    // Determine date range
    // If Monday, show last week (Mon-Sun). Else show current week (Mon-Today)
    final isMonday = now.weekday == DateTime.monday;

    // Logic:
    // If today is Monday: Show PREVIOUS week (Mon-Sun)
    // If today is NOT Monday: Show CURRENT week (from Mon up to Today)

    DateTime rangeStart;
    DateTime rangeEnd;

    if (isMonday) {
      // Previous week: Last Monday to Last Sunday
      // If today is Mon, subtract 7 days to get last Mon
      rangeStart = now.subtract(const Duration(days: 7));
      // End is last Sunday (yesterday)
      rangeEnd = now.subtract(const Duration(days: 1));
    } else {
      // Current week: This Monday to Today
      // If today is Tue (weekday 2), subtract 1 day to get Mon
      rangeStart = now.subtract(Duration(days: now.weekday - 1));
      rangeEnd = now;
    }

    // Normalize to date only to match storage keys
    rangeStart = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    rangeEnd = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

    final daysToFetch = rangeEnd.difference(rangeStart).inDays + 1;
    final historyMap = storage.getHistoryMap(days: 30); // Fetch recent history
    final weeklyData = <Map<String, dynamic>>[];

    // Get live steps for today if included in range
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final liveSteps = ref.read(stepProvider).todaySteps;

    for (int i = 0; i < daysToFetch; i++) {
      final date = rangeStart.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      int steps = 0;
      if (dateStr == todayStr) {
        steps = liveSteps; // Use live steps for today
      } else {
        steps = historyMap[dateStr] ?? 0;
      }

      weeklyData.add({
        'steps': steps,
        'goal': settings.dailyGoal,
        'date': dateStr,
      });
    }

    // Mark as viewed if it's Monday (the "Weekly Report" day)
    if (isMonday) {
      await storage.setLastWeeklyReportViewed(
        DateFormat('yyyy-MM-dd').format(now),
      );
      setState(() {}); // Refresh to hide dot
    }

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (context, anim1, anim2) {
        return WeeklyReportDialog(
          weeklyData: weeklyData,
          onDismiss: () => Navigator.pop(context),
        );
      },
    );
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final storage = ref.read(storageServiceProvider);
      storage.setProfileName(name);

      // Sync change to cloud (debounced)
      ref.read(syncManagerProvider).onSettingsChanged();
    }
    setState(() => _isEditingName = false);
  }

  Widget _buildStreakCalendar(
    BuildContext context,
    storage,
    ThemeData theme,
    int dailyGoal,
  ) {
    // Get history map for the last 14 days
    final historyMap = storage.getHistoryMap(days: 14);
    final now = DateTime.now();
    final weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade400,
                      Colors.deepOrange.shade500,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Streak',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Last 14 days',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Calendar grid - 7 days per row
          Column(
            children: [
              // First row: 7 days ago to 1 day ago
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final date = now.subtract(Duration(days: 13 - index));
                  final dateStr =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  final steps = historyMap[dateStr] ?? 0;
                  final isActive = steps >= dailyGoal;

                  return _buildDayCell(date, isActive, false, weekDays, theme);
                }),
              ),
              const SizedBox(height: 12),
              // Second row: last 7 days including today
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final date = now.subtract(Duration(days: 6 - index));
                  final dateStr =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  final steps = historyMap[dateStr] ?? 0;
                  final isActive = steps >= dailyGoal;
                  final isToday = index == 6;

                  return _buildDayCell(
                    date,
                    isActive,
                    isToday,
                    weekDays,
                    theme,
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime date,
    bool isActive,
    bool isToday,
    List<String> weekDays,
    ThemeData theme,
  ) {
    return Column(
      children: [
        // Day letter
        Text(
          weekDays[date.weekday % 7],
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        // Fire icon or empty indicator
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.orange.shade50
                : isToday
                ? AppTheme.mintBackground
                : Colors.grey.shade100,
            border: isToday && !isActive
                ? Border.all(color: AppTheme.accentBlack, width: 2)
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isActive
                ? ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.orange.shade400,
                        Colors.deepOrange.shade600,
                      ],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  )
                : Text(
                    '${date.day}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isToday
                          ? AppTheme.accentBlack
                          : AppTheme.textSecondary,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBmiCard(
    BuildContext context,
    storage,
    Color accentColor,
    Color accentBgColor,
  ) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final heightCm = settings.heightCm;
    final weightKg = settings.weightKg;

    // Calculate BMI using settings state (reactive)
    final bmi = settings.bmi;

    // Get BMI category
    String category;
    Color categoryColor;
    if (bmi < 18.5) {
      category = 'Underweight';
      categoryColor = Colors.blue;
    } else if (bmi < 25) {
      category = 'Normal';
      categoryColor = Colors.green;
    } else if (bmi < 30) {
      category = 'Overweight';
      categoryColor = Colors.orange;
    } else {
      category = 'Obese';
      categoryColor = Colors.red;
    }

    // BMI position on scale (15-40 range mapped to 0-1)
    final bmiPosition = ((bmi - 15) / 25).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/body-stats'),
      child: Container(
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
                    color: accentBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.monitor_weight_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Body Mass Index',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Tap for TDEE & Weight Tracking',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // BMI Value and Category
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  bmi.toStringAsFixed(1),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // BMI Scale
            Stack(
              children: [
                // Background gradient bar
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [
                        Colors.blue,
                        Colors.green,
                        Colors.yellow,
                        Colors.orange,
                        Colors.red,
                      ],
                    ),
                  ),
                ),
                // Position indicator
                Positioned(
                  left:
                      bmiPosition * (MediaQuery.of(context).size.width - 80) -
                      8,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: categoryColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Scale labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '15',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '18.5',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '25',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '30',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '40',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Height/Weight info
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.height_rounded,
                          color: accentColor,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          settings.useMetric
                              ? '$heightCm cm'
                              : '${(heightCm / 2.54).toStringAsFixed(1)} in',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.monitor_weight_outlined,
                          color: accentColor,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          settings.useMetric
                              ? '$weightKg kg'
                              : '${(weightKg * 2.205).toStringAsFixed(1)} lbs',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakFreezeCard(
    BuildContext context,
    XpData xp,
    Color accentColor,
    ThemeData theme,
  ) {
    final isActive = xp.streakFreezeActive;
    final canAfford = xp.canAffordStreakFreeze;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: Colors.blue.shade300, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? Colors.blue.shade50 : AppTheme.mintBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.ac_unit_rounded,
              color: isActive ? Colors.blue.shade600 : accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streak Freeze',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive
                      ? 'Active! Yesterday is protected'
                      : 'Missed yesterday? Protect your streak',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isActive
                        ? Colors.blue.shade600
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Button
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.blue.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: canAfford
                  ? () => _showStreakFreezeConfirmation(context)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: canAfford ? accentColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '$kStreakFreezeCost',
                      style: TextStyle(
                        color: canAfford ? Colors.white : Colors.grey.shade500,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'XP',
                      style: TextStyle(
                        color: canAfford
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.grey.shade500,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showStreakFreezeConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.ac_unit_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Streak Freeze',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Protects your streak, not your steps',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'If you missed your goal yesterday, this prevents your streak from resetting to zero. Your step count stays the same.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cost
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlack,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$kStreakFreezeCost XP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final success = await ref
                            .read(xpProvider.notifier)
                            .activateStreakFreeze();
                        if (mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(
                                    Icons.ac_unit_rounded,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Streak protected! 🎉'),
                                ],
                              ),
                              backgroundColor: Colors.blue.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Activate',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
