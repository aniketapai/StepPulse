/// Provider for managing AI chat state and history
library;

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';
import 'step_provider.dart';

/// Chat state
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Chat provider
class ChatNotifier extends StateNotifier<ChatState> {
  final GeminiService _geminiService;
  final StorageService _storage;
  final Ref _ref;

  ChatNotifier(this._geminiService, this._storage, this._ref)
    : super(const ChatState()) {
    _loadChatHistory();
  }

  /// Load chat history from storage
  void _loadChatHistory() {
    final history = _storage.getChatHistory();
    if (history.isNotEmpty) {
      state = state.copyWith(messages: history);
    }
  }

  /// Send a message to the AI
  Future<void> sendMessage(String text, {List<File>? images}) async {
    if (text.trim().isEmpty && (images == null || images.isEmpty)) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      imagePaths: images?.map((f) => f.path).toList(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
    );

    try {
      // Get user context
      final userContext = _getUserContext();

      // Get AI response
      final response = await _geminiService.sendMessage(
        prompt: text,
        images: images,
        userContext: userContext,
      );

      // Add AI message
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );

      final updatedMessages = [...state.messages, aiMessage];
      state = state.copyWith(messages: updatedMessages, isLoading: false);

      // Save to storage
      _storage.saveChatHistory(updatedMessages);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to get response: $e',
      );
    }
  }

  /// Clear chat history
  void clearChat() {
    state = const ChatState();
    _storage.clearChatHistory();
  }

  /// Get user context for personalized responses
  Map<String, dynamic> _getUserContext() {
    final settings = _ref.read(settingsProvider);
    final steps = _ref.read(stepProvider).todaySteps;

    // Calculate BMI
    double? bmi;
    if (settings.heightCm > 0 && settings.weightKg > 0) {
      final heightM = settings.heightCm / 100;
      bmi = settings.weightKg / (heightM * heightM);
    }

    // Convert activity level number to string
    final activityLabels = [
      'sedentary',
      'light',
      'moderate',
      'active',
      'very active',
    ];
    final levelIndex = settings.activityLevel is int
        ? (settings.activityLevel as int).clamp(0, 4)
        : 2; // default to moderate
    final activityLevel = activityLabels[levelIndex];

    return {
      'age': settings.age,
      'gender': settings.gender,
      'weight': settings.weightKg,
      'height': settings.heightCm,
      'bmi': bmi?.toStringAsFixed(1),
      'goal': settings.dailyGoal,
      'steps': steps,
      'activityLevel': activityLevel,
    };
  }
}

/// Chat provider
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final geminiService = GeminiService();
  final storage = ref.watch(storageServiceProvider);
  return ChatNotifier(geminiService, storage, ref);
});
