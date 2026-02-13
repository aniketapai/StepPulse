import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for accepted friendships
class Friend {
  final String userId;
  final String friendCode;
  final String displayName;
  final int totalXp;
  final int level;
  final DateTime friendsSince;

  const Friend({
    required this.userId,
    required this.friendCode,
    required this.displayName,
    required this.totalXp,
    required this.level,
    required this.friendsSince,
  });

  /// Create from Firestore subcollection document
  factory Friend.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Friend(
      userId: doc.id,
      friendCode: data['friendCode'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Unknown',
      totalXp: data['totalXp'] as int? ?? 0,
      level: data['level'] as int? ?? 1,
      friendsSince:
          (data['friendsSince'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Create from user data (when adding a new friend)
  factory Friend.fromUserData(String userId, Map<String, dynamic> userData) {
    final profile = userData['profile'] as Map<String, dynamic>?;
    final stats = userData['stats'] as Map<String, dynamic>?;
    final totalXp = stats?['totalXp'] as int? ?? 0;

    return Friend(
      userId: userId,
      friendCode: userData['friendCode'] as String? ?? '',
      displayName: profile?['name'] as String? ?? 'Unknown',
      totalXp: totalXp,
      level: calculateLevel(totalXp),
      friendsSince: DateTime.now(),
    );
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toMap() {
    return {
      'friendCode': friendCode,
      'displayName': displayName,
      'totalXp': totalXp,
      'level': level,
      'friendsSince': Timestamp.fromDate(friendsSince),
    };
  }

  /// Calculate level from total XP (mirrors xp_data.dart logic)
  static int calculateLevel(int totalXp) {
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
      'Friend(userId: $userId, name: $displayName, level: $level, xp: $totalXp)';
}
