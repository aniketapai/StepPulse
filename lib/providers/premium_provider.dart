import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';

/// Provider for premium (ad-free) status
final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return PremiumNotifier(storage);
});

class PremiumNotifier extends StateNotifier<bool> {
  final StorageService _storage;

  PremiumNotifier(this._storage) : super(false) {
    _loadPremiumStatus();
  }

  void _loadPremiumStatus() {
    state = _storage.isPremium;
  }

  /// Toggle premium status (for testing)
  Future<void> setPremium(bool value) async {
    await _storage.setPremium(value);
    state = value;
  }

  /// Simulate purchase (for testing)
  Future<bool> purchasePremium() async {
    // In production, this would integrate with in-app purchases
    // For now, just toggle the premium status
    await setPremium(true);
    return true;
  }

  /// Restore purchase (for testing)
  Future<void> restorePurchase() async {
    // In production, this would check with the app store
    // For now, just load from storage
    _loadPremiumStatus();
  }
}
