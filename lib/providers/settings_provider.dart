import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../services/storage_service.dart';

/// Dashboard theme options
enum DashboardTheme { classic, modern }

/// Settings state class
class SettingsState {
  final int dailyGoal;
  final bool useMetric;
  final int heightCm;
  final int weightKg;
  final DashboardTheme dashboardTheme;

  const SettingsState({
    this.dailyGoal = kDefaultDailyGoal,
    this.useMetric = true,
    this.heightCm = 170,
    this.weightKg = 70,
    this.dashboardTheme = DashboardTheme.classic,
  });

  SettingsState copyWith({
    int? dailyGoal,
    bool? useMetric,
    int? heightCm,
    int? weightKg,
    DashboardTheme? dashboardTheme,
  }) {
    return SettingsState(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      useMetric: useMetric ?? this.useMetric,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      dashboardTheme: dashboardTheme ?? this.dashboardTheme,
    );
  }

  /// Calculate BMI
  double get bmi {
    final heightM = heightCm / 100.0;
    return heightM > 0 ? weightKg / (heightM * heightM) : 0.0;
  }
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
