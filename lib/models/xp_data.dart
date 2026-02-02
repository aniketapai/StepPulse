/// XP and gamification model for StepPulse
library;

/// XP awarded per step
const double kXpPerStep = 0.01;

/// XP awarded for reaching daily goal
const int kGoalBonusXp = 50;

/// XP awarded for streak (per day of streak)
const int kStreakBonusXpPerDay = 10;

/// XP cost to activate a streak freeze
const int kStreakFreezeCost = 500;

/// Level thresholds (10 levels)
/// ~200 XP/day at 10k steps + goal = takes ~3 weeks to max
const List<int> kLevelThresholds = [
  0, // Level 1  - Start
  200, // Level 2  - ~1 day
  500, // Level 3  - ~2-3 days
  1000, // Level 4  - ~5 days
  2000, // Level 5  - ~10 days
  3500, // Level 6  - ~2 weeks
  5500, // Level 7  - ~3 weeks
  8000, // Level 8  - ~1 month
  12000, // Level 9  - ~2 months
  18000, // Level 10 - ~3 months (Master)
];

/// Level titles (10 levels)
const List<String> kLevelTitles = [
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

/// XP data model
class XpData {
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final int totalStepsAllTime;
  final int totalDaysActive;
  final DateTime? lastActiveDate;
  final bool streakFreezeActive;
  final DateTime? streakFreezeDate;

  const XpData({
    this.totalXp = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalStepsAllTime = 0,
    this.totalDaysActive = 0,
    this.lastActiveDate,
    this.streakFreezeActive = false,
    this.streakFreezeDate,
  });

  /// Check if user can afford a streak freeze
  bool get canAffordStreakFreeze => totalXp >= kStreakFreezeCost;

  /// Calculate current level based on total XP
  int get level {
    for (int i = kLevelThresholds.length - 1; i >= 0; i--) {
      if (totalXp >= kLevelThresholds[i]) {
        return i + 1;
      }
    }
    return 1;
  }

  /// Get level title
  String get levelTitle {
    final lvl = level;
    if (lvl <= kLevelTitles.length) {
      return kLevelTitles[lvl - 1];
    }
    return 'Master';
  }

  /// Get XP needed for next level
  int get xpForNextLevel {
    final lvl = level;
    if (lvl >= kLevelThresholds.length) {
      return 0; // Max level
    }
    return kLevelThresholds[lvl];
  }

  /// Get XP progress in current level (0.0 - 1.0)
  double get levelProgress {
    final lvl = level;
    if (lvl >= kLevelThresholds.length) return 1.0;

    final currentLevelXp = kLevelThresholds[lvl - 1];
    final nextLevelXp = kLevelThresholds[lvl];
    final xpInLevel = totalXp - currentLevelXp;
    final xpNeeded = nextLevelXp - currentLevelXp;

    return (xpInLevel / xpNeeded).clamp(0.0, 1.0);
  }

  /// Copy with new values
  XpData copyWith({
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    int? totalStepsAllTime,
    int? totalDaysActive,
    DateTime? lastActiveDate,
    bool? streakFreezeActive,
    DateTime? streakFreezeDate,
  }) {
    return XpData(
      totalXp: totalXp ?? this.totalXp,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalStepsAllTime: totalStepsAllTime ?? this.totalStepsAllTime,
      totalDaysActive: totalDaysActive ?? this.totalDaysActive,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      streakFreezeActive: streakFreezeActive ?? this.streakFreezeActive,
      streakFreezeDate: streakFreezeDate ?? this.streakFreezeDate,
    );
  }

  /// Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'totalXp': totalXp,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalStepsAllTime': totalStepsAllTime,
      'totalDaysActive': totalDaysActive,
      'lastActiveDate': lastActiveDate?.toIso8601String(),
      'streakFreezeActive': streakFreezeActive,
      'streakFreezeDate': streakFreezeDate?.toIso8601String(),
    };
  }

  /// Create from Map
  factory XpData.fromMap(Map<String, dynamic> map) {
    return XpData(
      totalXp: map['totalXp'] as int? ?? 0,
      currentStreak: map['currentStreak'] as int? ?? 0,
      longestStreak: map['longestStreak'] as int? ?? 0,
      totalStepsAllTime: map['totalStepsAllTime'] as int? ?? 0,
      totalDaysActive: map['totalDaysActive'] as int? ?? 0,
      lastActiveDate: map['lastActiveDate'] != null
          ? DateTime.parse(map['lastActiveDate'] as String)
          : null,
      streakFreezeActive: map['streakFreezeActive'] as bool? ?? false,
      streakFreezeDate: map['streakFreezeDate'] != null
          ? DateTime.parse(map['streakFreezeDate'] as String)
          : null,
    );
  }
}
