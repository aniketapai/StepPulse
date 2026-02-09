import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../providers/settings_provider.dart';
import '../../models/xp_data.dart';

/// Screen to view another user's profile from the leaderboard
class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String displayName;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.displayName,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;
  bool _badgesExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storage = ref.read(storageServiceProvider);
      final firestoreService = FirestoreService(storage);
      final data = await firestoreService.getUserData(widget.userId);

      if (mounted) {
        setState(() {
          _userData = data;
          _isLoading = false;
          if (data == null) {
            _error = 'Unable to load user profile';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.mintBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.mintBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.displayName,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _buildProfileContent(context, theme),
    );
  }

  Widget _buildProfileContent(BuildContext context, ThemeData theme) {
    if (_userData == null) return const SizedBox();

    final profile = _userData!['profile'] as Map<String, dynamic>?;
    final stats = _userData!['stats'] as Map<String, dynamic>?;

    // Extract profile data
    final name = profile?['name'] as String? ?? widget.displayName;
    final memberSince = profile?['memberSince'] as String? ?? '';

    // Parse member since date
    final memberSinceDate = DateTime.tryParse(memberSince) ?? DateTime.now();
    final memberDays = DateTime.now().difference(memberSinceDate).inDays + 1;

    // Extract stats
    final totalXp = stats?['totalXp'] as int? ?? 0;
    final currentStreak = stats?['currentStreak'] as int? ?? 0;
    final longestStreak = stats?['longestStreak'] as int? ?? 0;
    final totalDaysActive = stats?['totalDaysActive'] as int? ?? 0;

    // Calculate level from XP
    final level = _calculateLevel(totalXp);
    final levelTitle = _getLevelTitle(level);
    final levelProgress = _getLevelProgress(totalXp, level);
    final xpForNextLevel = _getXpForNextLevel(level);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentBlack,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Member for $memberDays days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  // Badges Section
                  const SizedBox(height: 16),
                  _buildBadgesPreview(
                    totalXp,
                    totalDaysActive,
                    longestStreak,
                    theme,
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
                  // Level badge
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
                      'Level $level • $levelTitle',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // XP display
                  Text(
                    '$totalXp',
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
                                widthFactor: levelProgress,
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
                        '${xpForNextLevel - totalXp} XP to Level ${level + 1}',
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

            // Streaks Card - only show if user has activity
            if (totalDaysActive > 0)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: AppTheme.accentBlack,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$currentStreak',
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
                          const Icon(
                            Icons.emoji_events_rounded,
                            color: AppTheme.accentBlack,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$longestStreak',
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
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: AppTheme.accentBlack,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$totalDaysActive',
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
              )
            else
              // No activity yet message
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 48,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No activity yet',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 100), // Bottom spacing
          ],
        ),
      ),
    );
  }

  // Helper methods to mirror XP calculations from xp_data.dart
  int _calculateLevel(int totalXp) {
    for (int i = kLevelThresholds.length - 1; i >= 0; i--) {
      if (totalXp >= kLevelThresholds[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  String _getLevelTitle(int level) {
    if (level <= kLevelTitles.length) {
      return kLevelTitles[level - 1];
    }
    return 'Master';
  }

  double _getLevelProgress(int totalXp, int level) {
    if (level >= kLevelThresholds.length) return 1.0;

    final currentThreshold = kLevelThresholds[level - 1];
    final nextThreshold = kLevelThresholds[level];
    final xpInCurrentLevel = totalXp - currentThreshold;
    final xpNeededForLevel = nextThreshold - currentThreshold;

    return (xpInCurrentLevel / xpNeededForLevel).clamp(0.0, 1.0);
  }

  int _getXpForNextLevel(int level) {
    if (level >= kLevelThresholds.length) {
      return kLevelThresholds.last;
    }
    return kLevelThresholds[level];
  }

  // Badge definitions (same as profile_screen.dart)
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

  Set<String> _getUnlockedBadges(
    int totalXp,
    int totalDaysActive,
    int longestStreak,
  ) {
    final unlocked = <String>{};
    final stats = _userData!['stats'] as Map<String, dynamic>?;
    final totalSteps = stats?['totalStepsAllTime'] as int? ?? 0;

    // Check unlock conditions (simplified - we don't have full history data)
    if (totalDaysActive >= 1) unlocked.add('first_flame');
    if (totalSteps >= 42195) unlocked.add('marathon');
    if (longestStreak >= 7) unlocked.add('week_warrior');
    if (longestStreak >= 30) unlocked.add('month_master');
    if (totalDaysActive >= 100) unlocked.add('centurion');
    if (totalSteps >= 100000) unlocked.add('club_100k');
    if (totalSteps >= 500000) unlocked.add('half_million');
    if (totalSteps >= 1000000) unlocked.add('millionaire');

    return unlocked;
  }

  Widget _buildBadgesPreview(
    int totalXp,
    int totalDaysActive,
    int longestStreak,
    ThemeData theme,
  ) {
    final unlockedBadges = _getUnlockedBadges(
      totalXp,
      totalDaysActive,
      longestStreak,
    );
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

    return Container(
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
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
