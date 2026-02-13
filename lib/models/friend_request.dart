import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for friend requests
class FriendRequest {
  final String id;
  final String senderId;
  final String senderName;
  final String senderCode;
  final String receiverId;
  final String receiverName;
  final String receiverCode;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;
  final DateTime? respondedAt;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderCode,
    required this.receiverId,
    required this.receiverName,
    required this.receiverCode,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  /// Create from Firestore document
  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Unknown',
      senderCode: data['senderCode'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      receiverName: data['receiverName'] as String? ?? 'Unknown',
      receiverCode: data['receiverCode'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document data
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderCode': senderCode,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverCode': receiverCode,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
    };
  }

  /// Create a copy with updated fields
  FriendRequest copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderCode,
    String? receiverId,
    String? receiverName,
    String? receiverCode,
    String? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderCode: senderCode ?? this.senderCode,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverCode: receiverCode ?? this.receiverCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  @override
  String toString() =>
      'FriendRequest(id: $id, from: $senderName, to: $receiverName, status: $status)';
}
