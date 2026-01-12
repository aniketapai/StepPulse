import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Smart notification service for StepPulse
/// Handles 10 types of motivational notifications:
///
/// **Progress:** 50%, 75%, 100% goal reached
/// **Time-Based:** Midday low steps, Evening reminder
/// **Streak:** Don't break the streak
/// **Milestone:** First 1k steps, Personal best
/// **Motivational:** Long inactivity
class SmartNotificationService {
  static final SmartNotificationService _instance =
      SmartNotificationService._();
  factory SmartNotificationService() => _instance;
  SmartNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Track which notifications have been sent today
  final Set<String> _sentToday = {};
  String? _lastResetDate;

  // Store last known values for comparison
  int _lastKnownSteps = 0;

  /// Initialize the notification service
  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);
  }

  /// Reset daily tracking at midnight
  void _checkDateReset() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (_lastResetDate != today) {
      _sentToday.clear();
      _lastResetDate = today;
    }
  }

  /// Check and send appropriate notifications based on current state
  Future<void> checkAndNotify({
    required int todaySteps,
    required int goal,
    required int currentStreak,
    required int personalBest,
  }) async {
    _checkDateReset();

    final progress = todaySteps / goal;
    final hour = DateTime.now().hour;

    // === PROGRESS NOTIFICATIONS ===

    // 50% reached
    if (progress >= 0.5 && !_sentToday.contains('progress_50')) {
      await _showNotification(
        id: 1,
        title: '🎯 Halfway There!',
        body: 'You\'ve reached 50% of your daily goal. Keep going!',
      );
      _sentToday.add('progress_50');
    }

    // 75% reached
    if (progress >= 0.75 && !_sentToday.contains('progress_75')) {
      await _showNotification(
        id: 2,
        title: '🔥 Almost There!',
        body: 'Just 25% more to hit your goal. You got this!',
      );
      _sentToday.add('progress_75');
    }

    // 100% goal reached
    if (progress >= 1.0 && !_sentToday.contains('progress_100')) {
      await _showNotification(
        id: 3,
        title: '🏆 Goal Crushed!',
        body:
            'Amazing! You\'ve completed your daily goal of ${_formatNumber(goal)} steps!',
      );
      _sentToday.add('progress_100');
    }

    // === TIME-BASED NOTIFICATIONS ===

    // Midday reminder (12-14h, less than 30% progress)
    if (hour >= 12 &&
        hour <= 14 &&
        progress < 0.3 &&
        !_sentToday.contains('midday')) {
      await _showNotification(
        id: 4,
        title: '⏰ Midday Check-in',
        body:
            'Half the day is gone! You\'re at ${(progress * 100).round()}% of your goal.',
      );
      _sentToday.add('midday');
    }

    // Evening reminder (18-20h, less than 80% progress)
    if (hour >= 18 &&
        hour <= 20 &&
        progress < 0.8 &&
        !_sentToday.contains('evening')) {
      final remaining = goal - todaySteps;
      await _showNotification(
        id: 5,
        title: '🌙 Evening Push',
        body:
            'Just ${_formatNumber(remaining)} steps left to reach your goal tonight!',
      );
      _sentToday.add('evening');
    }

    // === STREAK NOTIFICATIONS ===

    // Don't break the streak (20-21h, streak > 1, goal not reached)
    if (hour >= 20 &&
        hour <= 21 &&
        currentStreak > 1 &&
        progress < 1.0 &&
        !_sentToday.contains('streak_reminder')) {
      await _showNotification(
        id: 6,
        title: '🔥 Protect Your Streak!',
        body:
            'Don\'t lose your $currentStreak-day streak! ${_formatNumber(goal - todaySteps)} steps to go.',
      );
      _sentToday.add('streak_reminder');
    }

    // === MILESTONE NOTIFICATIONS ===

    // First 1,000 steps of the day
    if (todaySteps >= 1000 &&
        _lastKnownSteps < 1000 &&
        !_sentToday.contains('first_1k')) {
      await _showNotification(
        id: 7,
        title: '👟 First 1,000!',
        body: 'Great start! Your first 1,000 steps are done.',
      );
      _sentToday.add('first_1k');
    }

    // New personal best
    if (todaySteps > personalBest &&
        personalBest > 0 &&
        !_sentToday.contains('personal_best')) {
      await _showNotification(
        id: 8,
        title: '🌟 New Personal Best!',
        body:
            'You\'ve beaten your record of ${_formatNumber(personalBest)} steps!',
      );
      _sentToday.add('personal_best');
    }

    _lastKnownSteps = todaySteps;
  }

  /// Schedule inactivity reminder
  Future<void> scheduleInactivityReminder() async {
    // Cancel existing inactivity reminder
    await _notifications.cancel(9);

    // Schedule for 3 hours from now
    final scheduledTime = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(hours: 3));

    await _notifications.zonedSchedule(
      9,
      '🚶 Time to Move!',
      'You haven\'t walked in a while. A short walk can boost your energy!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'step_pulse_reminders',
          'Step Reminders',
          channelDescription: 'Motivational step reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel inactivity reminder (called when steps increase)
  Future<void> cancelInactivityReminder() async {
    await _notifications.cancel(9);
  }

  /// Schedule morning motivation
  Future<void> scheduleMorningMotivation({required int currentStreak}) async {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 8, 0); // 8 AM

    // If it's past 8 AM, schedule for tomorrow
    if (now.hour >= 8) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    String body = currentStreak > 1
        ? 'Day ${currentStreak + 1} of your streak awaits! Let\'s go! 💪'
        : 'A new day, a new opportunity to crush your goals!';

    await _notifications.zonedSchedule(
      10,
      '🌅 Good Morning!',
      body,
      tzScheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'step_pulse_morning',
          'Morning Motivation',
          channelDescription: 'Daily morning motivation',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'step_pulse_smart',
      'Smart Notifications',
      channelDescription: 'Progress and motivational notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(id, title, body, details);
  }

  /// Show level-up celebration notification
  Future<void> showLevelUpNotification({
    required int newLevel,
    required String levelTitle,
  }) async {
    await _showNotification(
      id: 11,
      title: '🎉 Level Up!',
      body: 'Congratulations! You\'ve reached Level $newLevel: $levelTitle',
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}
