import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/walk_session.dart';
import '../../providers/settings_provider.dart';
import '../../providers/walking_provider.dart';
import 'walk_detail_screen.dart';

/// Screen to view past walk history
class WalkHistoryScreen extends ConsumerStatefulWidget {
  const WalkHistoryScreen({super.key});

  @override
  ConsumerState<WalkHistoryScreen> createState() => _WalkHistoryScreenState();
}

class _WalkHistoryScreenState extends ConsumerState<WalkHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final walkData = storage.getWalkHistory();

    // Convert to WalkSession objects - data is stored as Maps
    final walks = <WalkSession>[];
    for (final data in walkData) {
      try {
        if (data is Map) {
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          final map = Map<String, dynamic>.from(data);
          walks.add(WalkSession.fromMap(map));
        }
      } catch (e) {
        // Skip invalid entries
        debugPrint('Error loading walk: $e');
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.subtleBg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: AppTheme.textPrimaryC(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Walk History',
          style: TextStyle(
            color: AppTheme.textPrimaryC(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: walks.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: walks.length,
              itemBuilder: (context, index) {
                final walk = walks[index];
                return _WalkHistoryCard(
                  walk: walk,
                  onTap: () => _openWalkDetail(walk, index),
                );
              },
            ),
    );
  }

  void _openWalkDetail(WalkSession walk, int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalkDetailScreen(
          walk: walk,
          onUpdate: (updatedWalk) async {
            // Update local storage
            final storage = ref.read(storageServiceProvider);
            final walks = storage.getWalkHistory();

            if (index < walks.length) {
              walks[index] = updatedWalk.toMap();
              await storage.saveWalkHistory(walks);

              // Update in cloud
              ref.read(walkingProvider.notifier).updateWalkInCloud(updatedWalk);
            }
          },
        ),
      ),
    );
    // Refresh list when returning
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_walk_rounded,
            size: 80,
            color: AppTheme.textSecondaryC(context).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No walks yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryC(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your walks to see them here!',
            style: TextStyle(
              color: AppTheme.textSecondaryC(context).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkHistoryCard extends StatelessWidget {
  final WalkSession walk;
  final VoidCallback? onTap;

  const _WalkHistoryCard({required this.walk, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(walk.startTime),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppTheme.textPrimaryC(context),
                  ),
                ),
                Text(
                  timeFormat.format(walk.startTime),
                  style: TextStyle(
                    color: AppTheme.textSecondaryC(context),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.straighten_rounded,
                  value: '${walk.distanceKm.toStringAsFixed(2)} km',
                  label: 'Distance',
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.timer_outlined,
                  value: _formatDuration(walk.duration),
                  label: 'Duration',
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.directions_walk_rounded,
                  value: _formatNumber(walk.steps),
                  label: 'Steps',
                ),
              ],
            ),
            // Pace
            if (walk.paceMinPerKm > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.subtleBg(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 16,
                      color: AppTheme.textSecondaryC(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Avg pace: ${walk.paceMinPerKm.toStringAsFixed(1)} min/km',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryC(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Rating
            if (walk.rating > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < walk.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: index < walk.rating
                        ? Colors.amber
                        : AppTheme.textSecondaryC(
                            context,
                          ).withValues(alpha: 0.3),
                    size: 18,
                  );
                }),
              ),
            ],
            // Description
            if (walk.description != null && walk.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                walk.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryC(context),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondaryC(context)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryC(context),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryC(context),
            ),
          ),
        ],
      ),
    );
  }
}
