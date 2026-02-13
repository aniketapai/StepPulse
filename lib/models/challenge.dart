import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of challenges available
enum ChallengeType {
  steps, // Total steps competition
  goalDays, // Daily goal streak competition
  xp, // XP earned competition
}

/// Status of a challenge
enum ChallengeStatus {
  pending, // Waiting for opponent to accept
  active, // In progress
  completed, // Finished with a winner
  declined, // Opponent declined
}

/// Duration options for challenges
enum ChallengeDuration { threeDays, oneWeek, twoWeeks, oneMonth }

extension ChallengeDurationExt on ChallengeDuration {
  int get days {
    switch (this) {
      case ChallengeDuration.threeDays:
        return 3;
      case ChallengeDuration.oneWeek:
        return 7;
      case ChallengeDuration.twoWeeks:
        return 14;
      case ChallengeDuration.oneMonth:
        return 30;
    }
  }

  String get label {
    switch (this) {
      case ChallengeDuration.threeDays:
        return '3 Days';
      case ChallengeDuration.oneWeek:
        return '1 Week';
      case ChallengeDuration.twoWeeks:
        return '2 Weeks';
      case ChallengeDuration.oneMonth:
        return '1 Month';
    }
  }
}

extension ChallengeTypeExt on ChallengeType {
  String get label {
    switch (this) {
      case ChallengeType.steps:
        return 'Step Challenge';
      case ChallengeType.goalDays:
        return 'Daily Goal Streak';
      case ChallengeType.xp:
        return 'XP Battle';
    }
  }

  String get emoji {
    switch (this) {
      case ChallengeType.steps:
        return '🏃';
      case ChallengeType.goalDays:
        return '🎯';
      case ChallengeType.xp:
        return '⚡';
    }
  }

  String get description {
    switch (this) {
      case ChallengeType.steps:
        return 'Who walks more total steps';
      case ChallengeType.goalDays:
        return 'Who hits their daily goal more days';
      case ChallengeType.xp:
        return 'Who earns more XP during the period';
    }
  }

  String get unit {
    switch (this) {
      case ChallengeType.steps:
        return 'steps';
      case ChallengeType.goalDays:
        return 'days';
      case ChallengeType.xp:
        return 'XP';
    }
  }
}

/// Model for a challenge between two friends
class Challenge {
  final String id;
  final ChallengeType type;
  final ChallengeStatus status;
  final String creatorId;
  final String opponentId;
  final String creatorName;
  final String opponentName;
  final DateTime startDate;
  final DateTime endDate;
  final int creatorProgress;
  final int opponentProgress;
  final String? winnerId;
  final DateTime createdAt;

  const Challenge({
    required this.id,
    required this.type,
    required this.status,
    required this.creatorId,
    required this.opponentId,
    required this.creatorName,
    required this.opponentName,
    required this.startDate,
    required this.endDate,
    this.creatorProgress = 0,
    this.opponentProgress = 0,
    this.winnerId,
    required this.createdAt,
  });

  /// Create from Firestore document
  factory Challenge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Challenge(
      id: doc.id,
      type: ChallengeType.values.firstWhere(
        (e) => e.name == (data['type'] as String? ?? 'steps'),
        orElse: () => ChallengeType.steps,
      ),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'pending'),
        orElse: () => ChallengeStatus.pending,
      ),
      creatorId: data['creatorId'] as String? ?? '',
      opponentId: data['opponentId'] as String? ?? '',
      creatorName: data['creatorName'] as String? ?? 'Unknown',
      opponentName: data['opponentName'] as String? ?? 'Unknown',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      creatorProgress: data['creatorProgress'] as int? ?? 0,
      opponentProgress: data['opponentProgress'] as int? ?? 0,
      winnerId: data['winnerId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'status': status.name,
      'creatorId': creatorId,
      'opponentId': opponentId,
      'creatorName': creatorName,
      'opponentName': opponentName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'creatorProgress': creatorProgress,
      'opponentProgress': opponentProgress,
      'winnerId': winnerId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Whether this challenge involves a specific user
  bool involvesUser(String userId) =>
      creatorId == userId || opponentId == userId;

  /// Whether the current user is the creator
  bool isCreator(String userId) => creatorId == userId;

  /// Get the opponent's name for a given user
  String getOpponentName(String userId) =>
      creatorId == userId ? opponentName : creatorName;

  /// Get the opponent's ID for a given user
  String getOpponentId(String userId) =>
      creatorId == userId ? opponentId : creatorId;

  /// Get user's own progress
  int getUserProgress(String userId) =>
      creatorId == userId ? creatorProgress : opponentProgress;

  /// Get opponent's progress
  int getOpponentProgress(String userId) =>
      creatorId == userId ? opponentProgress : creatorProgress;

  /// Whether the challenge has ended (past end date)
  bool get isExpired => DateTime.now().isAfter(endDate);

  /// Days remaining in the challenge
  int get daysRemaining {
    final remaining = endDate.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// Total duration in days
  int get totalDays => endDate.difference(startDate).inDays;

  /// Progress percentage (0.0 - 1.0) of time elapsed
  double get timeProgress {
    final total = endDate.difference(startDate).inMilliseconds;
    final elapsed = DateTime.now().difference(startDate).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  @override
  String toString() =>
      'Challenge($id, ${type.label}, $status, $creatorName vs $opponentName)';
}
