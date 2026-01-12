import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../services/storage_service.dart';

/// Settings state class
class SettingsState {
  final int dailyGoal;
  final bool useMetric;

  const SettingsState({
    this.dailyGoal = kDefaultDailyGoal,
    this.useMetric = true,
  });

  SettingsState copyWith({int? dailyGoal, bool? useMetric}) {
    return SettingsState(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      useMetric: useMetric ?? this.useMetric,
    );
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

  /// Reset settings to defaults
  Future<void> resetSettings() async {
    await _storage.setDailyGoal(kDefaultDailyGoal);
    await _storage.setUseMetric(true);
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
