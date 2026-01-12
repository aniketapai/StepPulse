import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'step_provider.dart';
import 'xp_provider.dart';
import 'settings_provider.dart';

/// Provider that bridges step updates to XP updates
/// This watches step changes and triggers live XP updates
final stepXpBridgeProvider = Provider<void>((ref) {
  final stepState = ref.watch(stepProvider);
  final settings = ref.watch(settingsProvider);
  final xpNotifier = ref.read(xpProvider.notifier);

  // When today's steps change, update live XP
  if (stepState.todaySteps > 0 && !stepState.isLoading) {
    xpNotifier.updateLiveXp(
      todaySteps: stepState.todaySteps,
      goal: settings.dailyGoal,
    );
  }

  return;
});
