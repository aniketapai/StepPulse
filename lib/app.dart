import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_nav_shell.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'providers/settings_provider.dart';

/// Main app widget for StepPulse
class StepPulseApp extends ConsumerWidget {
  const StepPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    // Determine initial route based on onboarding status
    final initialRoute = storage.isOnboardingComplete
        ? '/dashboard'
        : '/onboarding';

    return MaterialApp(
      title: 'StepPulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: initialRoute,
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/dashboard': (context) => const MainNavShell(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
