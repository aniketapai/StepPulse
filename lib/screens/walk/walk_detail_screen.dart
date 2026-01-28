import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/walk_session.dart';

/// Screen to view details of a completed walk with map route
class WalkDetailScreen extends StatefulWidget {
  final WalkSession walk;
  final Function(WalkSession)? onUpdate;

  const WalkDetailScreen({super.key, required this.walk, this.onUpdate});

  @override
  State<WalkDetailScreen> createState() => _WalkDetailScreenState();
}

class _WalkDetailScreenState extends State<WalkDetailScreen> {
  late WalkSession _walk;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _walk = widget.walk;
    // Fit map to route after build - only if we have valid route
    if (_hasValidRoute()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapToRoute();
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Check if we have a valid route with at least one point
  bool _hasValidRoute() {
    if (_walk.routePoints.isEmpty) return false;
    // Check if first point has valid coordinates
    final first = _walk.routePoints.first;
    return first.latitude.isFinite && first.longitude.isFinite;
  }

  void _fitMapToRoute() {
    if (!_hasValidRoute()) return;

    try {
      // Need at least 2 points for bounds fitting
      if (_walk.routePoints.length >= 2) {
        // Validate all points have finite values
        final validPoints = _walk.polylinePoints
            .where((p) => p.latitude.isFinite && p.longitude.isFinite)
            .toList();

        if (validPoints.length >= 2) {
          final bounds = LatLngBounds.fromPoints(validPoints);
          // Check if bounds are valid (not empty)
          if (bounds.north != bounds.south || bounds.east != bounds.west) {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(60),
              ),
            );
            return;
          }
        }
      }
      // Fallback: center on first point
      _mapController.move(_walk.routePoints.first.latLng, 16);
    } catch (e) {
      // Final fallback: just center on first point
      debugPrint('Error fitting map to route: $e');
      try {
        _mapController.move(_walk.routePoints.first.latLng, 16);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final hasRoute = _hasValidRoute();

    return Scaffold(
      backgroundColor: AppTheme.mintBackground,
      body: Stack(
        children: [
          // Map or placeholder
          hasRoute ? _buildMap() : _buildNoRouteMessage(),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                  // Recenter button
                  if (hasRoute)
                    GestureDetector(
                      onTap: _fitMapToRoute,
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
                          Icons.my_location_rounded,
                          size: 20,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom details panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date and time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateFormat.format(_walk.startTime),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        timeFormat.format(_walk.startTime),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.straighten_rounded,
                        value: '${_walk.distanceKm.toStringAsFixed(2)} km',
                        label: 'Distance',
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.timer_outlined,
                        value: _formatDuration(_walk.duration),
                        label: 'Duration',
                      ),
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.directions_walk_rounded,
                        value: _formatNumber(_walk.steps),
                        label: 'Steps',
                      ),
                    ],
                  ),

                  // Pace
                  if (_walk.paceMinPerKm > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.mintBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.speed_rounded,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Avg pace: ${_walk.paceMinPerKm.toStringAsFixed(1)} min/km',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Rating
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < _walk.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: index < _walk.rating
                                ? Colors.amber
                                : AppTheme.textSecondary.withValues(alpha: 0.3),
                            size: 22,
                          );
                        }),
                      ),
                      // Edit button
                      GestureDetector(
                        onTap: () => _showEditSheet(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.mintBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: AppTheme.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Description
                  if (_walk.description != null &&
                      _walk.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _walk.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    LatLng initialPosition = _walk.routePoints.first.latLng;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: initialPosition, initialZoom: 15),
      children: [
        // OpenStreetMap tiles
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.steppulse.app',
        ),

        // Route polyline
        if (_walk.routePoints.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _walk.polylinePoints,
                color: AppTheme.accentBlack,
                strokeWidth: 5,
              ),
            ],
          ),

        // Markers
        MarkerLayer(
          markers: [
            // Start marker (green)
            Marker(
              point: _walk.routePoints.first.latLng,
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

            // End marker (red)
            if (_walk.routePoints.length > 1)
              Marker(
                point: _walk.routePoints.last.latLng,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.stop_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoRouteMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No route recorded',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'GPS data was not captured for this walk',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 100), // Space for bottom panel
        ],
      ),
    );
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _EditWalkSheet(
        walk: _walk,
        onSave: (updatedWalk) {
          setState(() {
            _walk = updatedWalk;
          });
          Navigator.pop(context);
          // Notify parent if callback provided
          widget.onUpdate?.call(updatedWalk);
        },
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.mintBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet for editing walk's description and rating
class _EditWalkSheet extends StatefulWidget {
  final WalkSession walk;
  final Function(WalkSession) onSave;

  const _EditWalkSheet({required this.walk, required this.onSave});

  @override
  State<_EditWalkSheet> createState() => _EditWalkSheetState();
}

class _EditWalkSheetState extends State<_EditWalkSheet> {
  late int _rating;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _rating = widget.walk.rating;
    _descriptionController = TextEditingController(
      text: widget.walk.description ?? '',
    );
  }

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Edit Walk',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Star rating
            Text(
              'Rating',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
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
            Text(
              'Note',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary),
              cursorColor: AppTheme.accentBlack,
              decoration: InputDecoration(
                hintText: 'Add a note about your walk...',
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
                final updatedWalk = widget.walk.copyWith(
                  rating: _rating,
                  description: _descriptionController.text.isEmpty
                      ? null
                      : _descriptionController.text,
                );
                widget.onSave(updatedWalk);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlack,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Save Changes',
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
}
