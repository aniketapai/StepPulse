import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/redeem_code_service.dart';
import 'settings_provider.dart';

/// Provider for the RedeemCodeService
final redeemCodeServiceProvider = Provider<RedeemCodeService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RedeemCodeService(storage);
});
