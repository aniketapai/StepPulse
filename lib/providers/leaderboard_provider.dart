import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/leaderboard_entry.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';

/// Leaderboard state
class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final int? userRank;
  final int totalUsers;
  final bool isLoading;
  final String? error;
  final DateTime? lastFetched;

  const LeaderboardState({
    this.entries = const [],
    this.userRank,
    this.totalUsers = 0,
    this.isLoading = false,
    this.error,
    this.lastFetched,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    int? userRank,
    int? totalUsers,
    bool? isLoading,
    String? error,
    DateTime? lastFetched,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      userRank: userRank ?? this.userRank,
      totalUsers: totalUsers ?? this.totalUsers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }
}

/// Leaderboard provider with 24-hour caching
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final FirestoreService _firestoreService;
  final StorageService _storage;

  /// Cache duration: 24 hours
  static const _cacheDuration = Duration(hours: 24);

  LeaderboardNotifier(this._firestoreService, this._storage)
    : super(const LeaderboardState()) {
    _loadFromCache();
  }

  /// Load cached leaderboard data
  void _loadFromCache() {
    try {
      final cachedData = _storage.getCachedLeaderboard();
      if (cachedData != null) {
        final lastFetchedStr = cachedData['lastFetched'] as String?;
        final lastFetched = lastFetchedStr != null
            ? DateTime.tryParse(lastFetchedStr)
            : null;

        // Check if cache is still valid
        if (lastFetched != null &&
            DateTime.now().difference(lastFetched) < _cacheDuration) {
          final entriesData = cachedData['entries'] as List<dynamic>? ?? [];
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          final entries = <LeaderboardEntry>[];
          for (int i = 0; i < entriesData.length; i++) {
            final entry = entriesData[i];
            if (entry is Map) {
              entries.add(
                LeaderboardEntry.fromMap(
                  Map<String, dynamic>.from(entry),
                  i + 1,
                  isCurrentUser: entry['userId'] == currentUserId,
                ),
              );
            }
          }

          state = state.copyWith(
            entries: entries,
            userRank: cachedData['userRank'] as int?,
            totalUsers: cachedData['totalUsers'] as int? ?? 0,
            lastFetched: lastFetched,
          );
          print('✅ Loaded leaderboard from cache (${entries.length} entries)');
        }
      }
    } catch (e) {
      // If cache is corrupted, clear it and continue with empty state
      print('⚠️ Failed to load leaderboard cache: $e');
      _storage.clearLeaderboardCache();
    }
  }

  /// Fetch leaderboard from Firestore
  /// If force is true, ignores cache and fetches fresh data
  Future<void> fetchLeaderboard({bool force = false}) async {
    // Check cache validity unless force refresh
    if (!force && state.lastFetched != null) {
      final timeSinceLastFetch = DateTime.now().difference(state.lastFetched!);
      if (timeSinceLastFetch < _cacheDuration) {
        print(
          '📦 Using cached leaderboard (${timeSinceLastFetch.inMinutes} min old)',
        );
        return;
      }
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Fetch leaderboard data
      final rawEntries = await _firestoreService.fetchLeaderboard(limit: 50);
      final totalUsers = await _firestoreService.getTotalUserCount();
      final userRank = await _firestoreService.getCurrentUserRank();

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // Convert to LeaderboardEntry objects
      final entries = <LeaderboardEntry>[];
      for (int i = 0; i < rawEntries.length; i++) {
        final data = rawEntries[i];
        entries.add(
          LeaderboardEntry.fromMap(
            data,
            i + 1,
            isCurrentUser: data['userId'] == currentUserId,
          ),
        );
      }

      final now = DateTime.now();

      state = state.copyWith(
        entries: entries,
        userRank: userRank,
        totalUsers: totalUsers,
        isLoading: false,
        lastFetched: now,
      );

      // Cache the results
      await _saveToCache(rawEntries, userRank, totalUsers, now);

      print(
        '✅ Fetched fresh leaderboard: ${entries.length} entries, user rank: #$userRank',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load leaderboard',
      );
      print('⚠️ Error fetching leaderboard: $e');
    }
  }

  /// Save leaderboard to cache
  Future<void> _saveToCache(
    List<Map<String, dynamic>> entries,
    int? userRank,
    int totalUsers,
    DateTime lastFetched,
  ) async {
    final cacheData = {
      'entries': entries,
      'userRank': userRank,
      'totalUsers': totalUsers,
      'lastFetched': lastFetched.toIso8601String(),
    };
    await _storage.setCachedLeaderboard(cacheData);
  }

  /// Check if user's rank has improved since last check
  bool get hasRankImproved {
    final cached = _storage.getCachedLeaderboard();
    if (cached == null || state.userRank == null) return false;

    final previousRank = cached['previousUserRank'] as int?;
    if (previousRank == null) return false;

    return state.userRank! < previousRank;
  }
}

/// Provider for leaderboard state
final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
      // We need FirestoreService and StorageService
      // Create FirestoreService with storage
      final storage = ref.watch(storageServiceProvider);
      final firestoreService = FirestoreService(storage);
      return LeaderboardNotifier(firestoreService, storage);
    });
