/// Leaderboard entry model for global XP rankings
class LeaderboardEntry {
  final int rank;
  final String displayName;
  final int totalXp;
  final int level;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.totalXp,
    required this.level,
    this.isCurrentUser = false,
  });

  /// Create from Firestore document data
  factory LeaderboardEntry.fromMap(
    Map<String, dynamic> map,
    int rank, {
    bool isCurrentUser = false,
  }) {
    // Extract XP from stats object or direct field
    final stats = map['stats'] as Map<String, dynamic>?;
    final totalXp = stats?['totalXp'] as int? ?? map['totalXp'] as int? ?? 0;

    // Calculate level from XP
    final level = _calculateLevel(totalXp);

    // Get display name from profile or direct field
    final profile = map['profile'] as Map<String, dynamic>?;
    final displayName =
        profile?['name'] as String? ??
        map['displayName'] as String? ??
        'Anonymous';

    return LeaderboardEntry(
      rank: rank,
      displayName: displayName,
      totalXp: totalXp,
      level: level,
      isCurrentUser: isCurrentUser,
    );
  }

  /// Calculate level from total XP (mirrors xp_data.dart logic)
  static int _calculateLevel(int totalXp) {
    const thresholds = [
      0,
      200,
      500,
      1000,
      2000,
      3500,
      5500,
      8000,
      12000,
      18000,
    ];
    for (int i = thresholds.length - 1; i >= 0; i--) {
      if (totalXp >= thresholds[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  /// Get level title for display
  String get levelTitle {
    const titles = [
      'Beginner',
      'Walker',
      'Strider',
      'Hiker',
      'Explorer',
      'Adventurer',
      'Trailblazer',
      'Champion',
      'Legend',
      'Master',
    ];
    if (level <= titles.length) {
      return titles[level - 1];
    }
    return 'Master';
  }

  @override
  String toString() =>
      'LeaderboardEntry(rank: $rank, name: $displayName, xp: $totalXp)';
}
