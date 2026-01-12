import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/step_data.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';

/// History notifier for step history management
class HistoryNotifier extends StateNotifier<List<StepData>> {
  final StorageService _storage;

  HistoryNotifier(this._storage) : super([]) {
    loadHistory();
  }

  /// Load step history from storage
  void loadHistory({int days = 30}) {
    state = _storage.getHistory(days: days);
  }

  /// Clear all history
  Future<void> clearHistory() async {
    await _storage.clearHistory();
    state = [];
  }

  /// Refresh history data
  void refresh() {
    loadHistory();
  }
}

/// Provider for step history
final historyProvider = StateNotifierProvider<HistoryNotifier, List<StepData>>((
  ref,
) {
  final storage = ref.watch(storageServiceProvider);
  return HistoryNotifier(storage);
});
