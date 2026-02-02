import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/walk_session.dart';
import '../services/walking_service.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import '../services/routing_service.dart';
import 'settings_provider.dart';

/// State for walking session
class WalkingState {
  final WalkSession session;
  final Duration currentDuration;
  final bool isLoading;
  final String? errorMessage;

  // Destination navigation
  final LatLng? destination;
  final RouteInfo? plannedRoute;
  final bool isLoadingRoute;

  const WalkingState({
    required this.session,
    this.currentDuration = Duration.zero,
    this.isLoading = false,
    this.errorMessage,
    this.destination,
    this.plannedRoute,
    this.isLoadingRoute = false,
  });

  WalkingState copyWith({
    WalkSession? session,
    Duration? currentDuration,
    bool? isLoading,
    String? errorMessage,
    LatLng? destination,
    RouteInfo? plannedRoute,
    bool? isLoadingRoute,
    bool clearDestination = false,
  }) {
    return WalkingState(
      session: session ?? this.session,
      currentDuration: currentDuration ?? this.currentDuration,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      destination: clearDestination ? null : (destination ?? this.destination),
      plannedRoute: clearDestination
          ? null
          : (plannedRoute ?? this.plannedRoute),
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
    );
  }
}

/// Notifier for walking state
class WalkingNotifier extends StateNotifier<WalkingState> {
  final WalkingService _walkingService;
  final StorageService _storage;
  final FirestoreService _firestore;
  final RoutingService _routingService = RoutingService();

  // Track paused time
  DateTime? _pauseStartTime;
  Duration _totalPausedDuration = Duration.zero;
  int _startSteps = 0;

  WalkingNotifier(this._walkingService, this._storage, this._firestore)
    : super(WalkingState(session: WalkSession.create())) {
    // Set up callbacks
    _walkingService.onLocationUpdate = _onLocationUpdate;
    _walkingService.onDurationUpdate = _onDurationUpdate;
    _walkingService.onError = _onError;
  }

  /// Start a new walk
  Future<void> startWalk() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    // Check permissions first
    final hasPermission = await _walkingService.checkPermissions();
    if (!hasPermission) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Location permission required',
      );
      return;
    }

    // Get initial position
    final position = await _walkingService.getCurrentLocation();
    if (position == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not get current location',
      );
      return;
    }

    // Create new session with initial point
    final startPoint = RoutePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      altitude: position.altitude,
      speed: position.speed,
    );

    final newSession = WalkSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      routePoints: [startPoint],
      status: WalkStatus.walking,
    );

    _totalPausedDuration = Duration.zero;
    _pauseStartTime = null;

    state = state.copyWith(
      session: newSession,
      currentDuration: Duration.zero,
      isLoading: false,
    );

    // Start tracking
    await _walkingService.startTracking();
    _walkingService.startDurationTimer(newSession.startTime);
  }

  /// Pause the current walk
  void pauseWalk() {
    if (state.session.status != WalkStatus.walking) return;

    _pauseStartTime = DateTime.now();
    _walkingService.stopTracking();
    _walkingService.pauseDurationTimer();

    state = state.copyWith(
      session: state.session.copyWith(status: WalkStatus.paused),
    );
  }

  /// Resume the paused walk
  Future<void> resumeWalk() async {
    if (state.session.status != WalkStatus.paused) return;

    // Calculate paused duration
    if (_pauseStartTime != null) {
      _totalPausedDuration += DateTime.now().difference(_pauseStartTime!);
      _pauseStartTime = null;
    }

    state = state.copyWith(
      session: state.session.copyWith(status: WalkStatus.walking),
    );

    // Resume tracking
    await _walkingService.startTracking();
    _walkingService.resumeDurationTimer(
      state.session.startTime,
      _totalPausedDuration,
    );
  }

  /// Stop and return the walk (doesn't save - use saveCompletedWalk after user adds details)
  Future<WalkSession> stopWalk() async {
    _walkingService.stopTracking();

    final finalSession = state.session.copyWith(
      endTime: DateTime.now(),
      status: WalkStatus.idle,
    );

    // Reset state
    state = WalkingState(session: WalkSession.create());
    _startSteps = 0;

    return finalSession;
  }

  /// Save a completed walk with description and rating
  Future<void> saveCompletedWalk(WalkSession session) async {
    // Debug logging to trace save issues
    print(
      '[WalkSave] Saving walk: id=${session.id}, '
      'routePoints=${session.routePoints.length}, '
      'distance=${session.totalDistanceMeters.toStringAsFixed(1)}m, '
      'steps=${session.steps}, '
      'duration=${session.duration.inSeconds}s',
    );

    // Skip only walks with absolutely no data (no route, no steps, no distance)
    if (session.routePoints.isEmpty &&
        session.totalDistanceMeters < 1 &&
        session.steps == 0) {
      print('[WalkSave] Skipping walk - no data recorded');
      return;
    }

    final walkData = session.toMap();
    print('[WalkSave] Walk data prepared for save: ${walkData.keys}');

    // Save to local storage
    final walks = _storage.getWalkHistory();
    print('[WalkSave] Current walk history count: ${walks.length}');
    walks.insert(0, walkData);

    // Keep only last 50 walks
    if (walks.length > 50) {
      walks.removeRange(50, walks.length);
    }

    await _storage.saveWalkHistory(walks);
    print('[WalkSave] Walk saved to local storage. New count: ${walks.length}');

    // Save to cloud (async, don't wait)
    _firestore.saveWalk(walkData);
    print('[WalkSave] Walk queued for cloud save');
  }

  /// Update an existing walk in cloud only (for edits)
  Future<void> updateWalkInCloud(WalkSession session) async {
    final walkData = session.toMap();
    // Just save to cloud - local is already updated
    _firestore.saveWalk(walkData);
  }

  /// Delete a walk from local storage and cloud
  Future<void> deleteWalk(String walkId) async {
    // Remove from local storage
    final walks = _storage.getWalkHistory();
    walks.removeWhere((walk) {
      if (walk is Map) {
        return walk['id'] == walkId;
      }
      return false;
    });
    await _storage.saveWalkHistory(walks);

    // Delete from cloud
    _firestore.deleteWalk(walkId);
  }

  /// Cancel walk without saving
  void cancelWalk() {
    _walkingService.stopTracking();
    state = WalkingState(session: WalkSession.create());
    _startSteps = 0;
  }

  /// Handle new location update
  void _onLocationUpdate(RoutePoint point) {
    if (state.session.status != WalkStatus.walking) return;

    // Validate GPS point to filter erratic jumps (screen lock/unlock issues)
    if (state.session.routePoints.isNotEmpty) {
      final lastPoint = state.session.routePoints.last;
      final distance = WalkingService.calculateDistance(
        lastPoint.latitude,
        lastPoint.longitude,
        point.latitude,
        point.longitude,
      );
      final timeDiff = point.timestamp
          .difference(lastPoint.timestamp)
          .inSeconds;

      // Filter out erratic points: >100m in <5s is likely GPS glitch
      // (100m in 5s = 20 m/s = 72 km/h - too fast for walking)
      if (timeDiff > 0 && timeDiff < 5 && distance > 100) {
        return; // Skip this erratic point
      }

      // Also skip if point is identical or nearly identical (duplicate)
      if (distance < 1) {
        return; // Skip near-duplicate points
      }
    }

    final updatedPoints = [...state.session.routePoints, point];
    final totalDistance = WalkingService.calculateTotalDistance(updatedPoints);

    state = state.copyWith(
      session: state.session.copyWith(
        routePoints: updatedPoints,
        totalDistanceMeters: totalDistance,
      ),
    );
  }

  /// Handle duration update
  void _onDurationUpdate(Duration duration) {
    state = state.copyWith(currentDuration: duration);
  }

  /// Handle error
  void _onError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  /// Update steps during walk
  void updateSteps(int currentSteps) {
    if (state.session.status != WalkStatus.walking) return;

    if (_startSteps == 0) {
      _startSteps = currentSteps;
    }

    final walkSteps = currentSteps - _startSteps;
    state = state.copyWith(
      session: state.session.copyWith(steps: walkSteps > 0 ? walkSteps : 0),
    );
  }

  /// Set destination and fetch route
  Future<void> setDestination(LatLng destination) async {
    // Need current location to calculate route
    final position = await _walkingService.getCurrentLocation();
    if (position == null) {
      state = state.copyWith(errorMessage: 'Could not get current location');
      return;
    }

    state = state.copyWith(destination: destination, isLoadingRoute: true);

    final start = LatLng(position.latitude, position.longitude);
    final route = await _routingService.getWalkingRoute(start, destination);

    if (route != null) {
      state = state.copyWith(plannedRoute: route, isLoadingRoute: false);
    } else {
      state = state.copyWith(
        errorMessage: 'Could not find route to destination',
        isLoadingRoute: false,
        clearDestination: true,
      );
    }
  }

  /// Clear current destination
  void clearDestination() {
    state = state.copyWith(clearDestination: true);
  }

  @override
  void dispose() {
    _walkingService.dispose();
    super.dispose();
  }
}

/// Provider for walking state
final walkingProvider = StateNotifierProvider<WalkingNotifier, WalkingState>((
  ref,
) {
  final storage = ref.watch(storageServiceProvider);
  final firestore = FirestoreService(storage);
  final walkingService = WalkingService();
  return WalkingNotifier(walkingService, storage, firestore);
});
