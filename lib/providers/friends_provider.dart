import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';
import '../services/firestore_service.dart';
import 'settings_provider.dart';

/// State for friends system
class FriendsState {
  final String? friendCode;
  final List<Friend> friends;
  final List<FriendRequest> receivedRequests;
  final List<FriendRequest> sentRequests;
  final bool isLoading;
  final String? error;

  const FriendsState({
    this.friendCode,
    this.friends = const [],
    this.receivedRequests = const [],
    this.sentRequests = const [],
    this.isLoading = false,
    this.error,
  });

  FriendsState copyWith({
    String? friendCode,
    List<Friend>? friends,
    List<FriendRequest>? receivedRequests,
    List<FriendRequest>? sentRequests,
    bool? isLoading,
    String? error,
  }) {
    return FriendsState(
      friendCode: friendCode ?? this.friendCode,
      friends: friends ?? this.friends,
      receivedRequests: receivedRequests ?? this.receivedRequests,
      sentRequests: sentRequests ?? this.sentRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get pendingRequestsCount => receivedRequests.length;
}

/// Provider for friends system state management
class FriendsNotifier extends StateNotifier<FriendsState> {
  final FirestoreService _firestoreService;
  bool _initialized = false;

  FriendsNotifier(this._firestoreService) : super(const FriendsState());

  /// Whether friends data has been successfully loaded
  bool get isInitialized => _initialized;

  /// Initialize friends data
  /// If force is true, re-fetches even if already loaded
  Future<void> initialize({bool force = false}) async {
    // Skip if already successfully loaded (unless forced)
    if (_initialized && !force) return;

    state = state.copyWith(isLoading: true, error: null);
    String? loadError;

    // Load each independently so one failure doesn't block others
    try {
      await loadFriendCode();
    } catch (e) {
      print('⚠️ Error in loadFriendCode: $e');
    }

    try {
      await loadFriends();
    } catch (e) {
      loadError = 'Failed to load friends: $e';
    }

    try {
      await loadFriendRequests();
    } catch (e) {
      loadError ??= 'Failed to load friend requests: $e';
    }

    if (loadError != null) {
      _initialized = false;
      state = state.copyWith(isLoading: false, error: loadError);
    } else {
      _initialized = true;
      state = state.copyWith(isLoading: false);
    }
  }

  /// Load current user's friend code
  Future<void> loadFriendCode() async {
    try {
      final code = await _firestoreService.getCurrentUserFriendCode();
      state = state.copyWith(friendCode: code);
    } catch (e) {
      print('⚠️ Error loading friend code: $e');
    }
  }

  /// Load friends list
  Future<void> loadFriends() async {
    final friends = await _firestoreService.getFriendsList();
    state = state.copyWith(friends: friends);
  }

  /// Load friend requests (both received and sent)
  Future<void> loadFriendRequests() async {
    final received = await _firestoreService.getPendingReceivedRequests();
    final sent = await _firestoreService.getPendingSentRequests();
    state = state.copyWith(receivedRequests: received, sentRequests: sent);
  }

  /// Send a friend request by friend code
  Future<void> sendRequest(String code) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _firestoreService.sendFriendRequest(code);
      // Reload sent requests to show the new request
      await loadFriendRequests();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Accept a friend request
  Future<void> acceptRequest(String requestId) async {
    // Optimistic update
    final request = state.receivedRequests.firstWhere(
      (r) => r.id == requestId,
      orElse: () => throw Exception('Request not found'),
    );

    final updatedReceived = state.receivedRequests
        .where((r) => r.id != requestId)
        .toList();

    // Create a temporary friend object from the request
    final tempFriend = Friend(
      userId: request.senderId,
      friendCode: request.senderCode,
      displayName: request.senderName,
      totalXp: 0, // Will be updated after server response
      level: 1,
      friendsSince: DateTime.now(),
    );

    state = state.copyWith(
      receivedRequests: updatedReceived,
      friends: [tempFriend, ...state.friends],
    );

    try {
      await _firestoreService.acceptFriendRequest(requestId);
      // Reload to get accurate friend data
      await loadFriends();
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        receivedRequests: [request, ...updatedReceived],
        friends: state.friends
            .where((f) => f.userId != request.senderId)
            .toList(),
        error: 'Failed to accept friend request',
      );
      rethrow;
    }
  }

  /// Reject a friend request
  Future<void> rejectRequest(String requestId) async {
    // Optimistic update
    final originalReceived = state.receivedRequests;
    final updatedReceived = originalReceived
        .where((r) => r.id != requestId)
        .toList();

    state = state.copyWith(receivedRequests: updatedReceived);

    try {
      await _firestoreService.rejectFriendRequest(requestId);
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        receivedRequests: originalReceived,
        error: 'Failed to reject friend request',
      );
      rethrow;
    }
  }

  /// Cancel a sent friend request
  Future<void> cancelRequest(String requestId) async {
    // Optimistic update
    final originalSent = state.sentRequests;
    final updatedSent = originalSent.where((r) => r.id != requestId).toList();

    state = state.copyWith(sentRequests: updatedSent);

    try {
      await _firestoreService.cancelFriendRequest(requestId);
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        sentRequests: originalSent,
        error: 'Failed to cancel friend request',
      );
      rethrow;
    }
  }

  /// Remove a friend
  Future<void> removeFriend(String friendUserId) async {
    // Optimistic update
    final originalFriends = state.friends;
    final updatedFriends = originalFriends
        .where((f) => f.userId != friendUserId)
        .toList();

    state = state.copyWith(friends: updatedFriends);

    try {
      await _firestoreService.removeFriend(friendUserId);
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        friends: originalFriends,
        error: 'Failed to remove friend',
      );
      rethrow;
    }
  }

  /// Search for a user by friend code (preview before sending request)
  Future<Map<String, dynamic>?> searchByCode(String code) async {
    try {
      return await _firestoreService.getUserPreviewByCode(code);
    } catch (e) {
      print('⚠️ Error searching by code: $e');
      return null;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Refresh all friends data
  Future<void> refresh() async {
    await initialize(force: true);
  }
}

/// Provider instance
final friendsProvider = StateNotifierProvider<FriendsNotifier, FriendsState>((
  ref,
) {
  final storage = ref.watch(storageServiceProvider);
  final firestoreService = FirestoreService(storage);
  return FriendsNotifier(firestoreService);
});

/// Shared state for friends sidebar visibility
/// Used to toggle sidebar from any screen (e.g. Profile button)
final friendsSidebarVisibleProvider = StateProvider<bool>((ref) => false);
