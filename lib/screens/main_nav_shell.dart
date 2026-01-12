import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
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

class _MainNavShellState extends ConsumerState<MainNavShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mintBackground,
      // IndexedStack = instant switching, all screens stay mounted
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          DashboardContent(),
          StatsContent(),
          ProgressContent(),
          ProfileContent(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
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
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
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
