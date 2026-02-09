import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'storage_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _localStorage;

  FirestoreService(this._localStorage);

  /// Collection reference for users
  CollectionReference get _users => _firestore.collection('users');

  /// Save all local data to Firestore (Push)
  Future<void> saveUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ [FirestoreService] Cannot save: No user logged in');
      return;
    }

    print(
      '🚀 [FirestoreService] Attempting to save data for user: ${user.uid}...',
    );

    try {
      final batch = _firestore.batch();
      final userDoc = _users.doc(user.uid);

      // 1. Prepare main user document data
      final userData = {
        'profile': {
          'name': _localStorage.profileName,
          // 'photoUrl': _localStorage.profilePhotoPath, // Local path useless in cloud
          'height': _localStorage.heightCm,
          'weight': _localStorage.weightKg,
          'goal': _localStorage.dailyGoal,
          'memberSince': _localStorage.memberSince,
          // Body stats for BMR/TDEE calculations
          'age': _localStorage.age,
          'gender': _localStorage.gender,
          'activityLevel': _localStorage.activityLevel,
        },
        'stats': _localStorage.getXpData() ?? {},
        'settings': {
          'useMetric': _localStorage.useMetric,
          'isOnboardingComplete': _localStorage.isOnboardingComplete,
          'dashboardTheme': _localStorage.dashboardTheme,
        },
        // Weight history for trend tracking
        'weightHistory': _localStorage.getWeightHistory(),
        // Rest day dates
        'restDayDates': _localStorage.restDayDates.toList(),
        'lastSyncedAt': FieldValue.serverTimestamp(),
        'device': 'flutter_app', // simplified
      };

      batch.set(userDoc, userData, SetOptions(merge: true));

      // 2. Save history as sub-collection (only last 30 days to save writes?)
      // Or sync all? For now, let's sync only dirty or recent.
      // A simple approach is to sync the last 7 days + today every time.
      // Or we can assume history doesn't change for past days.
      // Let's sync today + last 7 days.
      final history = _localStorage.getHistory(days: 30);
      for (final day in history) {
        final dayDoc = userDoc.collection('history').doc(day.date);
        batch.set(dayDoc, {'steps': day.steps}, SetOptions(merge: true));
      }

      await batch.commit();
      print('Cloud sync completed (Save)');
    } catch (e) {
      print('Error saving to Firestore: $e');
    }
  }

  /// Sync data from Firestore to Local (Pull & Merge)
  ///
  /// IMPORTANT: Step sensor data (baselineSteps, lastRawSteps, todaySteps)
  /// is LOCAL-ONLY and should NEVER be synced from cloud. This data comes
  /// from the device's step sensor and is unique per device.
  ///
  /// What we sync:
  /// - Profile (name, height, weight, goal) - Cloud wins
  /// - XP/Stats - Cloud wins (these are earned progress)
  /// - History (past day step counts) - Merge/Max (higher value wins)
  /// - Settings (useMetric) - Cloud wins
  ///
  /// What we DO NOT sync from cloud:
  /// - baselineSteps, lastRawSteps, currentDate (sensor data)
  /// - isOnboardingComplete (keep local value to avoid logout loops)
  ///
  /// Returns TRUE if cloud data existed (returning user), FALSE if new user.
  Future<bool> syncUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final userDoc = _users.doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        // No cloud data - this is a NEW user
        await saveUserData();
        return false; // Not a returning user
      }

      // Cloud data EXISTS - this is a RETURNING user
      // Mark onboarding as complete locally (they've done it before)
      await _localStorage.setOnboardingComplete(true);

      final data = docSnapshot.data() as Map<String, dynamic>;
      bool dataUpdated = false;

      // 1. Sync Profile (Cloud wins for profile data)
      if (data.containsKey('profile')) {
        final profile = data['profile'] as Map<String, dynamic>;

        // Only sync profile fields if they have meaningful values
        if (profile['name'] != null && (profile['name'] as String).isNotEmpty) {
          await _localStorage.setProfileName(profile['name']);
        }
        if (profile['height'] != null && profile['height'] > 0) {
          await _localStorage.setHeightCm(profile['height']);
        }
        if (profile['weight'] != null && profile['weight'] > 0) {
          await _localStorage.setWeightKg(profile['weight']);
        }
        if (profile['goal'] != null && profile['goal'] > 0) {
          await _localStorage.setDailyGoal(profile['goal']);
        }
        // Sync body stats for BMR/TDEE calculations
        if (profile['age'] != null && profile['age'] > 0) {
          await _localStorage.setAge(profile['age']);
        }
        if (profile['gender'] != null) {
          await _localStorage.setGender(profile['gender']);
        }
        if (profile['activityLevel'] != null) {
          await _localStorage.setActivityLevel(profile['activityLevel']);
        }
      }

      // 2. Sync Settings (only preference settings, NOT onboarding status)
      if (data.containsKey('settings')) {
        final settings = data['settings'] as Map<String, dynamic>;
        if (settings.containsKey('useMetric')) {
          await _localStorage.setUseMetric(settings['useMetric'] ?? true);
        }
        if (settings.containsKey('dashboardTheme')) {
          await _localStorage.setDashboardTheme(
            settings['dashboardTheme'] ?? 0,
          );
        }
        // NOTE: We intentionally DO NOT sync isOnboardingComplete
        // to prevent re-login loops and data loss scenarios
      }

      // 5. Sync Weight History
      if (data.containsKey('weightHistory')) {
        final cloudWeightHistory = data['weightHistory'] as List<dynamic>?;
        if (cloudWeightHistory != null && cloudWeightHistory.isNotEmpty) {
          // Merge with local - keep entries with latest data
          final localHistory = _localStorage.getWeightHistory();
          final mergedDates = <String, double>{};

          // Add local entries first
          for (final entry in localHistory) {
            final date = entry['date'] as String?;
            final weight = (entry['weight'] as num?)?.toDouble();
            if (date != null && weight != null) {
              mergedDates[date] = weight;
            }
          }

          // Cloud entries override local (cloud wins for same date)
          for (final entry in cloudWeightHistory) {
            if (entry is Map) {
              final date = entry['date'] as String?;
              final weight = (entry['weight'] as num?)?.toDouble();
              if (date != null && weight != null) {
                mergedDates[date] = weight;
              }
            }
          }

          // Save merged weight history
          for (final entry in mergedDates.entries) {
            await _localStorage.addWeightEntry(entry.value, date: entry.key);
          }
          dataUpdated = true;
        }
      }

      // 6. Sync Rest Day Dates
      if (data.containsKey('restDayDates')) {
        final cloudRestDays = data['restDayDates'] as List<dynamic>?;
        if (cloudRestDays != null) {
          for (final date in cloudRestDays) {
            if (date is String) {
              await _localStorage.setRestDay(date, true);
            }
          }
          dataUpdated = true;
        }
      }

      // 3. Sync XP/Stats (Cloud wins - these are earned progress)
      if (data.containsKey('stats')) {
        final stats = data['stats'] as Map<String, dynamic>;
        // Only update XP if cloud has higher values (progress shouldn't go backwards)
        // Note: stats contains {totalXp, currentStreak, ...} directly, not nested under 'xp'
        final localXp = _localStorage.getXpData();
        final cloudXp = stats['totalXp'] as int? ?? 0;
        final localXpValue = (localXp?['totalXp'] as int?) ?? 0;

        if (cloudXp >= localXpValue) {
          await _localStorage.saveXpData(stats);
          dataUpdated = true;
        }
      }

      // 4. Sync History (Merge/Max - higher step count wins)
      final historySnapshot = await userDoc.collection('history').get();
      for (final doc in historySnapshot.docs) {
        final date = doc.id;
        final cloudSteps = doc.data()['steps'] as int? ?? 0;
        final localSteps = _localStorage.getStepsForDate(date) ?? 0;

        // Only update if cloud has more steps (never reduce step count)
        if (cloudSteps > localSteps) {
          await _localStorage.saveStepsForDate(date, cloudSteps);
          dataUpdated = true;
        }
      }

      print('✅ Cloud sync completed (Pull) - dataUpdated: $dataUpdated');
      return dataUpdated;
    } catch (e) {
      // Fail silently - local data is preserved
      print('⚠️ Cloud sync failed (offline?): $e');
      return false;
    }
  }

  /// Save a single walk session to Firestore
  Future<void> saveWalk(Map<String, dynamic> walkData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ [FirestoreService] Cannot save walk: No user logged in');
      return;
    }

    try {
      final walkId =
          walkData['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString();
      await _users
          .doc(user.uid)
          .collection('walks')
          .doc(walkId)
          .set(walkData, SetOptions(merge: true));
      print('✅ Walk saved to cloud: $walkId');
    } catch (e) {
      print('⚠️ Error saving walk to cloud: $e');
    }
  }

  /// Sync all walks from Firestore to local storage
  Future<void> syncWalks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final walksSnapshot = await _users
          .doc(user.uid)
          .collection('walks')
          .orderBy('startTime', descending: true)
          .limit(50)
          .get();

      if (walksSnapshot.docs.isEmpty) return;

      // Get local walks
      final localWalks = _localStorage.getWalkHistory();
      final localIds = <String>{};
      for (final walk in localWalks) {
        if (walk is Map) {
          localIds.add(walk['id'] as String? ?? '');
        }
      }

      // Add cloud walks that aren't already local
      final mergedWalks = List<dynamic>.from(localWalks);
      for (final doc in walksSnapshot.docs) {
        if (!localIds.contains(doc.id)) {
          mergedWalks.add(doc.data());
        }
      }

      // Sort by startTime descending and keep only last 50
      mergedWalks.sort((a, b) {
        final aTime = a['startTime'] as String? ?? '';
        final bTime = b['startTime'] as String? ?? '';
        return bTime.compareTo(aTime);
      });

      if (mergedWalks.length > 50) {
        mergedWalks.removeRange(50, mergedWalks.length);
      }

      await _localStorage.saveWalkHistory(mergedWalks);
      print('✅ Walks synced from cloud: ${walksSnapshot.docs.length} walks');
    } catch (e) {
      print('⚠️ Error syncing walks from cloud: $e');
    }
  }

  /// Delete a walk from Firestore
  Future<void> deleteWalk(String walkId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _users.doc(user.uid).collection('walks').doc(walkId).delete();
      print('✅ Walk deleted from cloud: $walkId');
    } catch (e) {
      print('⚠️ Error deleting walk from cloud: $e');
    }
  }

  /// Fetch global leaderboard - top users by XP
  /// Returns list of user documents ordered by totalXp descending
  /// Limited to top 50 users to minimize reads
  Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 50}) async {
    try {
      final snapshot = await _users
          .orderBy('stats.totalXp', descending: true)
          .limit(limit)
          .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        results.add({...data, 'userId': doc.id});
      }

      print('✅ Fetched leaderboard: ${results.length} users');
      return results;
    } catch (e) {
      print('⚠️ Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Get total count of users for leaderboard display
  Future<int> getTotalUserCount() async {
    try {
      final snapshot = await _users.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('⚠️ Error getting user count: $e');
      return 0;
    }
  }

  /// Get current user's rank in the leaderboard
  /// Returns null if user not found or not logged in
  Future<int?> getCurrentUserRank() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // Get current user's XP
      final userDoc = await _users.doc(user.uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final stats = userData['stats'] as Map<String, dynamic>?;
      final userXp = stats?['totalXp'] as int? ?? 0;

      // Count users with more XP (rank = count + 1)
      final higherRankedSnapshot = await _users
          .where('stats.totalXp', isGreaterThan: userXp)
          .count()
          .get();

      final rank = (higherRankedSnapshot.count ?? 0) + 1;
      print('✅ Current user rank: #$rank with $userXp XP');
      return rank;
    } catch (e) {
      print('⚠️ Error getting user rank: $e');
      return null;
    }
  }

  /// Get a specific user's data by userId
  /// Used for viewing other users' profiles from leaderboard
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final userDoc = await _users.doc(userId).get();
      if (!userDoc.exists) {
        print('⚠️ User not found: $userId');
        return null;
      }

      final data = userDoc.data() as Map<String, dynamic>;
      print('✅ Fetched user data for: $userId');
      return {...data, 'userId': userId};
    } catch (e) {
      print('⚠️ Error fetching user data: $e');
      return null;
    }
  }
}
