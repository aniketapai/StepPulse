import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_constants.dart';
import '../models/chat_message.dart';
import '../models/step_data.dart';

/// Service for local data persistence using Hive
class StorageService {
  late Box _settingsBox;
  late Box _historyBox;

  /// Initialize Hive and open boxes
  Future<void> init() async {
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox(kSettingsBox);
    _historyBox = await Hive.openBox(kHistoryBox);
  }

  // ============ Settings ============

  /// Get daily step goal (default: 8000)
  int get dailyGoal =>
      _settingsBox.get(kDailyGoalKey, defaultValue: kDefaultDailyGoal) as int;

  /// Set daily step goal
  Future<void> setDailyGoal(int goal) async {
    await _settingsBox.put(kDailyGoalKey, goal);
  }

  /// Get unit preference (true = metric/km, false = imperial/miles)
  bool get useMetric =>
      _settingsBox.get(kUseMetricKey, defaultValue: true) as bool;

  /// Set unit preference
  Future<void> setUseMetric(bool value) async {
    await _settingsBox.put(kUseMetricKey, value);
  }

  /// Get baseline steps for today (sensor value at start of day)
  int get baselineSteps =>
      _settingsBox.get(kBaselineStepsKey, defaultValue: 0) as int;

  /// Set baseline steps
  Future<void> setBaselineSteps(int steps) async {
    await _settingsBox.put(kBaselineStepsKey, steps);
  }

  /// Get the current stored date (YYYY-MM-DD)
  String? get currentDate => _settingsBox.get(kCurrentDateKey) as String?;

  /// Set current date
  Future<void> setCurrentDate(String date) async {
    await _settingsBox.put(kCurrentDateKey, date);
  }

  /// Get last raw steps from sensor
  int get lastRawSteps =>
      _settingsBox.get(kLastRawStepsKey, defaultValue: 0) as int;

  /// Set last raw steps
  Future<void> setLastRawSteps(int steps) async {
    await _settingsBox.put(kLastRawStepsKey, steps);
  }

  // ============ History ============

  /// Save steps for a specific date
  Future<void> saveStepsForDate(String date, int steps) async {
    await _historyBox.put(date, steps);
  }

  /// Get steps for a specific date
  int? getStepsForDate(String date) {
    return _historyBox.get(date) as int?;
  }

  /// Get step history for last N days
  List<StepData> getHistory({int days = 30}) {
    final history = <StepData>[];
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = dateFormat.format(date);
      final steps = _historyBox.get(dateStr) as int?;

      if (steps != null) {
        history.add(StepData(date: dateStr, steps: steps));
      }
    }

    return history;
  }

  /// Clear all history data
  Future<void> clearHistory() async {
    await _historyBox.clear();
  }

  /// Clear all data (settings + history)
  Future<void> clearAllData() async {
    await _settingsBox.clear();
    await _historyBox.clear();
  }

  /// Get today's date string
  static String getTodayDateString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  // ============ XP Data ============

  static const String _xpDataKey = 'xp_data';

  /// Get XP data
  Map<String, dynamic>? getXpData() {
    final data = _settingsBox.get(_xpDataKey);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Save XP data
  Future<void> saveXpData(Map<String, dynamic> data) async {
    await _settingsBox.put(_xpDataKey, data);
  }

  // ============ Live XP Tracking ============

  static const String _lastLiveXpStepsKey = 'last_live_xp_steps';
  static const String _goalBonusAwardedKey = 'goal_bonus_awarded';

  /// Get last step count when live XP was awarded (checkpoint)
  int get lastLiveXpSteps =>
      _settingsBox.get(_lastLiveXpStepsKey, defaultValue: 0) as int;

  /// Set last live XP steps checkpoint
  Future<void> setLastLiveXpSteps(int steps) async {
    await _settingsBox.put(_lastLiveXpStepsKey, steps);
  }

  /// Check if goal bonus was already awarded today
  bool get goalBonusAwarded =>
      _settingsBox.get(_goalBonusAwardedKey, defaultValue: false) as bool;

  /// Set goal bonus awarded status
  Future<void> setGoalBonusAwarded(bool value) async {
    await _settingsBox.put(_goalBonusAwardedKey, value);
  }

  /// Reset live XP tracking for new day (called at midnight)
  Future<void> resetLiveXpTracking() async {
    await _settingsBox.put(_lastLiveXpStepsKey, 0);
    await _settingsBox.put(_goalBonusAwardedKey, false);
  }

  /// Get history as a map of date -> steps for heatmap
  Map<String, int> getHistoryMap({int days = 365}) {
    final history = <String, int>{};
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = dateFormat.format(date);
      final steps = _historyBox.get(dateStr) as int?;

      if (steps != null) {
        history[dateStr] = steps;
      }
    }

    return history;
  }

  // ============ Profile Data ============

  static const String _profileNameKey = 'profile_name';
  static const String _profilePhotoKey = 'profile_photo';
  static const String _memberSinceKey = 'member_since';
  static const String _heightCmKey = 'height_cm';
  static const String _weightKgKey = 'weight_kg';
  static const String _ageKey = 'age';
  static const String _genderKey = 'gender'; // 'male' or 'female'
  static const String _activityLevelKey = 'activity_level'; // 0-4
  static const String _weightHistoryKey = 'weight_history';

  /// Get profile name
  String get profileName =>
      _settingsBox.get(_profileNameKey, defaultValue: 'Walker') as String;

  /// Set profile name
  Future<void> setProfileName(String name) async {
    await _settingsBox.put(_profileNameKey, name);
  }

  /// Get profile photo path (local file path)
  String? get profilePhotoPath => _settingsBox.get(_profilePhotoKey) as String?;

  /// Set profile photo path
  Future<void> setProfilePhotoPath(String? path) async {
    if (path != null) {
      await _settingsBox.put(_profilePhotoKey, path);
    } else {
      await _settingsBox.delete(_profilePhotoKey);
    }
  }

  /// Get member since date
  String get memberSince {
    final saved = _settingsBox.get(_memberSinceKey) as String?;
    if (saved != null) return saved;
    // Set today as default and save
    final today = getTodayDateString();
    _settingsBox.put(_memberSinceKey, today);
    return today;
  }

  /// Get height in cm
  int get heightCm => _settingsBox.get(_heightCmKey, defaultValue: 170) as int;

  /// Set height in cm
  Future<void> setHeightCm(int height) async {
    await _settingsBox.put(_heightCmKey, height);
  }

  /// Get weight in kg
  int get weightKg => _settingsBox.get(_weightKgKey, defaultValue: 70) as int;

  /// Set weight in kg
  Future<void> setWeightKg(int weight) async {
    await _settingsBox.put(_weightKgKey, weight);
  }

  // Age
  int get age => _settingsBox.get(_ageKey, defaultValue: 25) as int;

  /// Set age
  Future<void> setAge(int age) async {
    await _settingsBox.put(_ageKey, age);
  }

  // Gender ('male' or 'female')
  String get gender =>
      _settingsBox.get(_genderKey, defaultValue: 'male') as String;

  /// Set gender
  Future<void> setGender(String gender) async {
    await _settingsBox.put(_genderKey, gender);
  }

  // Activity level (0-4: sedentary, light, moderate, active, very active)
  int get activityLevel =>
      _settingsBox.get(_activityLevelKey, defaultValue: 2) as int;

  /// Set activity level
  Future<void> setActivityLevel(int level) async {
    await _settingsBox.put(_activityLevelKey, level);
  }

  // Weight history - list of {date, weight} maps
  List<Map<String, dynamic>> getWeightHistory() {
    final data = _settingsBox.get(_weightHistoryKey);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  /// Add weight entry to history (optional date for historical entries)
  Future<void> addWeightEntry(double weight, {String? date}) async {
    final history = getWeightHistory();
    final entryDate = date ?? getTodayDateString();

    // Check if there's already an entry for this date
    final existingIndex = history.indexWhere((e) => e['date'] == entryDate);
    if (existingIndex >= 0) {
      // Update existing entry
      history[existingIndex]['weight'] = weight;
    } else {
      // Add new entry
      history.add({'date': entryDate, 'weight': weight});
    }

    // Sort by date
    history.sort(
      (a, b) => (a['date'] as String).compareTo(b['date'] as String),
    );

    // Keep only last 365 entries
    if (history.length > 365) {
      history.removeRange(0, history.length - 365);
    }

    await _settingsBox.put(_weightHistoryKey, history);
  }

  /// Clear weight history
  Future<void> clearWeightHistory() async {
    await _settingsBox.delete(_weightHistoryKey);
  }

  // ============ Dashboard Theme ============

  static const String _dashboardThemeKey = 'dashboard_theme';

  /// Get dashboard theme (0 = classic, 1 = modern)
  int get dashboardTheme =>
      _settingsBox.get(_dashboardThemeKey, defaultValue: 0) as int;

  /// Set dashboard theme
  Future<void> setDashboardTheme(int theme) async {
    await _settingsBox.put(_dashboardThemeKey, theme);
  }

  // ============ Dark Mode ============

  static const String _darkModeKey = 'dark_mode';

  /// Get dark mode setting (0 = system, 1 = light, 2 = dark)
  int get darkMode => _settingsBox.get(_darkModeKey, defaultValue: 0) as int;

  /// Set dark mode setting
  Future<void> setDarkMode(int mode) async {
    await _settingsBox.put(_darkModeKey, mode);
  }

  /// Reset all progress (XP, history, but keep profile & settings)
  Future<void> resetAllProgress() async {
    // Clear history
    await _historyBox.clear();
    // Reset XP data
    await _settingsBox.delete(_xpDataKey);
    // Reset step tracking for today
    await _settingsBox.delete(kBaselineStepsKey);
    await _settingsBox.delete(kCurrentDateKey);
    await _settingsBox.delete(kLastRawStepsKey);
  }

  // ============ Onboarding ============

  static const String _onboardingCompleteKey = 'onboarding_complete';

  /// Check if onboarding is complete
  bool get isOnboardingComplete =>
      _settingsBox.get(_onboardingCompleteKey, defaultValue: false) as bool;

  /// Set onboarding complete
  Future<void> setOnboardingComplete(bool value) async {
    await _settingsBox.put(_onboardingCompleteKey, value);
  }

  // ============ Premium (Ad-Free) ============

  static const String _premiumKey = 'is_premium';

  /// Check if user is premium (ad-free)
  bool get isPremium =>
      _settingsBox.get(_premiumKey, defaultValue: false) as bool;

  /// Set premium status
  Future<void> setPremium(bool value) async {
    await _settingsBox.put(_premiumKey, value);
  }

  // ============ Walk History ============

  static const String _walkHistoryKey = 'walk_history';

  /// Get walk history
  List<dynamic> getWalkHistory() {
    final data = _settingsBox.get(_walkHistoryKey);
    if (data == null) return [];
    return List<dynamic>.from(data as List);
  }

  /// Save walk history
  Future<void> saveWalkHistory(List<dynamic> walks) async {
    // Convert WalkSession objects to maps if they aren't already
    final List<Map<String, dynamic>> walkMaps = walks.map((walk) {
      if (walk is Map<String, dynamic>) {
        return walk;
      }
      // Assume it has a toMap method
      return walk.toMap() as Map<String, dynamic>;
    }).toList();
    await _settingsBox.put(_walkHistoryKey, walkMaps);
  }

  /// Clear walk history
  Future<void> clearWalkHistory() async {
    await _settingsBox.delete(_walkHistoryKey);
  }

  // ============ Recent Location Searches ============

  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  /// Get recent location searches
  List<Map<String, dynamic>> getRecentSearches() {
    final data = _settingsBox.get(_recentSearchesKey);
    if (data == null) return [];
    return List<Map<String, dynamic>>.from(
      (data as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  /// Add a location to recent searches
  Future<void> addRecentSearch({
    required String displayName,
    required String shortName,
    required double latitude,
    required double longitude,
  }) async {
    final searches = getRecentSearches();

    // Remove duplicate if exists
    searches.removeWhere(
      (s) =>
          s['displayName'] == displayName ||
          (s['latitude'] == latitude && s['longitude'] == longitude),
    );

    // Add to beginning
    searches.insert(0, {
      'displayName': displayName,
      'shortName': shortName,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Keep only max items
    if (searches.length > _maxRecentSearches) {
      searches.removeRange(_maxRecentSearches, searches.length);
    }

    await _settingsBox.put(_recentSearchesKey, searches);
  }

  // Weekly Report
  static const String kLastWeeklyReportViewed = 'last_weekly_report_viewed';

  String? get lastWeeklyReportViewed =>
      _settingsBox.get(kLastWeeklyReportViewed);

  Future<void> setLastWeeklyReportViewed(String dateIso) async {
    await _settingsBox.put(kLastWeeklyReportViewed, dateIso);
  }

  /// Clear recent searches
  Future<void> clearRecentSearches() async {
    await _settingsBox.delete(_recentSearchesKey);
  }

  // ============ Rest Day Tracking ============

  static const String _restDayDatesKey = 'rest_day_dates';

  /// Get all dates marked as rest days
  Set<String> get restDayDates {
    final data = _settingsBox.get(_restDayDatesKey);
    if (data == null) return {};
    return Set<String>.from(data as List);
  }

  /// Check if today is a rest day
  bool get isTodayRestDay {
    final today = getTodayDateString();
    return restDayDates.contains(today);
  }

  /// Check if a specific date is a rest day
  bool isRestDay(String date) {
    return restDayDates.contains(date);
  }

  /// Toggle rest day for today
  Future<void> toggleTodayRestDay() async {
    final today = getTodayDateString();
    final dates = restDayDates;
    if (dates.contains(today)) {
      dates.remove(today);
    } else {
      dates.add(today);
    }
    await _settingsBox.put(_restDayDatesKey, dates.toList());
  }

  /// Set rest day status for a specific date
  Future<void> setRestDay(String date, bool isRest) async {
    final dates = restDayDates;
    if (isRest) {
      dates.add(date);
    } else {
      dates.remove(date);
    }
    // Keep only last 365 days to prevent unbounded growth
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    dates.removeWhere((d) {
      final dateObj = DateTime.tryParse(d);
      return dateObj != null && dateObj.isBefore(cutoff);
    });
    await _settingsBox.put(_restDayDatesKey, dates.toList());
  }

  // ============ Leaderboard Cache ============

  static const String _leaderboardCacheKey = 'leaderboard_cache';

  /// Get cached leaderboard data
  Map<String, dynamic>? getCachedLeaderboard() {
    final data = _settingsBox.get(_leaderboardCacheKey);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Set cached leaderboard data
  Future<void> setCachedLeaderboard(Map<String, dynamic> data) async {
    await _settingsBox.put(_leaderboardCacheKey, data);
  }

  /// Clear leaderboard cache
  Future<void> clearLeaderboardCache() async {
    await _settingsBox.delete(_leaderboardCacheKey);
  }

  // ============ Chat History ============

  static const String _chatHistoryKey = 'chat_history';

  /// Get chat history
  List<ChatMessage> getChatHistory() {
    final data = _settingsBox.get(_chatHistoryKey);
    if (data == null) return [];

    try {
      final list = data as List;
      return list
          .map(
            (item) =>
                ChatMessage.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (e) {
      print('Error loading chat history: $e');
      return [];
    }
  }

  /// Save chat history
  Future<void> saveChatHistory(List<ChatMessage> messages) async {
    final data = messages.map((m) => m.toMap()).toList();
    await _settingsBox.put(_chatHistoryKey, data);
  }

  /// Clear chat history
  Future<void> clearChatHistory() async {
    await _settingsBox.delete(_chatHistoryKey);
  }
}
