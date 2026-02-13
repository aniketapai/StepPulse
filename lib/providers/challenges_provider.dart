import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/challenge.dart';
import '../services/firestore_service.dart';
import 'settings_provider.dart';

/// State for challenges system
class ChallengesState {
  final List<Challenge> activeChallenges;
  final List<Challenge> pendingChallenges;
  final List<Challenge> completedChallenges;
  final bool isLoading;
  final String? error;

  const ChallengesState({
    this.activeChallenges = const [],
    this.pendingChallenges = const [],
    this.completedChallenges = const [],
    this.isLoading = false,
    this.error,
  });

  ChallengesState copyWith({
    List<Challenge>? activeChallenges,
    List<Challenge>? pendingChallenges,
    List<Challenge>? completedChallenges,
    bool? isLoading,
    String? error,
  }) {
    return ChallengesState(
      activeChallenges: activeChallenges ?? this.activeChallenges,
      pendingChallenges: pendingChallenges ?? this.pendingChallenges,
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
            // Only show pending challenges the user RECEIVED (not created)
            if (_userId != null && c.opponentId == _userId) {
              pending.add(c);
            }
            break;
          case ChallengeStatus.completed:
            completed.add(c);
            break;
          case ChallengeStatus.declined:
            // Skip declined challenges
            break;
        }
      }

      state = state.copyWith(
        activeChallenges: active,
        pendingChallenges: pending,
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
