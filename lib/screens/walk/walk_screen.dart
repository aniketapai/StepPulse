import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../models/walk_session.dart';
import '../../providers/walking_provider.dart';
import '../../providers/step_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/geocoding_service.dart';
import 'walk_detail_screen.dart';

/// Walk tracking screen with live GPS map and controls
class WalkScreen extends ConsumerStatefulWidget {
  const WalkScreen({super.key});

  @override
  ConsumerState<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends ConsumerState<WalkScreen> {
  final MapController _mapController = MapController();
  Timer? _stepUpdateTimer;

  // Countdown state
  bool _showingCountdown = false;
  int _countdownValue = 3;

  // Current location
  LatLng? _currentLocation;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GeocodingService _geocodingService = GeocodingService();
  List<SearchResult> _searchResults = [];
  List<Map<String, dynamic>> _recentSearches = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  bool _showRecentSearches = false;
  Timer? _searchDebounce;

  // Walk history state
  List<WalkSession> _recentWalks = [];
  final bool _showWalkHistory = true;

  @override
  void initState() {
    super.initState();
    // Get current location on load
    _getCurrentLocation();
    // Load recent searches
    _loadRecentSearches();
    // Load walk history
    _loadWalkHistory();

    // Listen for search focus changes
    _searchFocusNode.addListener(_onSearchFocusChanged);

    // Periodically sync steps with walk session
    _stepUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final steps = ref.read(stepProvider);
      ref.read(walkingProvider.notifier).updateSteps(steps.todaySteps);
    });
  }

  void _loadRecentSearches() {
    final storage = ref.read(storageServiceProvider);
    setState(() {
      _recentSearches = storage.getRecentSearches();
    });
  }

  void _loadWalkHistory() {
    try {
      final storage = ref.read(storageServiceProvider);
      final walkData = storage.getWalkHistory();
      setState(() {
        _recentWalks = walkData
            .take(5) // Show only last 5 walks
            .map((data) => WalkSession.fromMap(data as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      // Silently fail - empty walk history is fine
      _recentWalks = [];
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      setState(() {
        _showRecentSearches = _recentSearches.isNotEmpty;
        _showSearchResults = false;
      });
    } else if (!_searchFocusNode.hasFocus) {
      setState(() {
        _showRecentSearches = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError(
          'Location services are disabled. Please enable GPS.',
        );
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Location permission denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError(
          'Location permissions are permanently denied. Please enable in Settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      // Move map to current location
      try {
        _mapController.move(_currentLocation!, 16);
      } catch (_) {}
    } catch (e) {
      _showLocationError('Could not get current location. Please try again.');
    }
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        // Show recent searches when search is cleared
        _showRecentSearches =
            _recentSearches.isNotEmpty && _searchFocusNode.hasFocus;
      });
      return;
    }

    // Hide recent searches when typing
    setState(() {
      _showRecentSearches = false;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      final results = await _geocodingService.searchLocations(query);
      setState(() {
        _searchResults = results;
        _showSearchResults = results.isNotEmpty;
        _isSearching = false;
      });
    });
  }

  void _selectSearchResult(SearchResult result) {
    setState(() {
      _showSearchResults = false;
      _showRecentSearches = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();

    // Save to recent searches
    final storage = ref.read(storageServiceProvider);
    storage.addRecentSearch(
      displayName: result.displayName,
      shortName: result.shortName,
      latitude: result.location.latitude,
      longitude: result.location.longitude,
    );
    _loadRecentSearches();

    // Set destination
    ref.read(walkingProvider.notifier).setDestination(result.location);

    // Move map to destination
    try {
      _mapController.move(result.location, 15);
    } catch (_) {}
  }

  void _selectRecentSearch(Map<String, dynamic> search) {
    setState(() {
      _showSearchResults = false;
      _showRecentSearches = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();

    final location = LatLng(
      search['latitude'] as double,
      search['longitude'] as double,
    );

    // Set destination
    ref.read(walkingProvider.notifier).setDestination(location);

    // Move map to destination
    try {
      _mapController.move(location, 15);
    } catch (_) {}
  }

  @override
  void dispose() {
    _stepUpdateTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walkState = ref.watch(walkingProvider);
    final theme = Theme.of(context);

    // Auto-center on latest position
    if (walkState.session.routePoints.isNotEmpty &&
        walkState.session.status == WalkStatus.walking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(walkState.session.routePoints.last.latLng, 17);
        } catch (_) {}
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.mintBackground,
      body: Stack(
        children: [
          // Map
          _buildMap(walkState),

          // Top bar with back button, search, and action buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => _handleBack(walkState),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),

                  // Search bar (expanded to fill space, only when idle)
                  if (walkState.session.status == WalkStatus.idle) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          cursorColor: AppTheme.accentBlack,
                          decoration: InputDecoration(
                            hintText: 'Search destination...',
                            hintStyle: TextStyle(
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 14,
                            ),
                            prefixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.accentBlack,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.search_rounded,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    color: AppTheme.textSecondary,
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const Spacer(),

                  // Location button
                  GestureDetector(
                    onTap: () => _getCurrentLocation(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.my_location_rounded,
                        size: 20,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ),

                  // History button (only when idle)
                  if (walkState.session.status == WalkStatus.idle) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/walk-history'),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          size: 20,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Search results dropdown (positioned below search bar)
          if (walkState.session.status == WalkStatus.idle &&
              _showSearchResults &&
              _searchResults.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(72, 68, 112, 0),
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return ListTile(
                        leading: Icon(
                          Icons.location_on_outlined,
                          color: Colors.blue.shade600,
                        ),
                        title: Text(
                          result.shortName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          result.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectSearchResult(result),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Recent searches dropdown (positioned below search bar)
          if (walkState.session.status == WalkStatus.idle &&
              _showRecentSearches &&
              _recentSearches.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(72, 68, 112, 0),
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Recent Searches',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _recentSearches.length,
                          itemBuilder: (context, index) {
                            final search = _recentSearches[index];
                            return ListTile(
                              leading: Icon(
                                Icons.history_rounded,
                                color: Colors.grey.shade500,
                              ),
                              title: Text(
                                search['shortName'] as String? ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                search['displayName'] as String? ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectRecentSearch(search),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Stats overlay at top (during walk)
          if (walkState.session.status != WalkStatus.idle)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(70, 16, 16, 0),
                child: _buildStatsCard(walkState, theme),
              ),
            ),

          // Destination info card (when destination is set but not walking yet)
          if (walkState.destination != null &&
              walkState.plannedRoute != null &&
              walkState.session.status == WalkStatus.idle)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(70, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.route_rounded, color: Colors.blue.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              walkState.plannedRoute!.formattedDistance,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              '${walkState.plannedRoute!.formattedDuration} walk',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => ref
                            .read(walkingProvider.notifier)
                            .clearDestination(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Route loading indicator
          if (walkState.isLoadingRoute)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(70, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Finding route...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Control buttons at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildControls(walkState, theme),
          ),

          // Error message
          if (walkState.errorMessage != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 200,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  walkState.errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Loading overlay
          if (walkState.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accentBlack),
              ),
            ),

          // Countdown overlay
          if (_showingCountdown)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_countdownValue),
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 0.5, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value,
                        child: Text(
                          '$_countdownValue',
                          style: const TextStyle(
                            fontSize: 120,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap(WalkingState walkState) {
    // Use current location if available, otherwise default to a position
    LatLng initialPosition =
        _currentLocation ??
        const LatLng(12.9716, 77.5946); // Default to Bangalore
    if (walkState.session.routePoints.isNotEmpty) {
      initialPosition = walkState.session.routePoints.last.latLng;
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialPosition,
        initialZoom: 17,
        // Long-press to set destination (only when idle)
        onLongPress: walkState.session.status == WalkStatus.idle
            ? (tapPosition, point) {
                ref.read(walkingProvider.notifier).setDestination(point);
              }
            : null,
      ),
      children: [
        // OpenStreetMap tiles (100% free!)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.steppulse.app',
        ),

        // Planned route polyline (blue) - show when destination is set
        if (walkState.plannedRoute != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: walkState.plannedRoute!.routePoints,
                color: Colors.blue.shade400,
                strokeWidth: 6,
                borderColor: Colors.blue.shade700,
                borderStrokeWidth: 1,
              ),
            ],
          ),

        // User's walked route polyline (black, solid)
        if (walkState.session.routePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: walkState.session.polylinePoints,
                color: AppTheme.accentBlack,
                strokeWidth: 5,
              ),
            ],
          ),

        // Markers
        MarkerLayer(
          markers: [
            // Destination marker (red pin)
            if (walkState.destination != null)
              Marker(
                point: walkState.destination!,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),

            // Start marker
            if (walkState.session.routePoints.isNotEmpty)
              Marker(
                point: walkState.session.routePoints.first.latLng,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // Current location marker
            if (walkState.session.routePoints.isNotEmpty)
              Marker(
                point: walkState.session.routePoints.last.latLng,
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCard(WalkingState walkState, ThemeData theme) {
    final duration = walkState.currentDuration;
    final distance = walkState.session.distanceKm;
    final pace = walkState.session.paceMinPerKm;
    final steps = walkState.session.steps;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: _formatDuration(duration),
            label: 'Time',
            icon: Icons.timer_outlined,
          ),
          _StatItem(
            value: distance.toStringAsFixed(2),
            label: 'km',
            icon: Icons.straighten_rounded,
          ),
          _StatItem(
            value: pace > 0 ? pace.toStringAsFixed(1) : '--',
            label: 'min/km',
            icon: Icons.speed_rounded,
          ),
          _StatItem(
            value: _formatNumber(steps),
            label: 'steps',
            icon: Icons.directions_walk_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildControls(WalkingState walkState, ThemeData theme) {
    final status = walkState.session.status;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: status == WalkStatus.idle
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Walk history section
                if (_showWalkHistory && _recentWalks.isNotEmpty) ...[
                  _buildWalkHistorySection(theme),
                  const SizedBox(height: 16),
                ],
                _buildStartButton(),
              ],
            )
          : _buildActiveControls(walkState),
    );
  }

  Widget _buildWalkHistorySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Walks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/walk-history'),
              child: Text(
                'See All',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentWalks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final walk = _recentWalks[index];
              return _buildWalkHistoryCard(walk, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWalkHistoryCard(WalkSession walk, ThemeData theme) {
    final distanceKm = walk.totalDistanceMeters / 1000;
    final duration = walk.duration;
    final formattedDate = _formatWalkDate(walk.startTime);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => WalkDetailScreen(walk: walk)),
        ).then((_) => _loadWalkHistory());
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.mintBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (walk.rating > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Colors.amber.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${walk.rating}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatWalkDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final walkDate = DateTime(date.year, date.month, date.day);

    if (walkDate == today) {
      return 'Today';
    } else if (walkDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: () => _startWithCountdown(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.accentBlack,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text(
              'Start Walk',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show 3-2-1 countdown before starting walk
  void _startWithCountdown() {
    setState(() {
      _showingCountdown = true;
      _countdownValue = 3;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue > 1) {
        setState(() {
          _countdownValue--;
        });
      } else {
        timer.cancel();
        setState(() {
          _showingCountdown = false;
        });
        // Actually start the walk
        ref.read(walkingProvider.notifier).startWalk();
      }
    });
  }

  Widget _buildActiveControls(WalkingState walkState) {
    final isPaused = walkState.session.status == WalkStatus.paused;

    return Row(
      children: [
        // Stop button
        Expanded(
          child: GestureDetector(
            onTap: () => _showStopConfirmation(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.stop_rounded,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stop',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Pause/Resume button
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () {
              if (isPaused) {
                ref.read(walkingProvider.notifier).resumeWalk();
              } else {
                ref.read(walkingProvider.notifier).pauseWalk();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isPaused ? AppTheme.accentBlack : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: isPaused
                    ? null
                    : Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: isPaused ? Colors.white : Colors.orange.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPaused ? 'Resume' : 'Pause',
                    style: TextStyle(
                      color: isPaused ? Colors.white : Colors.orange.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showStopConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stop_circle_outlined, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'End Walk?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Your walk will be saved to history.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.mintBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      final session = await ref
                          .read(walkingProvider.notifier)
                          .stopWalk();
                      if (mounted) {
                        _showWalkSummary(session);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlack,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'End Walk',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showWalkSummary(WalkSession session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _WalkSummarySheet(
        session: session,
        onSave: (updatedSession) {
          // Save with description and rating
          ref.read(walkingProvider.notifier).saveCompletedWalk(updatedSession);
          Navigator.pop(
            context,
          ); // Just close the summary sheet, stay on walk screen
        },
      ),
    );
  }

  void _handleBack(WalkingState walkState) {
    if (walkState.session.status != WalkStatus.idle) {
      // Show confirmation if walk is in progress
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Walk?'),
          content: const Text('Your current walk will be discarded.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                ref.read(walkingProvider.notifier).cancelWalk();
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '0:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;

  const _SummaryItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

/// Enhanced walk summary sheet with rating and description
class _WalkSummarySheet extends StatefulWidget {
  final WalkSession session;
  final Function(WalkSession) onSave;

  const _WalkSummarySheet({required this.session, required this.onSave});

  @override
  State<_WalkSummarySheet> createState() => _WalkSummarySheetState();
}

class _WalkSummarySheetState extends State<_WalkSummarySheet> {
  int _rating = 0;
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.mintBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppTheme.accentBlack,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Walk Complete! 🎉',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SummaryItem(
                  value: _formatDuration(widget.session.duration),
                  label: 'Duration',
                ),
                _SummaryItem(
                  value: '${widget.session.distanceKm.toStringAsFixed(2)} km',
                  label: 'Distance',
                ),
                _SummaryItem(
                  value: _formatNumber(widget.session.steps),
                  label: 'Steps',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Star rating
            Text(
              'How was your walk?',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: index < _rating
                          ? Colors.amber
                          : AppTheme.textSecondary,
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Description field
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              style: const TextStyle(color: AppTheme.textPrimary),
              cursorColor: AppTheme.accentBlack,
              decoration: InputDecoration(
                hintText: 'Add a note about your walk (optional)',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppTheme.mintBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            GestureDetector(
              onTap: () {
                final updatedSession = widget.session.copyWith(
                  rating: _rating,
                  description: _descriptionController.text.isEmpty
                      ? null
                      : _descriptionController.text,
                );
                widget.onSave(updatedSession);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlack,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Save Walk',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
