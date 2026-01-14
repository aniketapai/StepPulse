import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/xp_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_manager.dart';
import '../../models/xp_data.dart';

/// Enhanced Profile screen content (for use in nav shell)
class ProfileContent extends ConsumerStatefulWidget {
  const ProfileContent({super.key});

  @override
  ConsumerState<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<ProfileContent>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  bool _isEditingName = false;

  // Animation controllers
  late AnimationController _animController;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      _nameController.text = storage.profileName;
    });

    // Set up staggered animations for 5 elements
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimations = List.generate(5, (index) {
      final start = index * 0.12;
      final end = start + 0.4;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    _slideAnimations = List.generate(5, (index) {
      final start = index * 0.12;
      final end = start + 0.4;
      return Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedChild(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(position: _slideAnimations[index], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final xp = ref.watch(xpProvider);
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);
    final isGoogleUser = ref.read(authServiceProvider).isGoogleUser;

    // Parse member since date for display
    final memberSince = storage.memberSince;
    final memberSinceDate = DateTime.tryParse(memberSince) ?? DateTime.now();
    final memberDays = DateTime.now().difference(memberSinceDate).inDays + 1;

    return SafeArea(
      child: SingleChildScrollView(
        // ClampingScrollPhysics for smoother, more controlled scrolling
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Title with Settings icon - animated
            _buildAnimatedChild(
              0,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 44), // Balance for the settings icon
                  Expanded(
                    child: Text(
                      'Profile',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/settings'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        size: 20,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Profile Card with Avatar and Name - animated
            _buildAnimatedChild(
              1,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: isGoogleUser ? null : _pickProfilePhoto,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlack,
                              shape: BoxShape.circle,
                              image: storage.profilePhotoPath != null
                                  ? DecorationImage(
                                      image: FileImage(
                                        File(storage.profilePhotoPath!),
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: storage.profilePhotoPath == null
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 50,
                                  )
                                : null,
                          ),
                          if (!isGoogleUser)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlack,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Editable Name
                    _isEditingName
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 150,
                                child: TextField(
                                  controller: _nameController,
                                  textAlign: TextAlign.center,
                                  autofocus: true,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppTheme.textPrimary,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (_) => _saveName(),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.check_rounded),
                                color: AppTheme.accentBlack,
                                onPressed: _saveName,
                              ),
                            ],
                          )
                        : GestureDetector(
                            onTap: isGoogleUser
                                ? null
                                : () => setState(() => _isEditingName = true),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  storage.profileName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (!isGoogleUser) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                    const SizedBox(height: 4),
                    Text(
                      'Member for $memberDays days',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // XP & Level Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  // Level badge with info icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlack,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Level ${xp.level} • ${xp.levelTitle}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showXpInfoPopup(context),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // XP display
                  Text(
                    '${xp.totalXp}',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Total XP Earned',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Level progress bar
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 10,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              Container(
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: xp.levelProgress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentBlack,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${xp.xpForNextLevel - xp.totalXp} XP to Level ${xp.level + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Streaks Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecoration,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: AppTheme.accentBlack,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${xp.currentStreak}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Current\nStreak',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: AppTheme.mintBackground,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: AppTheme.accentBlack,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${xp.longestStreak}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Longest\nStreak',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: AppTheme.mintBackground,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: AppTheme.accentBlack,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${xp.totalDaysActive}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Days\nActive',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // BMI Card
            _buildBmiCard(context, storage),

            const SizedBox(height: 120), // Space for nav bar
          ],
        ),
      ),
    );
  }

  void _showXpInfoPopup(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: Colors.amber.shade600,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'XP System',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // XP Earning - horizontal text format
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.mintBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '👣 100 steps = +1 XP   🎯 Goal = +50 XP   🔥 Streak = +10 XP/day',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // Level Ranks title
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Levels',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Compact level grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(kLevelTitles.length, (index) {
                final xpRequired = index < kLevelThresholds.length
                    ? kLevelThresholds[index]
                    : 18000;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}. ${kLevelTitles[index]} · ${_formatNumber(xpRequired)} XP',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}k';
    }
    return number.toString();
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 500,
      maxHeight: 500,
      imageQuality: 80,
    );

    if (image != null) {
      final storage = ref.read(storageServiceProvider);
      await storage.setProfilePhotoPath(image.path);

      // Sync change to cloud (debounced)
      ref.read(syncManagerProvider).onSettingsChanged();

      setState(() {});
    }
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final storage = ref.read(storageServiceProvider);
      storage.setProfileName(name);

      // Sync change to cloud (debounced)
      ref.read(syncManagerProvider).onSettingsChanged();
    }
    setState(() => _isEditingName = false);
  }

  Widget _buildBmiCard(BuildContext context, storage) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final heightCm = settings.heightCm;
    final weightKg = settings.weightKg;

    // Calculate BMI using settings state (reactive)
    final bmi = settings.bmi;

    // Get BMI category
    String category;
    Color categoryColor;
    if (bmi < 18.5) {
      category = 'Underweight';
      categoryColor = Colors.blue;
    } else if (bmi < 25) {
      category = 'Normal';
      categoryColor = Colors.green;
    } else if (bmi < 30) {
      category = 'Overweight';
      categoryColor = Colors.orange;
    } else {
      category = 'Obese';
      categoryColor = Colors.red;
    }

    // BMI position on scale (15-40 range mapped to 0-1)
    final bmiPosition = ((bmi - 15) / 25).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.mintBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.monitor_weight_rounded,
                  color: AppTheme.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Body Mass Index',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // BMI Value and Category
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                bmi.toStringAsFixed(1),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: categoryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // BMI Scale
          Stack(
            children: [
              // Background gradient bar
              Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.blue,
                      Colors.green,
                      Colors.yellow,
                      Colors.orange,
                      Colors.red,
                    ],
                  ),
                ),
              ),
              // Position indicator
              Positioned(
                left:
                    bmiPosition * (MediaQuery.of(context).size.width - 80) - 8,
                top: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: categoryColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Scale labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '15',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '18.5',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '25',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '30',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '40',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Height/Weight info
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.mintBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.height_rounded,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.useMetric
                            ? '$heightCm cm'
                            : '${(heightCm / 2.54).toStringAsFixed(1)} in',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.mintBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.monitor_weight_outlined,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.useMetric
                            ? '$weightKg kg'
                            : '${(weightKg * 2.205).toStringAsFixed(1)} lbs',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
