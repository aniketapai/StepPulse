import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../providers/friends_provider.dart';
import '../providers/challenges_provider.dart';
import '../providers/xp_provider.dart';
import '../providers/settings_provider.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';
import '../models/challenge.dart';
import '../core/theme/app_theme.dart';

/// Friends sidebar that slides in from the right
class FriendsSidebar extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const FriendsSidebar({super.key, required this.onClose});

  @override
  ConsumerState<FriendsSidebar> createState() => _FriendsSidebarState();
}

class _FriendsSidebarState extends ConsumerState<FriendsSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  int _currentTab =
      0; // 0 = Friends, 1 = Leaderboard, 2 = Challenges, 3 = Requests
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();

    // Load friends data (force refresh each time sidebar opens)
    Future.microtask(() {
      ref.read(friendsProvider.notifier).initialize(force: true);
      ref.read(challengesProvider.notifier).loadChallenges();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    await _animationController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleClose,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) => Container(
          color: Colors.black.withValues(
            alpha: 0.5 * _animationController.value,
          ),
          child: child,
        ),
        child: GestureDetector(
          onTap: () {}, // Prevent tap from closing when clicking on sidebar
          child: Align(
            alignment: Alignment.centerRight,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: AppTheme.mintBackground,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                ),
                child: Material(
                  color: AppTheme.mintBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildTabs(),
                        Expanded(
                          child: _currentTab == 0
                              ? _buildFriendsTab()
                              : _currentTab == 1
                              ? _buildLeaderboardTab()
                              : _currentTab == 2
                              ? _buildChallengesTab()
                              : _buildRequestsTab(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final state = ref.watch(friendsProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_rounded,
                color: AppTheme.accentBlack,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Friends',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentBlack,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _handleClose,
                icon: const Icon(Icons.close_rounded),
                color: AppTheme.accentBlack,
              ),
            ],
          ),
          // Friend code row
          if (state.friendCode != null)
            GestureDetector(
              onTap: () => _copyFriendCode(state.friendCode),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your code: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.accentBlack.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      state.friendCode!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentBlack,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.content_copy_rounded,
                      size: 15,
                      color: AppTheme.accentBlack.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final state = ref.watch(friendsProvider);
    final challengesState = ref.watch(challengesProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              label: 'Friends',
              index: 0,
              count: state.friends.length,
            ),
          ),
          Expanded(child: _buildTab(label: 'Board', index: 1)),
          Expanded(
            child: _buildTab(
              label: '⚔️',
              index: 2,
              count:
                  challengesState.pendingCount +
                  challengesState.activeChallenges.length,
              showBadge: challengesState.pendingCount > 0,
            ),
          ),
          Expanded(
            child: _buildTab(
              label: 'Requests',
              index: 3,
              count: state.pendingRequestsCount,
              showBadge: state.pendingRequestsCount > 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required int index,
    int? count,
    bool showBadge = false,
  }) {
    final isSelected = _currentTab == index;

    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlack : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.accentBlack,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: showBadge
                      ? const Color(0xFFFF6B6B)
                      : (isSelected ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected || showBadge
                        ? Colors.white
                        : AppTheme.accentBlack,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    final state = ref.watch(friendsProvider);

    return Column(
      children: [
        const SizedBox(height: 16),
        _buildSearchBar(),
        const SizedBox(height: 16),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
              ? _buildErrorState(state.error!)
              : state.friends.isEmpty
              ? _buildEmptyState(
                  icon: Icons.person_add_rounded,
                  title: 'No friends yet',
                  subtitle: 'Add friends by entering their friend code above',
                )
              : _buildFriendsList(state.friends),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTab() {
    final state = ref.watch(friendsProvider);
    final xpState = ref.watch(xpProvider);
    final storage = ref.read(storageServiceProvider);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _buildErrorState(state.error!);
    }

    if (state.friends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.leaderboard_rounded,
        title: 'No friends yet',
        subtitle: 'Add friends to see how you compare!',
      );
    }

    // Build leaderboard entries: friends + current user
    final entries = <_LeaderboardItem>[];

    // Add current user
    final myName = storage.profileName;
    entries.add(
      _LeaderboardItem(
        name: myName,
        xp: xpState.totalXp,
        level: xpState.level,
        isCurrentUser: true,
        userId: currentUser?.uid ?? '',
      ),
    );

    // Add friends
    for (final friend in state.friends) {
      entries.add(
        _LeaderboardItem(
          name: friend.displayName,
          xp: friend.totalXp,
          level: friend.level,
          isCurrentUser: false,
          userId: friend.userId,
        ),
      );
    }

    // Sort by XP descending
    entries.sort((a, b) => b.xp.compareTo(a.xp));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildLeaderboardEntry(entry, index + 1);
      },
    );
  }

  Widget _buildLeaderboardEntry(_LeaderboardItem entry, int rank) {
    final isTop3 = rank <= 3;
    final rankColors = {
      1: const Color(0xFFFFD700), // Gold
      2: const Color(0xFFC0C0C0), // Silver
      3: const Color(0xFFCD7F32), // Bronze
    };
    final rankIcons = {1: '🥇', 2: '🥈', 3: '🥉'};

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: entry.isCurrentUser
            ? AppTheme.accentBlack.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: entry.isCurrentUser
            ? Border.all(
                color: AppTheme.accentBlack.withValues(alpha: 0.2),
                width: 1.5,
              )
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: isTop3
                ? Text(
                    rankIcons[rank]!,
                    style: const TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  )
                : Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentBlack.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 10),
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.isCurrentUser
                  ? AppTheme.accentBlack
                  : AppTheme.accentBlack.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: entry.isCurrentUser
                      ? Colors.white
                      : AppTheme.accentBlack,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + Level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isCurrentUser ? '${entry.name} (You)' : entry.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: entry.isCurrentUser
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: AppTheme.accentBlack,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Level ${entry.level}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentBlack.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          // XP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NumberFormat('#,###').format(entry.xp),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isTop3
                      ? rankColors[rank] ?? AppTheme.accentBlack
                      : AppTheme.accentBlack,
                ),
              ),
              Text(
                'XP',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.accentBlack.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copyFriendCode(String? code) async {
    if (code == null) return;

    await Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.mediumImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Friend code copied!'),
            ],
          ),
          backgroundColor: AppTheme.accentBlack,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ==================== CHALLENGES TAB ====================

  Widget _buildChallengesTab() {
    final challengesState = ref.watch(challengesProvider);
    final friendsState = ref.watch(friendsProvider);

    if (challengesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (challengesState.error != null) {
      return _buildErrorState(challengesState.error!);
    }

    final hasContent =
        challengesState.pendingChallenges.isNotEmpty ||
        challengesState.activeChallenges.isNotEmpty ||
        challengesState.completedChallenges.isNotEmpty;

    return Column(
      children: [
        // Create challenge button
        if (friendsState.friends.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateChallengeSheet(),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('New Challenge'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlack,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: !hasContent
              ? _buildEmptyState(
                  icon: Icons.emoji_events_rounded,
                  title: 'No challenges yet',
                  subtitle: friendsState.friends.isEmpty
                      ? 'Add friends first to start challenging them!'
                      : 'Tap "New Challenge" to get started!',
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pending challenges (received)
                      if (challengesState.pendingChallenges.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B6B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Incoming Challenges',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentBlack,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...challengesState.pendingChallenges.map(
                          (c) => _buildPendingChallengeCard(c),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Active challenges
                      if (challengesState.activeChallenges.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentBlack,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...challengesState.activeChallenges.map(
                          (c) => _buildActiveChallengeCard(c),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Completed challenges
                      if (challengesState.completedChallenges.isNotEmpty) ...[
                        const Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentBlack,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...challengesState.completedChallenges
                            .take(5)
                            .map((c) => _buildCompletedChallengeCard(c)),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPendingChallengeCard(Challenge challenge) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final opponentName = challenge.getOpponentName(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(challenge.type.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.type.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentBlack,
                      ),
                    ),
                    Text(
                      'from $opponentName',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentBlack.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlack.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${challenge.totalDays}d',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleAcceptChallenge(challenge.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleDeclineChallenge(challenge.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                    side: const BorderSide(color: Color(0xFFFF6B6B)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChallengeCard(Challenge challenge) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final opponentName = challenge.getOpponentName(userId);
    final myProgress = challenge.getUserProgress(userId);
    final theirProgress = challenge.getOpponentProgress(userId);
    final maxProgress =
        (myProgress > theirProgress ? myProgress : theirProgress)
            .clamp(1, double.maxFinite)
            .toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(challenge.type.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.type.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentBlack,
                      ),
                    ),
                    Text(
                      'vs $opponentName',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentBlack.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${challenge.daysRemaining}d left',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentBlack,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 50,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: challenge.timeProgress,
                        minHeight: 3,
                        backgroundColor: AppTheme.accentBlack.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // My progress
          _buildProgressRow(
            label: 'You',
            value: myProgress,
            unit: challenge.type.unit,
            fraction: myProgress / maxProgress,
            color: const Color(0xFF4CAF50),
            isWinning: myProgress >= theirProgress,
          ),
          const SizedBox(height: 8),
          // Opponent progress
          _buildProgressRow(
            label: opponentName.split(' ').first,
            value: theirProgress,
            unit: challenge.type.unit,
            fraction: theirProgress / maxProgress,
            color: const Color(0xFFFF6B6B),
            isWinning: theirProgress > myProgress,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required int value,
    required String unit,
    required double fraction,
    required Color color,
    required bool isWinning,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isWinning ? FontWeight.w700 : FontWeight.w500,
              color: AppTheme.accentBlack,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.accentBlack.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${NumberFormat.compact().format(value)} $unit',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.accentBlack.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedChallengeCard(Challenge challenge) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final opponentName = challenge.getOpponentName(userId);
    final myProgress = challenge.getUserProgress(userId);
    final theirProgress = challenge.getOpponentProgress(userId);
    final didWin = challenge.winnerId == userId;
    final isTie = challenge.winnerId == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(challenge.type.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs $opponentName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentBlack,
                  ),
                ),
                Text(
                  '${NumberFormat.compact().format(myProgress)} vs '
                  '${NumberFormat.compact().format(theirProgress)} ${challenge.type.unit}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accentBlack.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isTie
                  ? Colors.amber.withValues(alpha: 0.15)
                  : didWin
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                  : const Color(0xFFFF6B6B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isTie
                  ? '🤝 Tie'
                  : didWin
                  ? '🏆 Won'
                  : '😔 Lost',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isTie
                    ? Colors.amber.shade800
                    : didWin
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Challenge creation bottom sheet
  void _showCreateChallengeSheet() {
    final friends = ref.read(friendsProvider).friends;
    if (friends.isEmpty) return;

    String? selectedFriendId;
    String? selectedFriendName;
    ChallengeType selectedType = ChallengeType.steps;
    ChallengeDuration selectedDuration = ChallengeDuration.oneWeek;
    int step = 0; // 0 = pick friend, 1 = pick type + duration

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.55,
              decoration: const BoxDecoration(
                color: AppTheme.mintBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlack.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      step == 0 ? 'Choose Opponent' : 'Challenge Setup',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentBlack,
                      ),
                    ),
                  ),
                  Expanded(
                    child: step == 0
                        ? _buildFriendPickerStep(friends, (id, name) {
                            setSheetState(() {
                              selectedFriendId = id;
                              selectedFriendName = name;
                              step = 1;
                            });
                          })
                        : _buildChallengeConfigStep(
                            friendName: selectedFriendName!,
                            selectedType: selectedType,
                            selectedDuration: selectedDuration,
                            onTypeChanged: (t) =>
                                setSheetState(() => selectedType = t),
                            onDurationChanged: (d) =>
                                setSheetState(() => selectedDuration = d),
                            onSend: () async {
                              Navigator.pop(ctx);
                              await _handleCreateChallenge(
                                type: selectedType,
                                opponentId: selectedFriendId!,
                                opponentName: selectedFriendName!,
                                duration: selectedDuration,
                              );
                            },
                            onBack: () => setSheetState(() => step = 0),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendPickerStep(
    List<Friend> friends,
    void Function(String id, String name) onSelect,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => onSelect(friend.userId, friend.displayName),
            leading: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.accentBlack,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  friend.displayName.isNotEmpty
                      ? friend.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(
              friend.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.accentBlack,
              ),
            ),
            subtitle: Text(
              'Level ${friend.level} • ${friend.totalXp} XP',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.accentBlack.withValues(alpha: 0.6),
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.accentBlack,
            ),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChallengeConfigStep({
    required String friendName,
    required ChallengeType selectedType,
    required ChallengeDuration selectedDuration,
    required ValueChanged<ChallengeType> onTypeChanged,
    required ValueChanged<ChallengeDuration> onDurationChanged,
    required VoidCallback onSend,
    required VoidCallback onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button + opponent name
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.accentBlack,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'vs $friendName',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.accentBlack.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Challenge type picker
          const Text(
            'Challenge Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentBlack,
            ),
          ),
          const SizedBox(height: 10),
          ...ChallengeType.values.map((type) {
            final isSelected = type == selectedType;
            return GestureDetector(
              onTap: () => onTypeChanged(type),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentBlack.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(
                          color: AppTheme.accentBlack.withValues(alpha: 0.3),
                          width: 1.5,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Text(type.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppTheme.accentBlack,
                            ),
                          ),
                          Text(
                            type.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.accentBlack.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.accentBlack,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          // Duration picker
          const Text(
            'Duration',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.accentBlack,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: ChallengeDuration.values.map((dur) {
              final isSelected = dur == selectedDuration;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onDurationChanged(dur),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accentBlack : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dur.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.accentBlack,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Send ${selectedType.emoji} Challenge',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _handleCreateChallenge({
    required ChallengeType type,
    required String opponentId,
    required String opponentName,
    required ChallengeDuration duration,
  }) async {
    try {
      await ref
          .read(challengesProvider.notifier)
          .createChallenge(
            type: type,
            opponentId: opponentId,
            opponentName: opponentName,
            duration: duration,
          );
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type.emoji} Challenge sent to $opponentName!'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create challenge: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Future<void> _handleAcceptChallenge(String challengeId) async {
    try {
      await ref.read(challengesProvider.notifier).acceptChallenge(challengeId);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge accepted! Let\'s go! 🔥'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Future<void> _handleDeclineChallenge(String challengeId) async {
    try {
      await ref.read(challengesProvider.notifier).declineChallenge(challengeId);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Widget _buildRequestsTab() {
    final state = ref.watch(friendsProvider);

    return state.isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.receivedRequests.isNotEmpty) ...[
                  const Text(
                    'Received',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...state.receivedRequests.map(
                    (request) => _buildReceivedRequestCard(request),
                  ),
                ],
                if (state.sentRequests.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Sent',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...state.sentRequests.map(
                    (request) => _buildSentRequestCard(request),
                  ),
                ],
                if (state.receivedRequests.isEmpty &&
                    state.sentRequests.isEmpty)
                  _buildEmptyState(
                    icon: Icons.inbox_rounded,
                    title: 'No pending requests',
                    subtitle: 'Friend requests will appear here',
                  ),
              ],
            ),
          );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Enter friend code (#XXXX1234)',
          hintStyle: TextStyle(
            color: AppTheme.accentBlack.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: const Icon(Icons.search, color: AppTheme.accentBlack),
          suffixIcon: IconButton(
            icon: const Icon(Icons.send_rounded, color: AppTheme.accentBlack),
            onPressed: _handleSendRequest,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(color: AppTheme.accentBlack),
        cursorColor: AppTheme.accentBlack,
        textCapitalization: TextCapitalization.characters,
        onSubmitted: (_) => _handleSendRequest(),
      ),
    );
  }

  Future<void> _handleSendRequest() async {
    final code = _searchController.text.trim();
    if (code.isEmpty) return;

    try {
      await ref.read(friendsProvider.notifier).sendRequest(code);
      _searchController.clear();
      HapticFeedback.lightImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
        // Switch to requests tab
        setState(() => _currentTab = 3);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFFF6B6B),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildFriendsList(List<Friend> friends) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return _buildFriendCard(friend);
      },
    );
  }

  Widget _buildFriendCard(Friend friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppTheme.accentBlack,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                friend.displayName.isNotEmpty
                    ? friend.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${friend.friendCode} • Level ${friend.level} • ${friend.totalXp} XP',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentBlack.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showRemoveFriendDialog(friend),
            icon: const Icon(Icons.more_vert_rounded),
            color: AppTheme.accentBlack,
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedRequestCard(FriendRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppTheme.accentBlack,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    request.senderName.isNotEmpty
                        ? request.senderName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.senderName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentBlack,
                      ),
                    ),
                    Text(
                      request.senderCode,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentBlack.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleAcceptRequest(request.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleRejectRequest(request.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                    side: const BorderSide(color: Color(0xFFFF6B6B)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentRequestCard(FriendRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentBlack.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentBlack.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                request.receiverName.isNotEmpty
                    ? request.receiverName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppTheme.accentBlack,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.receiverName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentBlack,
                  ),
                ),
                Text(
                  'Request sent',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentBlack.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _handleCancelRequest(request.id),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppTheme.accentBlack.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentBlack,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.accentBlack.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(friendsProvider.notifier).initialize(force: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlack,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppTheme.accentBlack.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentBlack.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.accentBlack.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAcceptRequest(String requestId) async {
    try {
      await ref.read(friendsProvider.notifier).acceptRequest(requestId);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted!'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Future<void> _handleRejectRequest(String requestId) async {
    try {
      await ref.read(friendsProvider.notifier).rejectRequest(requestId);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Future<void> _handleCancelRequest(String requestId) async {
    try {
      await ref.read(friendsProvider.notifier).cancelRequest(requestId);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel request: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF6B6B),
          ),
        );
      }
    }
  }

  Future<void> _showRemoveFriendDialog(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove ${friend.displayName} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF6B6B),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(friendsProvider.notifier).removeFriend(friend.userId);
        HapticFeedback.mediumImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${friend.displayName} removed from friends'),
              backgroundColor: AppTheme.accentBlack,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove friend: ${e.toString()}'),
              backgroundColor: const Color(0xFFFF6B6B),
            ),
          );
        }
      }
    }
  }
}

/// Simple data class for leaderboard entries
class _LeaderboardItem {
  final String name;
  final int xp;
  final int level;
  final bool isCurrentUser;
  final String userId;

  const _LeaderboardItem({
    required this.name,
    required this.xp,
    required this.level,
    required this.isCurrentUser,
    required this.userId,
  });
}
