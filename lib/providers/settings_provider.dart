import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../services/storage_service.dart';

/// Dashboard theme options
enum DashboardTheme { classic, modern }

/// Activity level options for TDEE calculation
enum ActivityLevel {
  sedentary, // Little or no exercise
  light, // 1-3 days/week
  moderate, // 3-5 days/week
  active, // 6-7 days/week
  veryActive, // Intense exercise daily
}

extension ActivityLevelExtension on ActivityLevel {
  String get label {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.light:
        return 'Light (1-3 days/week)';
      case ActivityLevel.moderate:
        return 'Moderate (3-5 days/week)';
      case ActivityLevel.active:
        return 'Active (6-7 days/week)';
      case ActivityLevel.veryActive:
        return 'Very Active (intense daily)';
    }
  }

  double get multiplier {
    switch (this) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.veryActive:
        return 1.9;
    }
  }
}

/// Settings state class
class SettingsState {
  final int dailyGoal;
  final bool useMetric;
  final int heightCm;
  final int weightKg;
  final int age;
  final String gender; // 'male' or 'female'
  final ActivityLevel activityLevel;
  final DashboardTheme dashboardTheme;

  const SettingsState({
    this.dailyGoal = kDefaultDailyGoal,
    this.useMetric = true,
    this.heightCm = 170,
    this.weightKg = 70,
    this.age = 25,
    this.gender = 'male',
    this.activityLevel = ActivityLevel.moderate,
    this.dashboardTheme = DashboardTheme.classic,
  });

  SettingsState copyWith({
    int? dailyGoal,
    bool? useMetric,
    int? heightCm,
    int? weightKg,
    int? age,
    String? gender,
    ActivityLevel? activityLevel,
    DashboardTheme? dashboardTheme,
  }) {
    return SettingsState(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      useMetric: useMetric ?? this.useMetric,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      dashboardTheme: dashboardTheme ?? this.dashboardTheme,
    );
  }

  /// Calculate BMI
  double get bmi {
    final heightM = heightCm / 100.0;
    return heightM > 0 ? weightKg / (heightM * heightM) : 0.0;
  }

  /// Calculate BMR using Mifflin-St Jeor equation
  double get bmr {
    if (gender == 'male') {
      return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    } else {
      return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
    }
  }

  /// Calculate TDEE (Total Daily Energy Expenditure)
  double get tdee => bmr * activityLevel.multiplier;
}

/// Settings notifier for managing app settings
class SettingsNotifier extends StateNotifier<SettingsState> {
  final StorageService _storage;

  SettingsNotifier(this._storage) : super(const SettingsState()) {
    _loadSettings();
  }

  /// Load settings from storage
  void _loadSettings() {
    state = SettingsState(
      dailyGoal: _storage.dailyGoal,
      useMetric: _storage.useMetric,
      heightCm: _storage.heightCm,
      weightKg: _storage.weightKg,
      age: _storage.age,
      gender: _storage.gender,
      activityLevel: ActivityLevel.values[_storage.activityLevel.clamp(0, 4)],
      dashboardTheme: DashboardTheme.values[_storage.dashboardTheme],
    );
  }

  /// Update daily step goal
  Future<void> setDailyGoal(int goal) async {
    final clampedGoal = goal.clamp(kMinGoal, kMaxGoal);
    await _storage.setDailyGoal(clampedGoal);
    state = state.copyWith(dailyGoal: clampedGoal);
  }

  /// Toggle unit system (metric/imperial)
  Future<void> setUseMetric(bool value) async {
    await _storage.setUseMetric(value);
    state = state.copyWith(useMetric: value);
  }

  /// Update height in cm
  Future<void> setHeightCm(int height) async {
    await _storage.setHeightCm(height);
    state = state.copyWith(heightCm: height);
  }

  /// Update weight in kg
  Future<void> setWeightKg(int weight) async {
    await _storage.setWeightKg(weight);
    state = state.copyWith(weightKg: weight);
  }

  /// Update age
  Future<void> setAge(int age) async {
    await _storage.setAge(age);
    state = state.copyWith(age: age);
  }

  /// Update gender
  Future<void> setGender(String gender) async {
    await _storage.setGender(gender);
    state = state.copyWith(gender: gender);
  }

  /// Update activity level
  Future<void> setActivityLevel(ActivityLevel level) async {
    await _storage.setActivityLevel(level.index);
    state = state.copyWith(activityLevel: level);
  }

  /// Update dashboard theme
  Future<void> setDashboardTheme(DashboardTheme theme) async {
    await _storage.setDashboardTheme(theme.index);
    state = state.copyWith(dashboardTheme: theme);
  }

  /// Reset settings to defaults
  Future<void> resetSettings() async {
    await _storage.setDailyGoal(kDefaultDailyGoal);
    await _storage.setUseMetric(true);
    await _storage.setDashboardTheme(0);
    state = const SettingsState();
  }
}

/// Provider for storage service
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Provider for settings
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final storage = ref.watch(storageServiceProvider);
    return SettingsNotifier(storage);
  },
);
