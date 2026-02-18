import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../providers/step_provider.dart';
import '../providers/history_provider.dart';
import '../providers/friends_provider.dart';
import '../services/update_service.dart';
import '../services/firestore_service.dart';
import '../widgets/friends_sidebar.dart';
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

    // Ensure user has a friend code (for new and existing users)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFriendCode();
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
    // Watch settings for other preferences
    ref.watch(settingsProvider);
    final showFriendsSidebar = ref.watch(friendsSidebarVisibleProvider);

    // Classic theme background
    final backgroundColor = AppTheme.bg(context);

    // Force status bar color to match background
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: AppTheme.isDark(context)
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: AppTheme.isDark(context)
            ? Brightness.dark
            : Brightness.light,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: backgroundColor,
            // Use IndexedStack to keep all screens mounted - no rebuild on tab switch
            body: IndexedStack(
              index: _currentIndex,
              children: const [
                DashboardContent(key: ValueKey('dashboard')),
                StatsContent(key: ValueKey('stats')),
                ProgressContent(key: ValueKey('progress')),
                ProfileContent(key: ValueKey('profile')),
              ],
            ),
            bottomNavigationBar: SafeArea(
              bottom: true,
              left: false,
              right: false,
              top: false,
              child: _buildBottomNav(),
            ),
          ),
          // Friends sidebar overlay
          if (showFriendsSidebar)
            FriendsSidebar(
              onClose: () =>
                  ref.read(friendsSidebarVisibleProvider.notifier).state =
                      false,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    // Classic theme colors
    final navColor = AppTheme.navBarBg(context);
    final accentColor = AppTheme.accent(context);

    // Get screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive margins - scale with screen width
    // Smaller on narrow screens, larger on wider screens
    final horizontalMargin = (screenWidth * 0.04).clamp(12.0, 20.0);
    final verticalMargin = (screenWidth * 0.035).clamp(14.0, 20.0);

    // Responsive internal padding
    final navHorizontalPadding = (screenWidth * 0.015).clamp(6.0, 10.0);

    return Container(
      margin: EdgeInsets.fromLTRB(
        horizontalMargin,
        verticalMargin,
        horizontalMargin,
        verticalMargin,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: navHorizontalPadding,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: navColor,
        borderRadius: BorderRadius.circular(24),
        border: AppTheme.isDark(context)
            ? null
            : Border.all(color: AppTheme.dividerColor(context)),
        boxShadow: AppTheme.isDark(context)
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
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
          // Center Walk Button - Pops out!
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/walk'),
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.isDark(context)
                    ? Colors.white
                    : AppTheme.bgLight,
                shape: BoxShape.circle,
                border: Border.all(color: accentColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.directions_walk_rounded,
                color: accentColor,
                size: 28,
              ),
            ),
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

  /// Ensure the current user has a friend code
  Future<void> _ensureFriendCode() async {
    try {
      final friendsNotifier = ref.read(friendsProvider.notifier);
      await friendsNotifier.loadFriendCode();

      // If no friend code, assign one
      final state = ref.read(friendsProvider);
      if (state.friendCode == null || state.friendCode!.isEmpty) {
        final storage = ref.read(storageServiceProvider);
        final firestoreService = FirestoreService(storage);
        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          await firestoreService.assignFriendCode(user.uid);
          // Reload friend code after assignment
          await friendsNotifier.loadFriendCode();
        }
      }
    } catch (e) {
      print('⚠️ Error ensuring friend code: $e');
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
              color: AppTheme.isDark(context)
                  ? Colors.white.withValues(alpha: 0.15 * value)
                  : AppTheme.accentGreen.withValues(alpha: 0.12 * value),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1.0 + (0.1 * value),
                  child: Icon(
                    icon,
                    color: AppTheme.isDark(context)
                        ? Colors.white
                        : AppTheme.textDark,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.isDark(context)
                        ? Colors.white.withValues(alpha: 0.6 + (0.4 * value))
                        : AppTheme.textDark.withValues(
                            alpha: 0.5 + (0.5 * value),
                          ),
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
