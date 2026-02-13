import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for user friend codes
/// Each user has a unique friend code to share with others for friend requests
class FriendCode {
  final String userId;
  final String friendCode; // Format: #XXXX1234 (9 chars total including #)
  final DateTime createdAt;

  const FriendCode({
    required this.userId,
    required this.friendCode,
    required this.createdAt,
  });

  /// Create from Firestore document data
  factory FriendCode.fromMap(Map<String, dynamic> map, String userId) {
    return FriendCode(
      userId: userId,
      friendCode: map['friendCode'] as String? ?? '',
      createdAt:
          (map['friendCodeCreatedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toMap() {
    return {
      'friendCode': friendCode,
      'friendCodeCreatedAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Validate friend code format
  static bool isValidFormat(String code) {
    // Must start with # and have exactly 8 alphanumeric characters after it
    final regex = RegExp(r'^#[A-Z0-9]{8}$');
    return regex.hasMatch(code);
  }

  /// Format a code to ensure it has the # prefix
  static String formatCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.startsWith('#')) {
      return cleanCode;
    }
    return '#$cleanCode';
  }

  @override
  String toString() => 'FriendCode(userId: $userId, code: $friendCode)';
}
