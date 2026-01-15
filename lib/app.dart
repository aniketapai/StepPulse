import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'screens/main_nav_shell.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/signin/sign_in_screen.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_manager.dart';

/// Main app widget for StepPulse
class StepPulseApp extends ConsumerStatefulWidget {
  const StepPulseApp({super.key});

  @override
  ConsumerState<StepPulseApp> createState() => _StepPulseAppState();
}

class _StepPulseAppState extends ConsumerState<StepPulseApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Sync data when app goes to background (optimized sync manager)
      ref.read(syncManagerProvider).syncNow(reason: 'app_background');
    }
  }

  @override
  Widget build(BuildContext context) {
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
      onGenerateRoute: (settings) {
        // Use smooth page transitions for all routes
        switch (settings.name) {
          case '/onboarding':
            return AppTheme.smoothPageRoute(
              page: const OnboardingScreen(),
              settings: settings,
            );
          case '/sign-in':
            // Separate sign-in only route for users who logged out
            return AppTheme.smoothPageRoute(
              page: const SignInScreen(),
              settings: settings,
            );
          case '/dashboard':
            return AppTheme.smoothPageRoute(
              page: const MainNavShell(),
              settings: settings,
            );
          case '/settings':
            return AppTheme.smoothPageRoute(
              page: const SettingsScreen(),
              settings: settings,
            );
          default:
            return AppTheme.smoothPageRoute(
              page: const MainNavShell(),
              settings: settings,
            );
        }
      },
    );
  }
}
