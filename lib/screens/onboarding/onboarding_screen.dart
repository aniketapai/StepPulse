import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/step_provider.dart';
import '../../providers/history_provider.dart';
import '../../services/foreground_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firestore_provider.dart';

/// Onboarding screen with multiple steps
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  bool _startAtSignIn = false; // For returning logged-out users

  // Animation controllers
  late AnimationController _contentAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Collected data
  int _selectedGoal = 8000;
  int _heightCm = 170;
  int _weightKg = 70;
  bool _useMetric = true;
  bool _permissionGranted = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();

    // Check if user is returning after logout (onboarding complete but logged out)
    // If so, start at Sign-In page instead of Welcome
    final storage = ref.read(storageServiceProvider);
    _startAtSignIn = storage.isOnboardingComplete;
    final initialPage = _startAtSignIn ? 4 : 0; // 4 = Sign-In page
    _currentPage = initialPage;
    _pageController = PageController(initialPage: initialPage);

    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    // Use easeIn for slow-then-fast effect - feels more premium
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Curves.easeIn,
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentAnimationController,
            curve: Curves.easeInQuad,
          ),
        );
    // Start initial animation
    _contentAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mintBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Animated header with back button - HIDDEN for simplicity in this flow
            /*
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Animated back button
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.5, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _currentPage > 0
                        ? IconButton(
                            key: const ValueKey('back'),
                            onPressed: _previousPage,
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppTheme.textPrimary,
                          )
                        : const SizedBox(key: ValueKey('empty'), width: 48),
                  ),

                  // Animated progress indicators
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(2, (index) { // Reduced to 2 steps primarily
                        final isActive = index <= _currentPage;
                        final isCurrent = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          width: isCurrent ? 40 : 24,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.accentBlack
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            */
            const SizedBox(height: 20),

            // Pages with animated content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  // Order: Welcome → Permission → Goal → Body → Sign-In
                  _buildAnimatedPage(_buildWelcomePage()), // Page 0
                  _buildAnimatedPage(_buildPermissionPage()), // Page 1
                  _buildAnimatedPage(_buildGoalPage()), // Page 2
                  _buildAnimatedPage(_buildBodyMeasurementsPage()), // Page 3
                  _buildAnimatedPage(_buildSignInPage()), // Page 4 (last)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wrap page content with fade and slide animations
  Widget _buildAnimatedPage(Widget child) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: child),
    );
  }

  // Page 0: Welcome Page
  Widget _buildWelcomePage() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.accentBlack,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to StepPulse',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Track your steps, earn XP, and achieve your fitness goals with a fun, gamified experience!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          _buildNextButton('Get Started', _nextPage),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Page 2: Goal Selection with Slider
  Widget _buildGoalPage() {
    final theme = Theme.of(context);
    const minGoal = 2000;
    const maxGoal = 20000;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 40),

          Icon(Icons.flag_rounded, size: 60, color: AppTheme.accentBlack),
          const SizedBox(height: 24),

          Text(
            'Set Your Daily Goal',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Slide to choose your daily step target',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 48),

          // Large goal display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _selectedGoal.toString().replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (m) => '${m[1]},',
                  ),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'steps per day',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Slider
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 10,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 14,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 28,
                    ),
                    activeTrackColor: AppTheme.accentBlack,
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbColor: AppTheme.accentBlack,
                    overlayColor: AppTheme.accentBlack.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _selectedGoal.toDouble(),
                    min: minGoal.toDouble(),
                    max: maxGoal.toDouble(),
                    divisions: (maxGoal - minGoal) ~/ 500,
                    onChanged: (value) {
                      setState(() {
                        _selectedGoal = value.round();
                      });
                    },
                  ),
                ),
                // Min/Max labels
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${minGoal ~/ 1000}K',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${maxGoal ~/ 1000}K',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          _buildNextButton('Continue', () {
            ref.read(settingsProvider.notifier).setDailyGoal(_selectedGoal);
            _nextPage();
          }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Page 3: Body Measurements
  Widget _buildBodyMeasurementsPage() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 40),

          Icon(
            Icons.accessibility_new_rounded,
            size: 60,
            color: AppTheme.accentBlack,
          ),
          const SizedBox(height: 24),

          Text(
            'Body Measurements',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Used to calculate calories burned more accurately',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 32),

          // Metric/Imperial toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildUnitToggle('Metric', true),
                _buildUnitToggle('Imperial', false),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Height
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Height',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _useMetric
                          ? '$_heightCm cm'
                          : '${(_heightCm / 2.54).toStringAsFixed(1)} in',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.accentBlack,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    activeTrackColor: AppTheme.accentBlack,
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbColor: AppTheme.accentBlack,
                  ),
                  child: Slider(
                    value: _heightCm.toDouble(),
                    min: 100,
                    max: 250,
                    divisions: 150,
                    onChanged: (value) =>
                        setState(() => _heightCm = value.round()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Weight
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Weight',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _useMetric
                          ? '$_weightKg kg'
                          : '${(_weightKg * 2.205).toStringAsFixed(1)} lbs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.accentBlack,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    activeTrackColor: AppTheme.accentBlack,
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbColor: AppTheme.accentBlack,
                  ),
                  child: Slider(
                    value: _weightKg.toDouble(),
                    min: 30,
                    max: 200,
                    divisions: 170,
                    onChanged: (value) =>
                        setState(() => _weightKg = value.round()),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          _buildNextButton('Continue', () {
            // Save measurements
            final storage = ref.read(storageServiceProvider);
            storage.setHeightCm(_heightCm);
            storage.setWeightKg(_weightKg);
            ref.read(settingsProvider.notifier).setUseMetric(_useMetric);
            _nextPage();
          }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildUnitToggle(String label, bool isMetric) {
    final isSelected = _useMetric == isMetric;
    return GestureDetector(
      onTap: () => setState(() => _useMetric = isMetric),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlack : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Page 4: Permission
  Widget _buildPermissionPage() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 40),

          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _permissionGranted ? Colors.green : AppTheme.accentBlack,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _permissionGranted ? Icons.check_rounded : Icons.sensors_rounded,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Enable Step Tracking',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We need access to your device\'s motion sensors to count your steps accurately.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 40),

          // Permission items
          _buildPermissionItem(
            icon: Icons.directions_walk_rounded,
            title: 'Activity Recognition',
            description: 'Count your steps using motion sensors',
          ),
          const SizedBox(height: 12),
          _buildPermissionItem(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            description: 'Show your progress in the status bar',
          ),

          const Spacer(),

          if (!_permissionGranted)
            _buildNextButton('Allow Permissions', _requestPermissions)
          else
            _buildNextButton('Continue', _nextPage),

          if (!_permissionGranted)
            TextButton(
              onPressed: _nextPage,
              child: Text(
                'Skip for now',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.mintBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.accentBlack, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Page 4: Sign In
  Widget _buildSignInPage() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.login_rounded,
                  size: 40,
                  color: theme.iconTheme.color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Sign In',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in with Google to sync your progress and set up your profile automatically.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const Spacer(),

          // Google Sign In Button
          InkWell(
            onTap: _handleGoogleSignIn,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.transparent : Colors.grey.shade300,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSigningIn)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  else
                    // We can use an icon or asset here. For now using Icon.
                    // Ideally use the official Google G logo asset.
                    Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png',
                      height: 24,
                      width: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 32,
                        color: Colors.blue,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Text(
                    _isSigningIn ? 'Signing in...' : 'Sign in with Google',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
    });

    try {
      print('Starting Google Sign-In...');
      final credential = await ref.read(authServiceProvider).signInWithGoogle();

      if (credential != null && credential.user != null) {
        print('Sign-In successful. User: ${credential.user?.email}');
        final user = credential.user!;

        // Save user data
        final storage = ref.read(storageServiceProvider);
        if (user.displayName != null) {
          storage.setProfileName(user.displayName!);
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed in successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        print('Syncing cloud data...');
        // Sync with Firestore - this may update local onboarding status
        final firestore = ref.read(firestoreServiceProvider);
        await firestore.syncUserData();

        // IMPORTANT: Refresh history provider so synced data shows in UI
        ref.read(historyProvider.notifier).refresh();

        // Refresh local state if needed (e.g. if profile name changed)
        setState(() {});

        print('Checking onboarding status...');

        // Check if this is a RETURNING user (onboarding was already completed)
        // The storage value may have been updated by cloud sync
        final isReturningUser = storage.isOnboardingComplete;

        if (mounted) {
          if (isReturningUser) {
            // Returning user - go straight to dashboard
            print('Returning user detected, going to dashboard...');
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else {
            // New user - continue with onboarding (permission page)
            print('New user, continuing onboarding...');
            _nextPage();
          }
        }
      } else {
        print('Sign-In cancelled or returned null credential.');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sign in cancelled')));
        }
      }
    } catch (e) {
      print('Sign-In error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Widget _buildNextButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentBlack,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _nextPage() {
    // Total pages: 0=Welcome, 1=Permission, 2=Goal, 3=Body, 4=Sign-In
    const totalPages = 5;

    if (_currentPage < totalPages - 1) {
      // Not on last page - continue to next page
      _contentAnimationController.reset();

      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutExpo,
      );

      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _contentAnimationController.forward();
        }
      });
    } else {
      // On last page (Sign-In) and user clicked skip - complete onboarding
      _completeOnboarding();
    }
  }

  /// Complete onboarding and navigate to dashboard
  void _completeOnboarding() {
    final storage = ref.read(storageServiceProvider);
    storage.setOnboardingComplete(true);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<void> _requestPermissions() async {
    // Request activity recognition
    final activityStatus = await Permission.activityRecognition.request();

    // Request notifications (Android 13+)
    await FlutterForegroundTask.requestNotificationPermission();

    if (activityStatus.isGranted) {
      setState(() => _permissionGranted = true);
      ref.read(stepProvider.notifier).setPermissionStatus(true);

      // Start foreground service
      await ForegroundStepService().start();
    }

    // Auto-advance after permission
    await Future.delayed(const Duration(milliseconds: 500));
    _nextPage();
  }
}
