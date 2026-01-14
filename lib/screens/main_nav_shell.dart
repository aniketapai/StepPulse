import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/step_provider.dart';
import '../providers/history_provider.dart';
import '../services/update_service.dart';
import 'dashboard/dashboard_content.dart';
import 'stats/stats_screen.dart';
import 'progress/progress_content.dart';
import 'profile/profile_screen.dart';

/// Main navigation shell - optimized for instant tab switching.
///
/// **Why IndexedStack?**
/// - All screens are pre-built and stay mounted
/// - Tab switch = just changing visibility (no rebuild)
/// - Truly instant transitions with zero jank
///
/// **Note:** In DEBUG mode, Flutter has intentional slowdowns for hot reload.
/// Run `flutter run --release` to see true performance.
class MainNavShell extends ConsumerStatefulWidget {
  const MainNavShell({super.key});

  @override
  ConsumerState<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends ConsumerState<MainNavShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Register to listen for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    // Check for day change immediately on mount
    _checkForDayChange();

    // Check for app updates from GitHub
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes from background, check if day has changed
    if (state == AppLifecycleState.resumed) {
      _checkForDayChange();
    }
  }

  /// Check if the day has changed since last check
  Future<void> _checkForDayChange() async {
    final dayChanged = await ref
        .read(stepProvider.notifier)
        .checkForDayChange();
    if (dayChanged) {
      // Refresh history to show updated data
      ref.read(historyProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force status bar color to match mint background
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppTheme.mintBackground,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.mintBackground,
        // Use AnimatedSwitcher for smooth fade transitions between tabs
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutExpo,
          switchOutCurve: Curves.easeInExpo,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _buildCurrentScreen(),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  /// Build current screen with unique key for AnimatedSwitcher
  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const DashboardContent(key: ValueKey('dashboard'));
      case 1:
        return const StatsContent(key: ValueKey('stats'));
      case 2:
        return const ProgressContent(key: ValueKey('progress'));
      case 3:
        return const ProfileContent(key: ValueKey('profile'));
      default:
        return const DashboardContent(key: ValueKey('dashboard'));
    }
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentBlack,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isSelected: _currentIndex == 0,
            onTap: () => _switchTab(0),
          ),
          _NavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Stats',
            isSelected: _currentIndex == 1,
            onTap: () => _switchTab(1),
          ),
          _NavItem(
            icon: Icons.show_chart_rounded,
            label: 'Progress',
            isSelected: _currentIndex == 2,
            onTap: () => _switchTab(2),
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Profile',
            isSelected: _currentIndex == 3,
            onTap: () => _switchTab(3),
          ),
        ],
      ),
    );
  }

  void _switchTab(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }
}

/// Animated nav item - extracted to prevent parent rebuilds
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: isSelected ? 1 : 0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutExpo,
        builder: (context, value, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15 * value),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1.0 + (0.1 * value),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6 + (0.4 * value)),
                    fontSize: 11,
                    fontWeight: value > 0.5 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
