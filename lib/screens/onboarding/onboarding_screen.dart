import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/step_provider.dart';
import '../../services/foreground_service.dart';

/// Onboarding screen with multiple steps
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Animation controllers
  late AnimationController _contentAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Collected data
  int _selectedGoal = 8000;
  String _userName = '';
  String? _profilePhotoPath;
  bool _permissionGranted = false;

  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    _nameController.dispose();
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
            // Animated header with back button
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
                      children: List.generate(4, (index) {
                        final isActive = index <= _currentPage;
                        final isCurrent = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          width: isCurrent ? 48 : 32,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
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

            // Pages with animated content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildAnimatedPage(_buildWelcomePage()),
                  _buildAnimatedPage(_buildGoalPage()),
                  _buildAnimatedPage(_buildPermissionPage()),
                  _buildAnimatedPage(_buildProfilePage()),
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

  // Page 1: Welcome
  Widget _buildWelcomePage() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.accentBlack,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 40),

          Text(
            'Welcome to\nStepPulse',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Track your steps, earn XP, and\nachieve your fitness goals',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const Spacer(),

          _buildNextButton('Get Started', () => _nextPage()),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Page 2: Goal Selection
  Widget _buildGoalPage() {
    final theme = Theme.of(context);
    final goals = [5000, 8000, 10000, 12000, 15000];

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
            'How many steps do you want to walk each day?',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 40),

          // Goal options
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: goals.map((goal) {
              final isSelected = _selectedGoal == goal;
              return GestureDetector(
                onTap: () => setState(() => _selectedGoal = goal),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accentBlack : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accentBlack
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    goal.toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]},',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Selected goal display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_walk, color: AppTheme.textSecondary),
                const SizedBox(width: 12),
                Text(
                  '${_selectedGoal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} steps/day',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
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

  // Page 3: Permission
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

  // Page 4: Profile Setup
  Widget _buildProfilePage() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 20),

          Text(
            'Set Up Your Profile',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s personalize your experience',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 32),

          // Profile photo
          GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlack,
                    shape: BoxShape.circle,
                    image: _profilePhotoPath != null
                        ? DecorationImage(
                            image: FileImage(File(_profilePhotoPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profilePhotoPath == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 60,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.mintBackground,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: AppTheme.accentBlack,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'Tap to add photo',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          // Name input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onChanged: (value) => setState(() => _userName = value),
            ),
          ),

          const SizedBox(height: 40),

          _buildNextButton('Finish Setup', _completeOnboarding),

          const SizedBox(height: 8),

          TextButton(
            onPressed: _completeOnboarding,
            child: Text(
              'Skip',
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
    if (_currentPage < 3) {
      // Reset animation to invisible state
      _contentAnimationController.reset();

      // Start page slide first
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );

      // Delay content fade to start after page slide is mostly done
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _contentAnimationController.forward();
        }
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      // Dismiss keyboard to prevent overflow on previous screens
      FocusScope.of(context).unfocus();

      // Reset animation to invisible state
      _contentAnimationController.reset();

      // Start page slide first
      _pageController.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );

      // Delay content fade to start after page slide is mostly done
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _contentAnimationController.forward();
        }
      });
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

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() => _profilePhotoPath = image.path);
    }
  }

  Future<void> _completeOnboarding() async {
    final storage = ref.read(storageServiceProvider);

    // Save profile data
    if (_userName.trim().isNotEmpty) {
      await storage.setProfileName(_userName.trim());
    }
    if (_profilePhotoPath != null) {
      await storage.setProfilePhotoPath(_profilePhotoPath);
    }

    // Mark onboarding as complete
    await storage.setOnboardingComplete(true);

    // Navigate to main app
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }
}
