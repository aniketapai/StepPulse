import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/app_constants.dart';
import '../services/step_service.dart';
import '../services/storage_service.dart';
import '../services/foreground_service.dart';
import '../services/smart_notifications.dart';
import 'settings_provider.dart';
import 'sync_manager.dart';

/// State for step tracking
class StepState {
  final int todaySteps;
  final int rawSteps;
  final int baselineSteps;
  final String currentDate;
  final bool isLoading;
  final bool hasPermission;
  final bool sensorAvailable;
  final String? errorMessage;

  const StepState({
    this.todaySteps = 0,
    this.rawSteps = 0,
    this.baselineSteps = 0,
    this.currentDate = '',
    this.isLoading = true,
    this.hasPermission = false,
    this.sensorAvailable = true,
    this.errorMessage,
  });

  StepState copyWith({
    int? todaySteps,
    int? rawSteps,
    int? baselineSteps,
    String? currentDate,
    bool? isLoading,
    bool? hasPermission,
    bool? sensorAvailable,
    String? errorMessage,
  }) {
    return StepState(
      todaySteps: todaySteps ?? this.todaySteps,
      rawSteps: rawSteps ?? this.rawSteps,
      baselineSteps: baselineSteps ?? this.baselineSteps,
      currentDate: currentDate ?? this.currentDate,
      isLoading: isLoading ?? this.isLoading,
      hasPermission: hasPermission ?? this.hasPermission,
      sensorAvailable: sensorAvailable ?? this.sensorAvailable,
      errorMessage: errorMessage,
    );
  }

  /// Calculate distance based on steps
  double getDistance({required bool useMetric}) {
    final factor = useMetric ? kDistancePerStepKm : kDistancePerStepMiles;
    return todaySteps * factor;
  }

  /// Calculate calories burned
  double get calories => todaySteps * kCaloriesPerStep;

  /// Calculate progress percentage (0.0 to 1.0)
  double getProgress(int dailyGoal) {
    if (dailyGoal <= 0) return 0.0;
    return (todaySteps / dailyGoal).clamp(0.0, 1.0);
  }

  /// Get remaining steps to reach goal
  int getRemainingSteps(int dailyGoal) {
    final remaining = dailyGoal - todaySteps;
    return remaining > 0 ? remaining : 0;
  }
}

/// Notifier for managing step counting state
class StepNotifier extends StateNotifier<StepState> {
  final StepService _stepService;
  final StorageService _storage;
  final SyncManager? _syncManager;
  StreamSubscription<int>? _stepSubscription;
  Timer? _midnightTimer;

  // Track milestone saves to prevent duplicate saves
  final Set<int> _savedMilestones = {}; // {25, 50, 75, 100}

  StepNotifier(this._stepService, this._storage, [this._syncManager])
    : super(const StepState()) {
    _initialize();
  }

  /// Initialize step tracking
  Future<void> _initialize() async {
    // Load saved data
    final savedDate = _storage.currentDate;
    final savedBaseline = _storage.baselineSteps;
    final lastRawSteps = _storage.lastRawSteps;
    final today = StorageService.getTodayDateString();

    // Check if it's a new day
    if (savedDate != null && savedDate != today) {
      // Save yesterday's steps to history
      final yesterdaySteps = lastRawSteps - savedBaseline;
      if (yesterdaySteps > 0) {
        await _storage.saveStepsForDate(savedDate, yesterdaySteps);
      }
      // Reset baseline for new day
      await _storage.setBaselineSteps(lastRawSteps);
      await _storage.setCurrentDate(today);

      state = state.copyWith(
        baselineSteps: lastRawSteps,
        currentDate: today,
        todaySteps: 0,
        isLoading: false,
      );
    } else {
      state = state.copyWith(
        baselineSteps: savedBaseline,
        currentDate: today,
        rawSteps: lastRawSteps,
        todaySteps: lastRawSteps - savedBaseline,
        isLoading: false,
      );

      // Set current date if not set
      if (savedDate == null) {
        await _storage.setCurrentDate(today);
      }
    }

    // Schedule midnight reset
    _scheduleMidnightReset();

    // IMPORTANT: Check for existing permission and start listening automatically
    // This ensures step counting works after app restart
    await _checkAndStartListening();
  }

  /// Check if permission is already granted and start listening
  Future<void> _checkAndStartListening() async {
    // Get the correct permission based on platform
    final permission = Platform.isIOS
        ? Permission.sensors
        : Permission.activityRecognition;

    final status = await permission.status;

    if (status.isGranted) {
      state = state.copyWith(hasPermission: true);
      startListening();

      // Also ensure foreground service is running
      await ForegroundStepService().start();
    }
  }

  /// Set permission status
  void setPermissionStatus(bool granted) {
    state = state.copyWith(hasPermission: granted);
    if (granted) {
      startListening();
    }
  }

  /// Start listening to step sensor
  void startListening() {
    _stepService.startListening();
    _stepSubscription = _stepService.stepStream.listen(
      _onStepCount,
      onError: _onStepError,
    );
  }

  /// Handle new step count from sensor
  void _onStepCount(int rawSteps) {
    final today = StorageService.getTodayDateString();

    // Check for day change
    if (state.currentDate.isNotEmpty && state.currentDate != today) {
      _handleDayChange(rawSteps);
      return;
    }

    // FIRST RUN: If baseline is 0 and we have raw steps, set baseline to current value
    // This means today's steps will start from 0
    if (state.baselineSteps == 0 && rawSteps > 0) {
      _storage.setBaselineSteps(rawSteps);
      _storage.setCurrentDate(today);
      _storage.setLastRawSteps(rawSteps);

      state = state.copyWith(
        rawSteps: rawSteps,
        baselineSteps: rawSteps,
        currentDate: today,
        todaySteps: 0,
        isLoading: false,
        sensorAvailable: true,
      );
      return;
    }

    // Handle device reboot (rawSteps < baseline)
    if (rawSteps < state.baselineSteps && state.baselineSteps > 0) {
      // Device was rebooted, save current progress and reset baseline
      _storage.saveStepsForDate(state.currentDate, state.todaySteps);
      _storage.setBaselineSteps(rawSteps);

      state = state.copyWith(
        rawSteps: rawSteps,
        baselineSteps: rawSteps,
        todaySteps: 0,
      );
      return;
    }

    // Normal case: calculate today's steps
    final todaySteps = rawSteps - state.baselineSteps;

    // Persist raw steps
    _storage.setLastRawSteps(rawSteps);

    state = state.copyWith(
      rawSteps: rawSteps,
      todaySteps: todaySteps,
      isLoading: false,
      sensorAvailable: true,
    );

    // Sync with foreground service notification
    _syncWithForegroundService();

    // Check for smart notifications
    _checkSmartNotifications();

    // Check and save at goal milestones (25%, 50%, 75%, 100%)
    _checkAndSaveMilestones();

    // Trigger cloud sync at milestones (optimized for scale)
    _syncManager?.onStepsChanged(todaySteps, _storage.dailyGoal);
  }

  /// Sync step data with foreground service notification
  void _syncWithForegroundService() {
    ForegroundStepService().updateStepData(
      todaySteps: state.todaySteps,
      baseline: state.baselineSteps,
      goal: _storage.dailyGoal,
    );
  }

  /// Check and save steps at goal milestones (25%, 50%, 75%, 100%)
  /// This prevents data loss if user uninstalls mid-day, while keeping
  /// cloud sync to once per day for cost efficiency.
  void _checkAndSaveMilestones() {
    final goal = _storage.dailyGoal;
    final steps = state.todaySteps;

    if (goal <= 0 || steps <= 0) return;

    // Calculate progress percentage
    final progress = (steps / goal * 100).floor();

    // Define milestones to check (in order)
    const milestones = [25, 50, 75, 100];

    for (final milestone in milestones) {
      if (progress >= milestone && !_savedMilestones.contains(milestone)) {
        // Save current steps to local history (overwrites previous for same date)
        // This is LOCAL ONLY - cloud sync happens once per day when day changes
        _storage.saveStepsForDate(state.currentDate, steps);
        _savedMilestones.add(milestone);

        print(
          '💾 Milestone $milestone% reached ($steps/$goal steps) - saved to local storage',
        );

        // Only save one milestone per step update to avoid excessive writes
        break;
      }
    }
  }

  /// Handle day change (midnight reset)
  Future<void> _handleDayChange(int currentRawSteps) async {
    final previousDate = state.currentDate;
    final today = StorageService.getTodayDateString();

    // Calculate previous day's steps from stored values (not volatile state!)
    // This is important because state.todaySteps may be stale when app resumes
    final storedBaseline = _storage.baselineSteps;
    final storedRawSteps = _storage.lastRawSteps;
    final previousDaySteps = storedRawSteps - storedBaseline;

    // Save previous day's steps to history
    if (previousDate.isNotEmpty && previousDaySteps > 0) {
      await _storage.saveStepsForDate(previousDate, previousDaySteps);
    }

    // Reset live XP tracking for the new day
    await _storage.resetLiveXpTracking();

    // Set new baseline
    await _storage.setBaselineSteps(currentRawSteps);
    await _storage.setCurrentDate(today);
    await _storage.setLastRawSteps(currentRawSteps);

    state = state.copyWith(
      currentDate: today,
      baselineSteps: currentRawSteps,
      rawSteps: currentRawSteps,
      todaySteps: 0,
    );

    // Reset milestone tracking for new day
    _savedMilestones.clear();

    // Reset sync manager daily tracking
    _syncManager?.resetDailyTracking();

    // Reschedule midnight timer
    _scheduleMidnightReset();
  }

  /// Handle sensor errors
  void _onStepError(dynamic error) {
    state = state.copyWith(
      sensorAvailable: false,
      errorMessage: 'Step sensor unavailable: $error',
      isLoading: false,
    );
  }

  /// Schedule timer for midnight reset
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final duration = tomorrow.difference(now);

    _midnightTimer = Timer(duration, () {
      // Trigger day change check on next step update
      final today = StorageService.getTodayDateString();
      if (state.currentDate != today) {
        _handleDayChange(state.rawSteps);
      }
      _scheduleMidnightReset();
    });
  }

  /// Manually save current progress
  Future<void> saveProgress() async {
    if (state.todaySteps > 0) {
      await _storage.saveStepsForDate(state.currentDate, state.todaySteps);
    }
  }

  /// Check and trigger smart notifications
  void _checkSmartNotifications() {
    // Get personal best from history
    final history = _storage.getHistory(days: 365);
    final personalBest = history.isEmpty
        ? 0
        : history.fold<int>(0, (max, h) => h.steps > max ? h.steps : max);

    SmartNotificationService().checkAndNotify(
      todaySteps: state.todaySteps,
      goal: _storage.dailyGoal,
      currentStreak: 0, // Will be updated when we integrate with XP provider
      personalBest: personalBest,
    );

    // Reset inactivity timer when steps increase
    if (state.todaySteps > 0) {
      SmartNotificationService().cancelInactivityReminder();
      SmartNotificationService().scheduleInactivityReminder();
    }
  }

  /// Check if day has changed and handle the transition
  /// This should be called when the app resumes from background
  Future<bool> checkForDayChange() async {
    final today = StorageService.getTodayDateString();

    // If it's still the same day, nothing to do
    if (state.currentDate == today || state.currentDate.isEmpty) {
      return false;
    }

    // Day has changed! Handle the transition
    await _handleDayChange(state.rawSteps);
    return true;
  }

  /// Reset today's steps (for testing)
  Future<void> resetToday() async {
    final rawSteps = state.rawSteps;
    await _storage.setBaselineSteps(rawSteps);
    state = state.copyWith(baselineSteps: rawSteps, todaySteps: 0);
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _midnightTimer?.cancel();
    _stepService.dispose();
    super.dispose();
  }
}

/// Provider for step service
final stepServiceProvider = Provider<StepService>((ref) {
  return StepService();
});

/// Provider for step state (with sync manager integration)
final stepProvider = StateNotifierProvider<StepNotifier, StepState>((ref) {
  final stepService = ref.watch(stepServiceProvider);
  final storage = ref.watch(storageServiceProvider);

  // Try to get sync manager, but don't fail if unavailable
  SyncManager? syncManager;
  try {
    syncManager = ref.watch(syncManagerProvider);
  } catch (_) {
    // Sync manager not available (e.g., during initialization)
  }

  return StepNotifier(stepService, storage, syncManager);
});
