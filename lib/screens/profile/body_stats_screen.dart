import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

/// Body Stats screen with BMI, TDEE calculator, and weight tracking
class BodyStatsScreen extends ConsumerStatefulWidget {
  const BodyStatsScreen({super.key});

  @override
  ConsumerState<BodyStatsScreen> createState() => _BodyStatsScreenState();
}

class _BodyStatsScreenState extends ConsumerState<BodyStatsScreen> {
  // Chart time range
  String _selectedRange = '1M';
  // Weight history for reactive chart updates
  List<Map<String, dynamic>> _weightHistory = [];
  // Selected point index for tooltip display
  int? _selectedPointIndex;

  @override
  void initState() {
    super.initState();
    _loadWeightHistory();
  }

  void _loadWeightHistory() {
    final storage = ref.read(storageServiceProvider);
    setState(() {
      _weightHistory = storage.getWeightHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.mintBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.mintBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppTheme.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Body Stats',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Current Stats Card
            _buildCurrentStatsCard(settings, theme),

            const SizedBox(height: 20),

            // BMI Card
            _buildBmiCard(settings, theme),

            const SizedBox(height: 20),

            // TDEE Calculator Card
            _buildTdeeCard(settings, theme),

            const SizedBox(height: 20),

            // Weight Progress Chart
            _buildWeightChartCard(theme),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatsCard(SettingsState settings, ThemeData theme) {
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
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.accentBlack,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Current Stats',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats Row
          Row(
            children: [
              // Weight
              Expanded(
                child: GestureDetector(
                  onTap: () => _showUpdateWeightDialog(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.mintBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.monitor_weight_outlined,
                          color: AppTheme.accentBlack,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          settings.useMetric
                              ? '${settings.weightKg}'
                              : '${(settings.weightKg * 2.205).round()}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          settings.useMetric ? 'kg' : 'lbs',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlack.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Tap to update',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.accentBlack,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Height
              Expanded(
                child: GestureDetector(
                  onTap: () => _showUpdateHeightDialog(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.mintBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.height_rounded,
                          color: AppTheme.accentBlack,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          settings.useMetric
                              ? '${settings.heightCm}'
                              : (settings.heightCm / 2.54).toStringAsFixed(1),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          settings.useMetric ? 'cm' : 'in',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlack.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Tap to update',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.accentBlack,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Age
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.mintBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cake_outlined,
                        color: AppTheme.accentBlack,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${settings.age}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'years',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const SizedBox(height: 18), // Balance spacing
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

  Widget _buildBmiCard(SettingsState settings, ThemeData theme) {
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
                child: const Icon(
                  Icons.speed_rounded,
                  color: AppTheme.accentBlack,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Body Mass Index',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
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
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
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
                  Positioned(
                    left: bmiPosition * (constraints.maxWidth - 20),
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
              );
            },
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
        ],
      ),
    );
  }

  Widget _buildTdeeCard(SettingsState settings, ThemeData theme) {
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
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppTheme.accentBlack,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Calorie Needs',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Based on your stats',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gender selector
          Row(
            children: [
              Text(
                'Gender',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              _buildGenderToggle(settings, theme),
            ],
          ),
          const SizedBox(height: 16),

          // Age selector
          Row(
            children: [
              Text(
                'Age',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              _buildAgeSelector(settings, theme),
            ],
          ),
          const SizedBox(height: 16),

          // Activity Level
          Text(
            'Activity Level',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _buildActivityLevelSelector(settings, theme),

          const SizedBox(height: 24),

          // Results
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentBlack,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'BMR',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${settings.bmr.round()}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'cal/day',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'TDEE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${settings.tdee.round()}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'cal/day',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                // Calorie targets
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCalorieTarget(
                      'Lose',
                      (settings.tdee - 500).round(),
                      Colors.blue.shade300,
                      theme,
                    ),
                    _buildCalorieTarget(
                      'Maintain',
                      settings.tdee.round(),
                      Colors.green.shade300,
                      theme,
                    ),
                    _buildCalorieTarget(
                      'Gain',
                      (settings.tdee + 500).round(),
                      Colors.orange.shade300,
                      theme,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieTarget(
    String label,
    int calories,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$calories',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderToggle(SettingsState settings, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mintBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => ref.read(settingsProvider.notifier).setGender('male'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: settings.gender == 'male'
                    ? AppTheme.accentBlack
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.male_rounded,
                    size: 18,
                    color: settings.gender == 'male'
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Male',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: settings.gender == 'male'
                          ? Colors.white
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(settingsProvider.notifier).setGender('female'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: settings.gender == 'female'
                    ? AppTheme.accentBlack
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.female_rounded,
                    size: 18,
                    color: settings.gender == 'female'
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Female',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: settings.gender == 'female'
                          ? Colors.white
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeSelector(SettingsState settings, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mintBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (settings.age > 15) {
                ref.read(settingsProvider.notifier).setAge(settings.age - 1);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.remove_rounded,
                size: 20,
                color: settings.age > 15
                    ? AppTheme.accentBlack
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${settings.age}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (settings.age < 100) {
                ref.read(settingsProvider.notifier).setAge(settings.age + 1);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.add_rounded,
                size: 20,
                color: settings.age < 100
                    ? AppTheme.accentBlack
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLevelSelector(SettingsState settings, ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ActivityLevel.values.map((level) {
        final isSelected = settings.activityLevel == level;
        return GestureDetector(
          onTap: () =>
              ref.read(settingsProvider.notifier).setActivityLevel(level),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentBlack
                  : AppTheme.mintBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              level.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeightChartCard(ThemeData theme) {
    final weightHistory = _weightHistory;

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
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: AppTheme.accentBlack,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight Progress',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${weightHistory.length} entries',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Time range selector
              _buildTimeRangeSelector(theme),
            ],
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 180,
            child: weightHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          size: 48,
                          color: AppTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No weight data yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Update your weight to start tracking',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildWeightChart(weightHistory, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector(ThemeData theme) {
    final ranges = ['1W', '1M', '3M', '1Y'];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mintBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ranges.map((range) {
          final isSelected = _selectedRange == range;
          return GestureDetector(
            onTap: () => setState(() => _selectedRange = range),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accentBlack : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                range,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeightChart(
    List<Map<String, dynamic>> history,
    ThemeData theme,
  ) {
    // Filter data based on selected range
    final now = DateTime.now();
    int daysToShow;
    switch (_selectedRange) {
      case '1W':
        daysToShow = 7;
        break;
      case '1M':
        daysToShow = 30;
        break;
      case '3M':
        daysToShow = 90;
        break;
      case '1Y':
        daysToShow = 365;
        break;
      default:
        daysToShow = 30;
    }

    final cutoffDate = now.subtract(Duration(days: daysToShow));
    final filteredData = history.where((entry) {
      final dateStr = entry['date'] as String;
      final date = DateTime.tryParse(dateStr);
      return date != null && date.isAfter(cutoffDate);
    }).toList();

    if (filteredData.isEmpty) {
      return Center(
        child: Text(
          'No data for this period',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    // Sort by date
    filteredData.sort(
      (a, b) => (a['date'] as String).compareTo(b['date'] as String),
    );

    // Handle single data point case - show weight prominently
    if (filteredData.length == 1) {
      final weight = (filteredData.first['weight'] as num).toDouble();
      final settings = ref.read(settingsProvider);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentBlack.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  settings.useMetric
                      ? weight.toStringAsFixed(1)
                      : (weight * 2.205).toStringAsFixed(1),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.accentBlack,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              settings.useMetric ? 'kg' : 'lbs',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add more entries to see your progress chart',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Get min/max for scaling
    final weights = filteredData
        .map((e) => (e['weight'] as num).toDouble())
        .toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final range = maxWeight - minWeight;
    // If all weights are the same, create artificial range
    final effectiveRange = range > 0 ? range : 2.0;
    final effectiveMin = range > 0 ? minWeight : minWeight - 1;
    final effectiveMax = range > 0 ? maxWeight : maxWeight + 1;
    final padding = effectiveRange * 0.1;

    final settings = ref.read(settingsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Calculate point positions for touch detection
        List<Offset> points = [];
        for (var i = 0; i < filteredData.length; i++) {
          final x = filteredData.length > 1
              ? i / (filteredData.length - 1) * width
              : width / 2;
          final weightRange =
              (effectiveMax + padding) - (effectiveMin - padding);
          final weight = (filteredData[i]['weight'] as num).toDouble();
          final y =
              height -
              ((weight - (effectiveMin - padding)) / weightRange * height);
          points.add(Offset(x, y));
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The chart
            CustomPaint(
              size: Size(width, height),
              painter: _WeightChartPainter(
                data: filteredData,
                minWeight: effectiveMin - padding,
                maxWeight: effectiveMax + padding,
                selectedIndex: _selectedPointIndex,
              ),
            ),
            // Touch detection layer
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (details) {
                  _selectNearestPoint(details.localPosition, points);
                },
                onPanUpdate: (details) {
                  _selectNearestPoint(details.localPosition, points);
                },
                onPanEnd: (_) {
                  setState(() => _selectedPointIndex = null);
                },
                onPanCancel: () {
                  setState(() => _selectedPointIndex = null);
                },
              ),
            ),
            // Vertical indicator line from tooltip to selected point
            if (_selectedPointIndex != null &&
                _selectedPointIndex! < filteredData.length &&
                _selectedPointIndex! < points.length &&
                points[_selectedPointIndex!].dy > 50)
              Positioned(
                left: points[_selectedPointIndex!].dx - 1,
                top: 50, // Start from below tooltip area
                child: Container(
                  width: 2,
                  height: (points[_selectedPointIndex!].dy - 50).clamp(
                    0,
                    double.infinity,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.accentBlack.withValues(alpha: 0.3),
                        AppTheme.accentBlack.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
            // Tooltip overlay - positioned at top of chart, horizontally aligned with point
            if (_selectedPointIndex != null &&
                _selectedPointIndex! < filteredData.length &&
                _selectedPointIndex! < points.length)
              Positioned(
                left: (points[_selectedPointIndex!].dx - 50).clamp(
                  0,
                  width - 100,
                ),
                top: 0, // Always at top of chart area
                child: _buildChartTooltip(
                  filteredData[_selectedPointIndex!],
                  settings.useMetric,
                  theme,
                ),
              ),
          ],
        );
      },
    );
  }

  void _selectNearestPoint(Offset touchPosition, List<Offset> points) {
    if (points.isEmpty) return;

    int nearestIndex = 0;
    double minDistance = double.infinity;

    for (var i = 0; i < points.length; i++) {
      final distance = (points[i] - touchPosition).distance;
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    // Only select if within reasonable distance (80 pixels)
    if (minDistance < 80) {
      setState(() => _selectedPointIndex = nearestIndex);
    }
  }

  Widget _buildChartTooltip(
    Map<String, dynamic> data,
    bool useMetric,
    ThemeData theme,
  ) {
    final weight = (data['weight'] as num).toDouble();
    final dateStr = data['date'] as String;
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();

    // Format date nicely
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final formattedDate = '${months[date.month - 1]} ${date.day}, ${date.year}';

    final displayWeight = useMetric ? weight : weight * 2.205;
    final unit = useMetric ? 'kg' : 'lbs';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accentBlack,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${displayWeight.toStringAsFixed(1)} $unit',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formattedDate,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdateHeightDialog() {
    final settings = ref.read(settingsProvider);
    double height = settings.heightCm.toDouble();
    final controller = TextEditingController(text: height.toStringAsFixed(1));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
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
              const SizedBox(height: 20),

              // Title
              Text(
                'Update Height',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // Height input
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      cursorColor: AppTheme.accentBlack,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,1}'),
                        ),
                      ],
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null && parsed >= 100 && parsed <= 250) {
                          setModalState(() => height = parsed);
                        }
                      },
                    ),
                  ),
                  Text(
                    settings.useMetric ? 'cm' : 'in',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.accentBlack,
                  inactiveTrackColor: AppTheme.mintBackground,
                  thumbColor: AppTheme.accentBlack,
                  overlayColor: AppTheme.accentBlack.withValues(alpha: 0.1),
                ),
                child: Slider(
                  value: height.clamp(100, 250),
                  min: 100,
                  max: 250,
                  onChanged: (value) {
                    setModalState(() {
                      height = value;
                      controller.text = value.toStringAsFixed(1);
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(settingsProvider.notifier)
                        .setHeightCm(height.round());
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Height',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUpdateWeightDialog() {
    final settings = ref.read(settingsProvider);
    final storage = ref.read(storageServiceProvider);
    double weight = settings.weightKg.toDouble();
    DateTime selectedDate = DateTime.now();
    final controller = TextEditingController(text: weight.toStringAsFixed(1));

    String formatDate(DateTime date) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) return 'Today';
      if (dateOnly == today.subtract(const Duration(days: 1)))
        return 'Yesterday';
      return '${date.day}/${date.month}/${date.year}';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
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
              const SizedBox(height: 20),

              // Title
              Text(
                'Log Weight',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Date selector
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppTheme.accentBlack,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: AppTheme.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.mintBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: AppTheme.accentBlack,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatDate(selectedDate),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.accentBlack,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 20,
                        color: AppTheme.accentBlack,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Weight input with slider
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      cursorColor: AppTheme.accentBlack,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,1}'),
                        ),
                      ],
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null && parsed >= 30 && parsed <= 300) {
                          setModalState(() => weight = parsed);
                        }
                      },
                    ),
                  ),
                  Text(
                    settings.useMetric ? 'kg' : 'lbs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.accentBlack,
                  inactiveTrackColor: AppTheme.mintBackground,
                  thumbColor: AppTheme.accentBlack,
                  overlayColor: AppTheme.accentBlack.withValues(alpha: 0.1),
                ),
                child: Slider(
                  value: weight.clamp(30, 200),
                  min: 30,
                  max: 200,
                  onChanged: (value) {
                    setModalState(() {
                      weight = value;
                      controller.text = value.toStringAsFixed(1);
                    });
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final dateStr =
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                    // Only update current weight in settings if it's today
                    if (selectedDate.day == DateTime.now().day &&
                        selectedDate.month == DateTime.now().month &&
                        selectedDate.year == DateTime.now().year) {
                      await ref
                          .read(settingsProvider.notifier)
                          .setWeightKg(weight.round());
                    }
                    // Add to weight history with date
                    await storage.addWeightEntry(weight, date: dateStr);
                    // Refresh the chart
                    _loadWeightHistory();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Weight',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for weight chart with gradient line
class _WeightChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minWeight;
  final double maxWeight;
  final int? selectedIndex;

  _WeightChartPainter({
    required this.data,
    required this.minWeight,
    required this.maxWeight,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final range = maxWeight - minWeight;
    if (range == 0) return;

    // Calculate points
    final points = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = data.length > 1
          ? i / (data.length - 1) * size.width
          : size.width / 2;
      final weight = (data[i]['weight'] as num).toDouble();
      final y = size.height - ((weight - minWeight) / range * size.height);
      points.add(Offset(x, y));
    }

    // Draw gradient fill
    if (points.length > 1) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, size.height);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.accentBlack.withValues(alpha: 0.2),
            AppTheme.accentBlack.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(fillPath, fillPaint);

      // Draw line with gradient
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [AppTheme.mintBackground, AppTheme.accentBlack],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(linePath, linePaint);
    }

    // Draw dots
    for (var i = 0; i < points.length; i++) {
      final isSelected = selectedIndex != null && i == selectedIndex;
      final isLast = i == points.length - 1;

      if (isSelected) {
        // Highlight selected point
        canvas.drawCircle(
          points[i],
          12,
          Paint()..color = AppTheme.accentBlack.withValues(alpha: 0.3),
        );
        canvas.drawCircle(points[i], 7, Paint()..color = AppTheme.accentBlack);
        canvas.drawCircle(points[i], 4, Paint()..color = Colors.white);
      } else if (isLast && selectedIndex == null) {
        // Highlight last point when no selection
        canvas.drawCircle(
          points[i],
          8,
          Paint()..color = AppTheme.accentBlack.withValues(alpha: 0.2),
        );
        canvas.drawCircle(points[i], 5, Paint()..color = AppTheme.accentBlack);
      } else {
        // Regular point
        canvas.drawCircle(points[i], 5, Paint()..color = AppTheme.accentBlack);
        canvas.drawCircle(points[i], 3, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
