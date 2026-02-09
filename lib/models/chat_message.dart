/// Chat message model for AI fitness assistant
library;

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? imagePaths; // Local file paths for images

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imagePaths,
  });

  /// Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'imagePaths': imagePaths,
    };
  }

  /// Create from Map
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      isUser: map['isUser'] as bool,
      timestamp: DateTime.parse(map['timestamp'] as String),
      imagePaths: map['imagePaths'] != null
          ? List<String>.from(map['imagePaths'] as List)
          : null,
    );
  }

  /// Create a copy with modified fields
  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<String>? imagePaths,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }
}
