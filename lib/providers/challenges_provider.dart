import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/challenge.dart';
import '../services/firestore_service.dart';
import 'settings_provider.dart';

/// State for challenges system
class ChallengesState {
  final List<Challenge> activeChallenges;
  final List<Challenge> pendingChallenges;
  final List<Challenge> sentChallenges;
  final List<Challenge> cancelRequestedChallenges;
  final List<Challenge> completedChallenges;
  final bool isLoading;
  final String? error;

  const ChallengesState({
    this.activeChallenges = const [],
    this.pendingChallenges = const [],
    this.sentChallenges = const [],
    this.cancelRequestedChallenges = const [],
    this.completedChallenges = const [],
    this.isLoading = false,
    this.error,
  });

  ChallengesState copyWith({
    List<Challenge>? activeChallenges,
    List<Challenge>? pendingChallenges,
    List<Challenge>? sentChallenges,
    List<Challenge>? cancelRequestedChallenges,
    List<Challenge>? completedChallenges,
    bool? isLoading,
    String? error,
  }) {
    return ChallengesState(
      activeChallenges: activeChallenges ?? this.activeChallenges,
      pendingChallenges: pendingChallenges ?? this.pendingChallenges,
      sentChallenges: sentChallenges ?? this.sentChallenges,
      cancelRequestedChallenges:
          cancelRequestedChallenges ?? this.cancelRequestedChallenges,
      completedChallenges: completedChallenges ?? this.completedChallenges,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Total pending challenges (received, not created by user)
  int get pendingCount => pendingChallenges.length;
}

/// Provider for challenges state management
class ChallengesNotifier extends StateNotifier<ChallengesState> {
  final FirestoreService _firestoreService;
  final String? _userId;

  ChallengesNotifier(this._firestoreService, this._userId)
    : super(const ChallengesState());

  /// Load all challenges and categorize them
  Future<void> loadChallenges() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final all = await _firestoreService.getChallenges();

      final active = <Challenge>[];
      final pending = <Challenge>[];
      final sent = <Challenge>[];
      final cancelRequested = <Challenge>[];
      final completed = <Challenge>[];

      for (final c in all) {
        switch (c.status) {
          case ChallengeStatus.active:
            // Check if expired — auto-complete
            if (c.isExpired) {
              await _firestoreService.completeChallenge(c.id);
              completed.add(c);
            } else {
              active.add(c);
            }
            break;
          case ChallengeStatus.pending:
            if (_userId != null && c.opponentId == _userId) {
              // Received challenge
              pending.add(c);
            } else if (_userId != null && c.creatorId == _userId) {
              // Sent challenge (waiting for opponent)
              sent.add(c);
            }
            break;
          case ChallengeStatus.cancelRequested:
            cancelRequested.add(c);
            break;
          case ChallengeStatus.completed:
            completed.add(c);
            break;
          case ChallengeStatus.declined:
          case ChallengeStatus.cancelled:
            // Skip
            break;
        }
      }

      state = state.copyWith(
        activeChallenges: active,
        pendingChallenges: pending,
        sentChallenges: sent,
        cancelRequestedChallenges: cancelRequested,
        completedChallenges: completed,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load challenges: $e',
      );
    }
  }

  /// Create a new challenge
  Future<void> createChallenge({
    required ChallengeType type,
    required String opponentId,
    required String opponentName,
    required ChallengeDuration duration,
  }) async {
    try {
      await _firestoreService.createChallenge(
        type: type,
        opponentId: opponentId,
        opponentName: opponentName,
        duration: duration,
      );
      await loadChallenges();
    } catch (e) {
      rethrow;
    }
  }

  /// Accept a pending challenge
  Future<void> acceptChallenge(String challengeId) async {
    try {
      await _firestoreService.acceptChallenge(challengeId);
      await loadChallenges();
    } catch (e) {
      rethrow;
    }
  }

  /// Decline a pending challenge
  Future<void> declineChallenge(String challengeId) async {
    try {
      await _firestoreService.declineChallenge(challengeId);
      await loadChallenges();
    } catch (e) {
      rethrow;
    }
  }

  /// Request cancellation of an active challenge
  Future<void> requestCancel(String challengeId) async {
    try {
      await _firestoreService.requestCancelChallenge(challengeId);
      await loadChallenges();
    } catch (e) {
      rethrow;
    }
  }

  /// Confirm cancellation (both agree — no penalty)
  Future<void> confirmCancel(String challengeId) async {
    try {
      await _firestoreService.confirmCancelChallenge(challengeId);
      await loadChallenges();
    } catch (e) {
      rethrow;
    }
  }

  /// Reject cancellation (requester loses XP, challenge resumes)
  Future<void> rejectCancel(String challengeId) async {
    try {
      await _firestoreService.rejectCancelChallenge(challengeId);
      await loadChallenges();
    } catch (e) {
      rethrow;
    }
  }

  /// Update progress for a challenge
  Future<void> updateProgress(String challengeId, int progress) async {
    await _firestoreService.updateChallengeProgress(challengeId, progress);
  }
}

/// Provider instance
final challengesProvider =
    StateNotifierProvider<ChallengesNotifier, ChallengesState>((ref) {
      final storage = ref.watch(storageServiceProvider);
      final firestoreService = FirestoreService(storage);
      final userId = FirebaseAuth.instance.currentUser?.uid;
      return ChallengesNotifier(firestoreService, userId);
    });
