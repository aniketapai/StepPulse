import 'dart:async';
import 'dart:io';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for reading step count from Health Connect (Android) for accurate step data
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _isAuthorized = false;
  bool _isAvailable = false;
  int _lastStepCount = 0;
  DateTime? _lastFetchTime;

  /// Check if Health Connect is available and authorized
  bool get isAvailable => _isAvailable;
  bool get isAuthorized => _isAuthorized;
  int get lastStepCount => _lastStepCount;

  /// Initialize Health service - check availability and request permissions
  Future<bool> initialize() async {
    if (!Platform.isAndroid) {
      _isAvailable = false;
      return false;
    }

    try {
      // Configure the health plugin
      await _health.configure();

      // Check if Health Connect is installed
      final result = await _health.getHealthConnectSdkStatus();
      _isAvailable = result == HealthConnectSdkStatus.sdkAvailable;

      if (!_isAvailable) {
        print('Health Connect not available: $result');
        return false;
      }

      return true;
    } catch (e) {
      print('Health service init error: $e');
      _isAvailable = false;
      return false;
    }
  }

  /// Request permission to read step data from Health Connect
  Future<bool> requestAuthorization() async {
    if (!_isAvailable) return false;

    try {
      // First ensure activity recognition permission is granted
      final activityPermission = await Permission.activityRecognition.request();
      if (!activityPermission.isGranted) {
        print('Activity recognition permission not granted');
        return false;
      }

      // Request Health Connect permissions for steps
      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];

      final authorized = await _health.requestAuthorization(
        types,
        permissions: permissions,
      );

      _isAuthorized = authorized;
      return authorized;
    } catch (e) {
      print('Health authorization error: $e');
      _isAuthorized = false;
      return false;
    }
  }

  /// Check if already authorized (without prompting)
  Future<bool> checkAuthorization() async {
    if (!_isAvailable) return false;

    try {
      final types = [HealthDataType.STEPS];
      final hasPermissions = await _health.hasPermissions(types);
      _isAuthorized = hasPermissions ?? false;
      return _isAuthorized;
    } catch (e) {
      print('Health check authorization error: $e');
      return false;
    }
  }

  /// Get today's step count from Health Connect
  Future<int?> getTodaySteps() async {
    if (!_isAvailable || !_isAuthorized) {
      return null;
    }

    // Throttle requests - don't fetch more than once per 10 seconds
    if (_lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inSeconds < 10) {
      return _lastStepCount;
    }

    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Get total steps for today from Health Connect
      final steps = await _health.getTotalStepsInInterval(midnight, now);

      if (steps != null) {
        _lastStepCount = steps;
        _lastFetchTime = DateTime.now();
        return steps;
      }
      return null;
    } catch (e) {
      print('Error fetching steps from Health Connect: $e');
      return null;
    }
  }

  /// Force refresh step count (ignores throttle)
  Future<int?> forceRefreshSteps() async {
    _lastFetchTime = null;
    return getTodaySteps();
  }
}
