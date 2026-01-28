import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/xp_data.dart';
import '../services/storage_service.dart';
import '../services/smart_notifications.dart';
import 'settings_provider.dart';

/// XP provider for gamification
class XpNotifier extends StateNotifier<XpData> {
  final StorageService _storage;

  XpNotifier(this._storage) : super(const XpData()) {
    _loadXpData();
  }

  /// Load XP data from storage
  void _loadXpData() {
    final data = _storage.getXpData();
    if (data != null) {
      state = XpData.fromMap(data);
    }
    // Recalculate streak stats from history data
    _recalculateStreakStats();
  }

  /// Recalculate current streak, longest streak, and days active from step history
  void _recalculateStreakStats() {
    final historyMap = _storage.getHistoryMap(days: 365);
    if (historyMap.isEmpty) return;

    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    // Calculate current streak (consecutive days with steps, starting from today/yesterday)
    int currentStreak = 0;
    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = dateFormat.format(date);
      final steps = historyMap[dateStr] ?? 0;
      if (steps > 0) {
        currentStreak++;
      } else if (i > 0) {
        // Allow today to have 0 steps (day not over yet), but break if any past day is 0
        break;
      }
    }

    // Calculate longest streak and total days active
    int longestStreak = 0;
    int tempStreak = 0;
    int totalDaysActive = 0;
    DateTime? lastActiveDate;

    // Sort dates chronologically
    final sortedDates = historyMap.keys.toList()..sort();

    for (int i = 0; i < sortedDates.length; i++) {
      final dateStr = sortedDates[i];
      final steps = historyMap[dateStr] ?? 0;

      if (steps > 0) {
        totalDaysActive++;
        final currentDate = DateTime.parse(dateStr);

        // Track last active date
        if (lastActiveDate == null || currentDate.isAfter(lastActiveDate)) {
          lastActiveDate = currentDate;
        }

        // Check if consecutive day
        if (i > 0) {
          final prevDateStr = sortedDates[i - 1];
          final prevDate = DateTime.parse(prevDateStr);
          final daysDiff = currentDate.difference(prevDate).inDays;

          if (daysDiff == 1 && (historyMap[prevDateStr] ?? 0) > 0) {
            // Consecutive day
            tempStreak++;
          } else {
            // Streak broken, start new streak
            tempStreak = 1;
          }
        } else {
          tempStreak = 1;
        }

        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      }
    }

    // Update state with calculated values
    state = state.copyWith(
      currentStreak: currentStreak,
      longestStreak: longestStreak > state.longestStreak
          ? longestStreak
          : state.longestStreak,
      totalDaysActive: totalDaysActive,
      lastActiveDate: lastActiveDate ?? state.lastActiveDate,
    );

    // Persist the updated stats
    _storage.saveXpData(state.toMap());
  }

  /// Award XP for daily steps (called at end of day / day change)
  Future<void> awardDailyXp({
    required int steps,
    required int goal,
    required String date,
  }) async {
    // Store previous level for comparison
    final previousLevel = state.level;

    // Calculate streak
    final today = DateTime.now();
    final lastActive = state.lastActiveDate;
    int newStreak = state.currentStreak;

    if (lastActive != null) {
      final daysDiff = today.difference(lastActive).inDays;
      if (daysDiff == 1) {
        // Consecutive day
        newStreak = state.currentStreak + 1;
      } else if (daysDiff > 1) {
        // Streak broken
        newStreak = 1;
      }
      // Same day = no change
    } else {
      newStreak = 1;
    }

    // Streak bonus (awarded at end of day)
    final streakBonus = newStreak * kStreakBonusXpPerDay;

    // Update state with streak info and bonus
    // Note: Step XP and goal bonus are already awarded live
    state = state.copyWith(
      totalXp: state.totalXp + streakBonus,
      currentStreak: newStreak,
      longestStreak: newStreak > state.longestStreak
          ? newStreak
          : state.longestStreak,
      totalStepsAllTime: state.totalStepsAllTime + steps,
      totalDaysActive: state.totalDaysActive + 1,
      lastActiveDate: today,
    );

    // Persist
    await _storage.saveXpData(state.toMap());

    // Check for level-up and send notification
    if (state.level > previousLevel) {
      SmartNotificationService().showLevelUpNotification(
        newLevel: state.level,
        levelTitle: state.levelTitle,
      );
    }
  }

  /// Update XP in real-time based on today's steps (called on each step update)
  /// This provides immediate feedback without waiting for end of day
  Future<void> updateLiveXp({
    required int todaySteps,
    required int goal,
  }) async {
    // Get what was saved at previous checkpoint
    final lastSavedSteps = _storage.lastLiveXpSteps;

    // Only update if we've gained 100+ new steps (1 XP)
    final stepsSinceLastUpdate = todaySteps - lastSavedSteps;
    if (stepsSinceLastUpdate < 100) return;

    // Calculate XP to add (floor to ensure we only add complete XP points)
    final xpToAdd = (stepsSinceLastUpdate * kXpPerStep).floor();
    if (xpToAdd <= 0) return;

    // Save checkpoint
    final newCheckpoint =
        lastSavedSteps + (xpToAdd * 100); // steps that earned XP
    await _storage.setLastLiveXpSteps(newCheckpoint);

    // Check for goal bonus (only award once per day)
    final goalBonusAwarded = _storage.goalBonusAwarded;
    int goalBonus = 0;
    if (!goalBonusAwarded && todaySteps >= goal) {
      goalBonus = kGoalBonusXp;
      await _storage.setGoalBonusAwarded(true);
    }

    // Store previous level for comparison
    final previousLevel = state.level;

    // Update XP state
    state = state.copyWith(totalXp: state.totalXp + xpToAdd + goalBonus);

    // Persist
    await _storage.saveXpData(state.toMap());

    // Check for level-up and send notification
    if (state.level > previousLevel) {
      SmartNotificationService().showLevelUpNotification(
        newLevel: state.level,
        levelTitle: state.levelTitle,
      );
    }
  }

  /// Reset live XP tracking for new day
  Future<void> resetLiveTracking() async {
    await _storage.setLastLiveXpSteps(0);
    await _storage.setGoalBonusAwarded(false);
  }

  /// Get XP breakdown for display
  Map<String, int> getXpBreakdown(int steps, int goal) {
    final stepXp = (steps * kXpPerStep).round();
    final goalBonus = steps >= goal ? kGoalBonusXp : 0;
    final streakBonus = state.currentStreak * kStreakBonusXpPerDay;

    return {
      'steps': stepXp,
      'goal': goalBonus,
      'streak': streakBonus,
      'total': stepXp + goalBonus + streakBonus,
    };
  }

  /// Reset all XP progress
  void reset() {
    state = const XpData();
  }

  /// Reload XP data from storage (call after Firestore sync)
  void refresh() {
    _loadXpData();
  }
}

/// Provider for XP state
final xpProvider = StateNotifierProvider<XpNotifier, XpData>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return XpNotifier(storage);
});
