import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import 'firestore_provider.dart';

/// Optimized sync manager for cloud data synchronization.
///
/// Designed for scale (5k-10k users) with minimal Firestore writes.
///
/// **Sync triggers:**
/// 1. App goes to background (existing behavior)
/// 2. Goal milestones reached (25%, 50%, 75%, 100%)
/// 3. Every 1000 steps walked
/// 4. Debounced settings changes (5 second delay)
///
/// **Cost estimation for 10k users:**
/// - ~5 syncs/user/day = 50,000 writes/day
/// - Free tier: 20,000/day → ~$2.70/month beyond free tier
class SyncManager {
  final FirestoreService _firestoreService;

  // Debounce timer for rapid changes
  Timer? _debounceTimer;

  // Track last synced values to avoid duplicate syncs
  int _lastSyncedSteps = 0;
  int _lastSyncedMilestone = 0; // 0, 25, 50, 75, 100

  // Minimum time between syncs (prevent spam)
  DateTime? _lastSyncTime;
  static const _minSyncInterval = Duration(seconds: 30);

  // Step milestone interval (sync every N steps)
  // For 10 test users: 500 steps × ~20 syncs × 10 users = 200/day (1% of free tier!)
  // For scale (10k users): increase to 2000+ to stay in free tier
  static const _stepSyncInterval = 500;

  SyncManager(this._firestoreService);

  /// Check if user is logged in
  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  /// Trigger sync on step update - only syncs at milestones
  /// Call this from step provider when steps change
  void onStepsChanged(int currentSteps, int dailyGoal) {
    if (!_isLoggedIn) return;

    // 1. Check for step milestones (every 1000 steps)
    final stepMilestone =
        (currentSteps ~/ _stepSyncInterval) * _stepSyncInterval;
    if (stepMilestone > _lastSyncedSteps && stepMilestone > 0) {
      _lastSyncedSteps = stepMilestone;
      _syncWithThrottle(reason: 'step_milestone_$stepMilestone');
    }

    // 2. Check for goal milestones (25%, 50%, 75%, 100%)
    if (dailyGoal > 0) {
      final progressPercent = (currentSteps / dailyGoal * 100).toInt();
      int goalMilestone = 0;

      if (progressPercent >= 100 && _lastSyncedMilestone < 100) {
        goalMilestone = 100;
      } else if (progressPercent >= 75 && _lastSyncedMilestone < 75) {
        goalMilestone = 75;
      } else if (progressPercent >= 50 && _lastSyncedMilestone < 50) {
        goalMilestone = 50;
      } else if (progressPercent >= 25 && _lastSyncedMilestone < 25) {
        goalMilestone = 25;
      }

      if (goalMilestone > _lastSyncedMilestone) {
        _lastSyncedMilestone = goalMilestone;
        _syncWithThrottle(
          reason: 'goal_milestone_$goalMilestone',
          priority: true,
        );
      }
    }
  }

  /// Trigger debounced sync for settings changes
  /// Waits 5 seconds after last change before syncing
  void onSettingsChanged() {
    if (!_isLoggedIn) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      _syncWithThrottle(reason: 'settings_change');
    });
  }

  /// Force immediate sync (e.g., app going to background)
  Future<void> syncNow({String reason = 'manual'}) async {
    if (!_isLoggedIn) return;

    _debounceTimer?.cancel();
    await _doSync(reason: reason);
  }

  /// Reset daily tracking (call at midnight)
  void resetDailyTracking() {
    _lastSyncedSteps = 0;
    _lastSyncedMilestone = 0;
  }

  /// Internal: Sync with throttling to prevent spam
  void _syncWithThrottle({required String reason, bool priority = false}) {
    // Skip if synced too recently (unless priority)
    if (!priority && _lastSyncTime != null) {
      final elapsed = DateTime.now().difference(_lastSyncTime!);
      if (elapsed < _minSyncInterval) {
        return;
      }
    }

    _doSync(reason: reason);
  }

  /// Internal: Actually perform the sync
  Future<void> _doSync({required String reason}) async {
    _lastSyncTime = DateTime.now();

    try {
      await _firestoreService.saveUserData();
      print('☁️ [SyncManager] Synced: $reason');
    } catch (e) {
      print('⚠️ [SyncManager] Sync failed ($reason): $e');
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}

/// Provider for the sync manager
final syncManagerProvider = Provider<SyncManager>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return SyncManager(firestoreService);
});
