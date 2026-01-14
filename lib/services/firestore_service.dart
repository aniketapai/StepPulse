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
        },
        'stats': _localStorage.getXpData() ?? {},
        'settings': {
          'useMetric': _localStorage.useMetric,
          'isOnboardingComplete': _localStorage.isOnboardingComplete,
        },
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
      }

      // 2. Sync Settings (only preference settings, NOT onboarding status)
      if (data.containsKey('settings')) {
        final settings = data['settings'] as Map<String, dynamic>;
        if (settings.containsKey('useMetric')) {
          await _localStorage.setUseMetric(settings['useMetric'] ?? true);
        }
        // NOTE: We intentionally DO NOT sync isOnboardingComplete
        // to prevent re-login loops and data loss scenarios
      }

      // 3. Sync XP/Stats (Cloud wins - these are earned progress)
      if (data.containsKey('stats')) {
        final stats = data['stats'] as Map<String, dynamic>;
        // Only update XP if cloud has higher values (progress shouldn't go backwards)
        final localXp = _localStorage.getXpData();
        final cloudXp = stats['xp'] as int? ?? 0;
        final localXpValue = (localXp?['xp'] as int?) ?? 0;

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
}
