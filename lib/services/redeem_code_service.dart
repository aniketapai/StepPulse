import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'storage_service.dart';

/// Actions that can be triggered by redeem codes
enum RedeemCodeAction {
  resetAll, // RESET100 - Full data reset
  unlockPro, // Future: Unlock pro features
  removeAds, // Future: Remove ads permanently
}

/// Result of code redemption attempt
enum RedeemCodeResult { success, invalidCode, alreadyRedeemed, error }

/// Information about a redeemable code
class RedeemCodeInfo {
  final String code;
  final RedeemCodeAction action;
  final String title;
  final String description;
  final String warning;
  final bool requiresConfirmation;

  const RedeemCodeInfo({
    required this.code,
    required this.action,
    required this.title,
    required this.description,
    required this.warning,
    this.requiresConfirmation = true,
  });
}

/// Result wrapper for code validation
class CodeValidationResult {
  final bool isValid;
  final RedeemCodeInfo? codeInfo;
  final String? errorMessage;

  const CodeValidationResult({
    required this.isValid,
    this.codeInfo,
    this.errorMessage,
  });
}

/// Service for managing code redemption
class RedeemCodeService {
  final StorageService _localStorage;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RedeemCodeService(this._localStorage);

  /// Registry of all valid codes
  static const Map<String, RedeemCodeInfo> _codeRegistry = {
    'RESET100': RedeemCodeInfo(
      code: 'RESET100',
      action: RedeemCodeAction.resetAll,
      title: 'Full Reset',
      description:
          'This will delete ALL your data including steps, XP, history, profile, and cloud backup. You will start completely fresh as a new user.',
      warning: '⚠️ This action cannot be undone!',
      requiresConfirmation: true,
    ),
    // Future codes can be added here:
    // 'PRO2024': RedeemCodeInfo(
    //   code: 'PRO2024',
    //   action: RedeemCodeAction.unlockPro,
    //   title: 'Unlock Pro',
    //   description: 'Unlocks all pro features permanently.',
    //   warning: '',
    //   requiresConfirmation: true,
    // ),
  };

  /// Validate a code and return its info
  CodeValidationResult validateCode(String code) {
    final normalizedCode = code.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      return const CodeValidationResult(
        isValid: false,
        errorMessage: 'Please enter a code',
      );
    }

    final codeInfo = _codeRegistry[normalizedCode];

    if (codeInfo == null) {
      return const CodeValidationResult(
        isValid: false,
        errorMessage: 'Invalid code. Please check and try again.',
      );
    }

    return CodeValidationResult(isValid: true, codeInfo: codeInfo);
  }

  /// Execute the action for a validated code
  Future<RedeemCodeResult> executeCode(RedeemCodeInfo codeInfo) async {
    try {
      switch (codeInfo.action) {
        case RedeemCodeAction.resetAll:
          return await _executeFullReset();
        case RedeemCodeAction.unlockPro:
          return await _executeUnlockPro();
        case RedeemCodeAction.removeAds:
          return await _executeRemoveAds();
      }
    } catch (e) {
      print('❌ [RedeemCodeService] Error executing code: $e');
      return RedeemCodeResult.error;
    }
  }

  /// Execute full reset - clears all local and cloud data
  Future<RedeemCodeResult> _executeFullReset() async {
    try {
      // 1. Delete cloud data first (while we still have the user ID)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print(
          '🔄 [RedeemCodeService] Starting full reset for user: ${user.uid}',
        );
        await _deleteCloudData(user.uid);

        // Add a small delay to ensure Firestore propagates the deletes
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 2. Clear all local data
      await _localStorage.clearAllData();

      print('✅ [RedeemCodeService] Full reset completed');
      return RedeemCodeResult.success;
    } catch (e) {
      print('❌ [RedeemCodeService] Full reset failed: $e');
      return RedeemCodeResult.error;
    }
  }

  /// Delete all user data from Firestore
  /// This will delete all subcollections and the main user document
  Future<void> _deleteCloudData(String userId) async {
    final userDoc = _firestore.collection('users').doc(userId);

    // Delete history subcollection first (in batches for large collections)
    await _deleteCollection(userDoc.collection('history'));

    // Delete any other subcollections that might exist
    // Add more here if you have other subcollections

    // Delete main user document
    await userDoc.delete();

    // Verify deletion was successful by checking if doc still exists
    final docSnapshot = await userDoc.get();
    if (docSnapshot.exists) {
      throw Exception(
        'Failed to delete user document - still exists after delete',
      );
    }

    print('✅ [RedeemCodeService] Cloud data deleted for user: $userId');
  }

  /// Delete all documents in a collection (handles batching for large collections)
  Future<void> _deleteCollection(CollectionReference collection) async {
    const batchSize = 100;
    QuerySnapshot snapshot;

    do {
      snapshot = await collection.limit(batchSize).get();

      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      print(
        '🗑️ [RedeemCodeService] Deleted ${snapshot.docs.length} documents from ${collection.path}',
      );
    } while (snapshot.docs.length == batchSize);
  }

  /// Execute unlock pro (placeholder for future)
  Future<RedeemCodeResult> _executeUnlockPro() async {
    await _localStorage.setPremium(true);
    return RedeemCodeResult.success;
  }

  /// Execute remove ads (placeholder for future - same as pro for now)
  Future<RedeemCodeResult> _executeRemoveAds() async {
    await _localStorage.setPremium(true);
    return RedeemCodeResult.success;
  }
}
