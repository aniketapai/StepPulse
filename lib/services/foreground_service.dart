import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';

/// Callback for foreground task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StepTaskHandler());
}

/// Handler for the foreground step counting task
class StepTaskHandler extends TaskHandler {
  int _baselineSteps = 0;
  int _todaySteps = 0;
  int _goal = 8000;
  String _currentDate = _getTodayDateString();
  int _lastRawSteps = 0;

  /// Get today's date as a string (YYYY-MM-DD)
  static String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Listen to step count
    Pedometer.stepCountStream.listen((event) {
      final rawSteps = event.steps;
      _lastRawSteps = rawSteps;

      // Check for day change
      final today = _getTodayDateString();
      if (_currentDate != today) {
        // Day has changed! Reset for new day
        _currentDate = today;
        _baselineSteps = rawSteps;
        _todaySteps = 0;
        _updateNotification();
        return;
      }

      // Initialize baseline on first reading
      if (_baselineSteps == 0 && rawSteps > 0) {
        _baselineSteps = rawSteps;
      }

      _todaySteps = rawSteps - _baselineSteps;
      if (_todaySteps < 0) _todaySteps = 0;

      _updateNotification();
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Check for day change periodically (every 5 seconds)
    final today = _getTodayDateString();
    if (_currentDate != today) {
      // Day has changed! Reset for new day
      _currentDate = today;
      _baselineSteps = _lastRawSteps;
      _todaySteps = 0;
      _updateNotification();
    } else {
      // Just update notification with current data
      _updateNotification();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Cleanup when service stops
  }

  @override
  void onReceiveData(Object data) {
    // Receive data from the main app
    if (data is Map<String, dynamic>) {
      if (data.containsKey('goal')) {
        _goal = data['goal'] as int;
      }
      if (data.containsKey('baseline')) {
        _baselineSteps = data['baseline'] as int;
      }
      if (data.containsKey('todaySteps')) {
        _todaySteps = data['todaySteps'] as int;
      }
      _updateNotification();
    }
  }

  void _updateNotification() {
    final distance = (_todaySteps * 0.0008).toStringAsFixed(2);
    final calories = (_todaySteps * 0.04).round();
    final progress = ((_todaySteps / _goal) * 100).clamp(0, 100).round();

    FlutterForegroundTask.updateService(
      notificationTitle: '🚶 $_todaySteps steps',
      notificationText: '$distance km • $calories kcal • $progress% of goal',
    );
  }
}

/// Service to manage foreground task
class ForegroundStepService {
  static final ForegroundStepService _instance = ForegroundStepService._();
  factory ForegroundStepService() => _instance;
  ForegroundStepService._();

  /// Initialize the foreground task
  Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'step_pulse_foreground',
        channelName: 'StepPulse Step Tracking',
        channelDescription: 'Shows your current step count',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          5000,
        ), // Update every 5 seconds
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Start the foreground service
  Future<void> start() async {
    // Check if already running
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    // Request notification permission on Android 13+
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Request battery optimization exemption
    final batteryOptimization =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!batteryOptimization) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    // Start the service
    await FlutterForegroundTask.startService(
      notificationTitle: '🚶 0 steps',
      notificationText: 'StepPulse is tracking your steps',
      callback: startCallback,
    );
  }

  /// Stop the foreground service
  Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  /// Check if service is running
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// Update step data in the service
  void updateStepData({
    required int todaySteps,
    required int baseline,
    required int goal,
  }) {
    FlutterForegroundTask.sendDataToTask({
      'todaySteps': todaySteps,
      'baseline': baseline,
      'goal': goal,
    });
  }
}
