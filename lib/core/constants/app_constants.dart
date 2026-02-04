/// App constants for StepPulse fitness tracker
library;

/// Default daily step goal
const int kDefaultDailyGoal = 8000;

/// Minimum step goal
const int kMinGoal = 2000;

/// Maximum step goal
const int kMaxGoal = 100000;

/// Distance per step in kilometers (average stride length)
const double kDistancePerStepKm = 0.0008;

/// Distance per step in miles
const double kDistancePerStepMiles = 0.0005;

/// Calories burned per step (simple estimate)
const double kCaloriesPerStep = 0.04;

/// Hive box names
const String kSettingsBox = 'settings_box';
const String kHistoryBox = 'history_box';

/// Settings keys
const String kDailyGoalKey = 'daily_goal';
const String kUseMetricKey = 'use_metric';
const String kBaselineStepsKey = 'baseline_steps';
const String kCurrentDateKey = 'current_date';
const String kLastRawStepsKey = 'last_raw_steps';
