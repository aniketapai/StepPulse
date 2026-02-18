import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/leaderboard_provider.dart';
import '../../models/leaderboard_entry.dart';
import 'user_profile_screen.dart';

/// Bottom sheet displaying the global XP leaderboard
class LeaderboardBottomSheet extends ConsumerStatefulWidget {
  const LeaderboardBottomSheet({super.key});

  @override
  ConsumerState<LeaderboardBottomSheet> createState() =>
      _LeaderboardBottomSheetState();
}

class _LeaderboardBottomSheetState
    extends ConsumerState<LeaderboardBottomSheet> {
  @override
  void initState() {
    super.initState();
    // Fetch leaderboard when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaderboardProvider.notifier).fetchLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leaderboard = ref.watch(leaderboardProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textPrimaryC(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Global Leaderboard',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryC(context),
                        ),
                      ),
                      if (leaderboard.totalUsers > 0)
                        Text(
                          '${leaderboard.totalUsers} walkers',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryC(context),
                          ),
                        ),
                    ],
                  ),
                ),
                // Refresh button
                IconButton(
                  onPressed: leaderboard.isLoading
                      ? null
                      : () => ref
                            .read(leaderboardProvider.notifier)
                            .fetchLeaderboard(force: true),
                  icon: leaderboard.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.textSecondaryC(context),
                          ),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          color: AppTheme.textSecondaryC(context),
                        ),
                ),
              ],
            ),
          ),

          // Cache info
          if (leaderboard.lastFetched != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Updated ${_formatLastFetched(leaderboard.lastFetched!)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondaryC(
                    context,
                  ).withValues(alpha: 0.7),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Divider
          Divider(
            height: 1,
            color: AppTheme.textPrimaryC(context).withValues(alpha: 0.1),
          ),

          // Leaderboard list
          Flexible(
            child: leaderboard.isLoading && leaderboard.entries.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : leaderboard.error != null && leaderboard.entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: AppTheme.textSecondaryC(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to load leaderboard',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryC(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : leaderboard.entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 48,
                            color: AppTheme.textSecondaryC(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No walkers yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryC(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: leaderboard.entries.length,
                    itemBuilder: (context, index) {
                      final entry = leaderboard.entries[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, _, __) =>
                                  UserProfileScreen(
                                    userId: entry.userId,
                                    displayName: entry.displayName,
                                  ),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        },
                        child: _LeaderboardTile(entry: entry),
                      );
                    },
                  ),
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  String _formatLastFetched(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Individual leaderboard tile
class _LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;

  const _LeaderboardTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTopThree = entry.rank <= 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppTheme.bg(context)
            : isTopThree
            ? _getRankColor(entry.rank).withValues(alpha: 0.1)
            : AppTheme.subtleBg(context),
        borderRadius: BorderRadius.circular(12),
        border: entry.isCurrentUser
            ? Border.all(color: AppTheme.accent(context), width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isTopThree
                  ? _getRankColor(entry.rank)
                  : AppTheme.subtleBg(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isTopThree
                  ? Icon(
                      _getRankIcon(entry.rank),
                      color: Colors.white,
                      size: 18,
                    )
                  : Text(
                      '${entry.rank}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryC(context),
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // Name and level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: entry.isCurrentUser
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: AppTheme.textPrimaryC(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'YOU',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.bgDark,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Level ${entry.level} • ${entry.levelTitle}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondaryC(context),
                  ),
                ),
              ],
            ),
          ),

          // XP count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatXp(entry.totalXp),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryC(context),
                ),
              ),
              Text(
                'XP',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondaryC(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }

  IconData _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.looks_one_rounded;
      case 2:
        return Icons.looks_two_rounded;
      case 3:
        return Icons.looks_3_rounded;
      default:
        return Icons.circle;
    }
  }

  String _formatXp(int xp) {
    if (xp >= 10000) {
      return '${(xp / 1000).toStringAsFixed(1)}k';
    } else if (xp >= 1000) {
      return '${(xp / 1000).toStringAsFixed(1)}k';
    }
    return xp.toString();
  }
}

/// Show the leaderboard bottom sheet
void showLeaderboardSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const LeaderboardBottomSheet(),
  );
}
