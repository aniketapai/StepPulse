import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../models/friend.dart';
import '../models/friend_request.dart';
import '../models/friend_code.dart';
import '../models/challenge.dart';
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
      // Fetch all users and sort client-side to avoid needing a composite index
      // on the nested stats.totalXp field
      final snapshot = await _users.get();

      final results = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        results.add({...data, 'userId': doc.id});
      }

      // Sort by totalXp descending, client-side
      results.sort((a, b) {
        final aStats = a['stats'] as Map<String, dynamic>?;
        final bStats = b['stats'] as Map<String, dynamic>?;
        final aXp = aStats?['totalXp'] as int? ?? 0;
        final bXp = bStats?['totalXp'] as int? ?? 0;
        return bXp.compareTo(aXp);
      });

      // Limit results
      final limited = results.length > limit
          ? results.sublist(0, limit)
          : results;

      print(
        '✅ Fetched leaderboard: ${limited.length} users (from ${results.length} total)',
      );
      return limited;
    } catch (e) {
      print('⚠️ Error fetching leaderboard: $e');
      rethrow;
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

      // Fetch all users and count those with higher XP client-side
      // This avoids needing a Firestore index on the nested stats.totalXp field
      final allUsersSnapshot = await _users.get();
      int higherCount = 0;
      for (final doc in allUsersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final docStats = data['stats'] as Map<String, dynamic>?;
        final docXp = docStats?['totalXp'] as int? ?? 0;
        if (docXp > userXp) higherCount++;
      }

      final rank = higherCount + 1;
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

  // ============================================================================
  // FRIENDS SYSTEM
  // ============================================================================

  /// Collection reference for friend requests
  CollectionReference get _friendRequests =>
      _firestore.collection('friendRequests');

  /// Generate a unique 8-character alphanumeric friend code
  /// Format: #ABCD1234 (total 9 chars with #)
  Future<String> generateFriendCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();

    // Try up to 5 times to generate a unique code
    for (int attempt = 0; attempt < 5; attempt++) {
      // Generate 8 random characters
      final code = String.fromCharCodes(
        Iterable.generate(
          8,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ),
      );

      final friendCode = '#$code';

      // Check if code is unique
      if (await isFriendCodeUnique(friendCode)) {
        return friendCode;
      }
    }

    // Fallback: Use timestamp-based code if random generation fails
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final fallbackCode = '#${timestamp.substring(timestamp.length - 8)}';
    print('⚠️ Using fallback friend code: $fallbackCode');
    return fallbackCode;
  }

  /// Check if a friend code is unique (not already taken)
  Future<bool> isFriendCodeUnique(String code) async {
    try {
      final snapshot = await _users
          .where('friendCode', isEqualTo: code)
          .limit(1)
          .get();
      return snapshot.docs.isEmpty;
    } catch (e) {
      print('⚠️ Error checking friend code uniqueness: $e');
      return false;
    }
  }

  /// Assign a friend code to a user
  /// Used for both new users and existing users
  Future<String?> assignFriendCode(String userId) async {
    try {
      // Check if user already has a friend code
      final userDoc = await _users.doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data.containsKey('friendCode') &&
            data['friendCode'] != null &&
            (data['friendCode'] as String).isNotEmpty) {
          print('✅ User already has friend code: ${data['friendCode']}');
          return data['friendCode'] as String;
        }
      }

      // Generate new friend code
      final friendCode = await generateFriendCode();

      // Assign to user
      await _users.doc(userId).set({
        'friendCode': friendCode,
        'friendCodeCreatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Assigned friend code to user $userId: $friendCode');
      return friendCode;
    } catch (e) {
      print('⚠️ Error assigning friend code: $e');
      return null;
    }
  }

  /// Get current user's friend code
  Future<String?> getCurrentUserFriendCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _users.doc(user.uid).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data() as Map<String, dynamic>;
      return data['friendCode'] as String?;
    } catch (e) {
      print('⚠️ Error fetching friend code: $e');
      return null;
    }
  }

  /// Look up user ID by friend code
  Future<String?> getUserIdByFriendCode(String code) async {
    try {
      final formattedCode = FriendCode.formatCode(code);
      final snapshot = await _users
          .where('friendCode', isEqualTo: formattedCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ No user found with friend code: $formattedCode');
        return null;
      }

      return snapshot.docs.first.id;
    } catch (e) {
      print('⚠️ Error looking up user by friend code: $e');
      return null;
    }
  }

  /// Send a friend request to a user by their friend code
  Future<void> sendFriendRequest(String receiverCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    try {
      // Format the receiver code
      final formattedCode = FriendCode.formatCode(receiverCode);

      // Get current user's data
      final currentUserDoc = await _users.doc(user.uid).get();
      if (!currentUserDoc.exists) {
        throw Exception('Current user data not found');
      }
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final currentUserCode = currentUserData['friendCode'] as String? ?? '';
      final currentUserName =
          (currentUserData['profile'] as Map<String, dynamic>?)?['name']
              as String? ??
          'Unknown';

      // Check if trying to add self
      if (formattedCode == currentUserCode) {
        throw Exception('You cannot add yourself as a friend');
      }

      // Look up receiver by friend code
      final receiverId = await getUserIdByFriendCode(formattedCode);
      if (receiverId == null) {
        throw Exception('User not found with code: $formattedCode');
      }

      // Get receiver's data
      final receiverDoc = await _users.doc(receiverId).get();
      if (!receiverDoc.exists) {
        throw Exception('Receiver user data not found');
      }
      final receiverData = receiverDoc.data() as Map<String, dynamic>;
      final receiverName =
          (receiverData['profile'] as Map<String, dynamic>?)?['name']
              as String? ??
          'Unknown';

      // Check if already friends
      final existingFriendship = await _users
          .doc(user.uid)
          .collection('friends')
          .doc(receiverId)
          .get();
      if (existingFriendship.exists) {
        throw Exception('You are already friends with this user');
      }

      // Check if request already exists (single where to avoid composite index)
      final existingRequests = await _friendRequests
          .where('senderId', isEqualTo: user.uid)
          .get();

      final hasPendingRequest = existingRequests.docs.any((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['receiverId'] == receiverId && data['status'] == 'pending';
      });

      if (hasPendingRequest) {
        throw Exception('Friend request already sent');
      }

      // Create friend request
      final request = FriendRequest(
        id: '', // Will be set by Firestore
        senderId: user.uid,
        senderName: currentUserName,
        senderCode: currentUserCode,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverCode: formattedCode,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _friendRequests.add(request.toMap());
      print('✅ Friend request sent to $receiverName ($formattedCode)');
    } catch (e) {
      print('⚠️ Error sending friend request: $e');
      rethrow;
    }
  }

  /// Get pending received friend requests for current user
  Future<List<FriendRequest>> getPendingReceivedRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      // Use single where clause to avoid needing composite index
      final snapshot = await _friendRequests
          .where('receiverId', isEqualTo: user.uid)
          .get();

      // Filter for pending status client-side
      final requests = snapshot.docs
          .map((doc) => FriendRequest.fromFirestore(doc))
          .where((r) => r.status == 'pending')
          .toList();
      // Sort client-side
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    } catch (e) {
      print('⚠️ Error fetching received requests: $e');
      rethrow;
    }
  }

  /// Get pending sent friend requests for current user
  Future<List<FriendRequest>> getPendingSentRequests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      // Use single where clause to avoid needing composite index
      final snapshot = await _friendRequests
          .where('senderId', isEqualTo: user.uid)
          .get();

      // Filter for pending status client-side
      final requests = snapshot.docs
          .map((doc) => FriendRequest.fromFirestore(doc))
          .where((r) => r.status == 'pending')
          .toList();
      // Sort client-side
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    } catch (e) {
      print('⚠️ Error fetching sent requests: $e');
      rethrow;
    }
  }

  /// Accept a friend request
  Future<void> acceptFriendRequest(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    try {
      // Get the request
      final requestDoc = await _friendRequests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }

      final request = FriendRequest.fromFirestore(requestDoc);

      // Verify current user is the receiver
      if (request.receiverId != user.uid) {
        throw Exception('You are not authorized to accept this request');
      }

      // Get both users' full data
      final senderDoc = await _users.doc(request.senderId).get();
      final receiverDoc = await _users.doc(request.receiverId).get();

      if (!senderDoc.exists || !receiverDoc.exists) {
        throw Exception('User data not found');
      }

      final senderData = senderDoc.data() as Map<String, dynamic>;
      final receiverData = receiverDoc.data() as Map<String, dynamic>;

      // Create friend objects
      final senderFriend = Friend.fromUserData(request.senderId, senderData);
      final receiverFriend = Friend.fromUserData(
        request.receiverId,
        receiverData,
      );

      // Use batch write for atomicity
      final batch = _firestore.batch();

      // Add to both users' friends subcollections
      batch.set(
        _users
            .doc(request.receiverId)
            .collection('friends')
            .doc(request.senderId),
        senderFriend.toMap(),
      );
      batch.set(
        _users
            .doc(request.senderId)
            .collection('friends')
            .doc(request.receiverId),
        receiverFriend.toMap(),
      );

      // Update request status
      batch.update(requestDoc.reference, {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print(
        '✅ Friend request accepted: ${request.senderName} ↔ ${request.receiverName}',
      );
    } catch (e) {
      print('⚠️ Error accepting friend request: $e');
      rethrow;
    }
  }

  /// Reject a friend request
  Future<void> rejectFriendRequest(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    try {
      final requestDoc = await _friendRequests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }

      final request = FriendRequest.fromFirestore(requestDoc);

      // Verify current user is the receiver
      if (request.receiverId != user.uid) {
        throw Exception('You are not authorized to reject this request');
      }

      await requestDoc.reference.update({
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Friend request rejected from: ${request.senderName}');
    } catch (e) {
      print('⚠️ Error rejecting friend request: $e');
      rethrow;
    }
  }

  /// Cancel a sent friend request
  Future<void> cancelFriendRequest(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    try {
      final requestDoc = await _friendRequests.doc(requestId).get();
      if (!requestDoc.exists) {
        throw Exception('Friend request not found');
      }

      final request = FriendRequest.fromFirestore(requestDoc);

      // Verify current user is the sender
      if (request.senderId != user.uid) {
        throw Exception('You are not authorized to cancel this request');
      }

      await requestDoc.reference.delete();
      print('✅ Friend request cancelled to: ${request.receiverName}');
    } catch (e) {
      print('⚠️ Error cancelling friend request: $e');
      rethrow;
    }
  }

  /// Get list of friends for current user
  Future<List<Friend>> getFriendsList() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _users.doc(user.uid).collection('friends').get();

      final friends = snapshot.docs
          .map((doc) => Friend.fromFirestore(doc))
          .toList();
      // Sort client-side to avoid needing composite index
      friends.sort((a, b) => b.friendsSince.compareTo(a.friendsSince));
      return friends;
    } catch (e) {
      print('⚠️ Error fetching friends list: $e');
      rethrow;
    }
  }

  /// Remove a friend
  Future<void> removeFriend(String friendUserId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    try {
      final batch = _firestore.batch();

      // Remove from both users' friends subcollections
      batch.delete(
        _users.doc(user.uid).collection('friends').doc(friendUserId),
      );
      batch.delete(
        _users.doc(friendUserId).collection('friends').doc(user.uid),
      );

      await batch.commit();
      print('✅ Friend removed: $friendUserId');
    } catch (e) {
      print('⚠️ Error removing friend: $e');
      rethrow;
    }
  }

  /// Get user preview by friend code (for display before sending request)
  Future<Map<String, dynamic>?> getUserPreviewByCode(String code) async {
    try {
      final userId = await getUserIdByFriendCode(code);
      if (userId == null) return null;

      final userDoc = await _users.doc(userId).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data() as Map<String, dynamic>;
      final profile = data['profile'] as Map<String, dynamic>?;
      final stats = data['stats'] as Map<String, dynamic>?;

      return {
        'userId': userId,
        'displayName': profile?['name'] ?? 'Unknown',
        'friendCode': data['friendCode'] ?? '',
        'totalXp': stats?['totalXp'] ?? 0,
        'level': Friend.calculateLevel(stats?['totalXp'] ?? 0),
      };
    } catch (e) {
      print('⚠️ Error getting user preview: $e');
      return null;
    }
  }

  // ========== CHALLENGES ==========

  /// Collection reference for challenges
  CollectionReference get _challenges => _firestore.collection('challenges');

  /// Create a new challenge
  Future<String> createChallenge({
    required ChallengeType type,
    required String opponentId,
    required String opponentName,
    required ChallengeDuration duration,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    // Get creator's name
    final userDoc = await _users.doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;
    final profile = userData?['profile'] as Map<String, dynamic>?;
    final creatorName = profile?['name'] as String? ?? 'Unknown';

    final now = DateTime.now();
    final startDate = now;
    final endDate = now.add(Duration(days: duration.days));

    final challenge = Challenge(
      id: '', // Will be set by Firestore
      type: type,
      status: ChallengeStatus.pending,
      creatorId: user.uid,
      opponentId: opponentId,
      creatorName: creatorName,
      opponentName: opponentName,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
    );

    final docRef = await _challenges.add(challenge.toMap());
    print('✅ Created challenge: ${docRef.id}');
    return docRef.id;
  }

  /// Get all challenges for the current user (active + completed)
  Future<List<Challenge>> getChallenges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      // Fetch challenges where user is creator
      final creatorSnapshot = await _challenges
          .where('creatorId', isEqualTo: user.uid)
          .get();

      // Fetch challenges where user is opponent
      final opponentSnapshot = await _challenges
          .where('opponentId', isEqualTo: user.uid)
          .get();

      final allDocs = <DocumentSnapshot>[
        ...creatorSnapshot.docs,
        ...opponentSnapshot.docs,
      ];

      // Deduplicate by doc ID
      final seen = <String>{};
      final challenges = <Challenge>[];
      for (final doc in allDocs) {
        if (seen.add(doc.id)) {
          challenges.add(Challenge.fromFirestore(doc));
        }
      }

      // Sort by creation date (newest first)
      challenges.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ Fetched ${challenges.length} challenges');
      return challenges;
    } catch (e) {
      print('⚠️ Error fetching challenges: $e');
      return [];
    }
  }

  /// Accept a challenge
  Future<void> acceptChallenge(String challengeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    try {
      final now = DateTime.now();
      // Get the challenge to calculate the proper end date from NOW
      final doc = await _challenges.doc(challengeId).get();
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) throw Exception('Challenge not found');

      // Calculate duration from original dates
      final originalStart = (data['startDate'] as Timestamp).toDate();
      final originalEnd = (data['endDate'] as Timestamp).toDate();
      final durationDays = originalEnd.difference(originalStart).inDays;

      // Reset start and end dates from acceptance time
      await _challenges.doc(challengeId).update({
        'status': ChallengeStatus.active.name,
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(now.add(Duration(days: durationDays))),
        'creatorProgress': 0,
        'opponentProgress': 0,
      });
      print('✅ Accepted challenge: $challengeId');
    } catch (e) {
      print('⚠️ Error accepting challenge: $e');
      rethrow;
    }
  }

  /// Decline a challenge
  Future<void> declineChallenge(String challengeId) async {
    try {
      await _challenges.doc(challengeId).update({
        'status': ChallengeStatus.declined.name,
      });
      print('✅ Declined challenge: $challengeId');
    } catch (e) {
      print('⚠️ Error declining challenge: $e');
      rethrow;
    }
  }

  /// Update challenge progress for current user
  Future<void> updateChallengeProgress(String challengeId, int progress) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await _challenges.doc(challengeId).get();
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final isCreator = data['creatorId'] == user.uid;
      final field = isCreator ? 'creatorProgress' : 'opponentProgress';

      await _challenges.doc(challengeId).update({field: progress});
    } catch (e) {
      print('⚠️ Error updating challenge progress: $e');
    }
  }

  /// Complete a challenge and determine the winner
  Future<void> completeChallenge(String challengeId) async {
    try {
      final doc = await _challenges.doc(challengeId).get();
      final challenge = Challenge.fromFirestore(doc);

      String? winnerId;
      if (challenge.creatorProgress > challenge.opponentProgress) {
        winnerId = challenge.creatorId;
      } else if (challenge.opponentProgress > challenge.creatorProgress) {
        winnerId = challenge.opponentId;
      }
      // null = tie

      await _challenges.doc(challengeId).update({
        'status': ChallengeStatus.completed.name,
        'winnerId': winnerId,
      });
      print('✅ Completed challenge: $challengeId, winner: $winnerId');
    } catch (e) {
      print('⚠️ Error completing challenge: $e');
      rethrow;
    }
  }
}
