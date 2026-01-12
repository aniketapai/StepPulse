import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/step_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/foreground_service.dart';

/// Permission handling screen
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _permissionDenied = false;
  final bool _sensorUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionDenied) {
      _checkPermission();
    }
  }

  /// Get the correct permission based on platform
  Permission get _stepPermission {
    if (Platform.isIOS) {
      // iOS uses sensors permission for CMPedometer (Motion & Fitness)
      return Permission.sensors;
    } else {
      // Android uses activityRecognition
      return Permission.activityRecognition;
    }
  }

  Future<void> _checkPermission() async {
    setState(() {
      _isLoading = true;
    });

    final permission = _stepPermission;
    final status = await permission.status;

    if (status.isGranted) {
      _startTrackingAndNavigate();
    } else if (status.isDenied) {
      final result = await permission.request();
      if (result.isGranted) {
        _startTrackingAndNavigate();
      } else {
        setState(() {
          _isLoading = false;
          _permissionDenied = true;
        });
      }
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
    } else {
      final result = await permission.request();
      if (result.isGranted) {
        _startTrackingAndNavigate();
      } else {
        setState(() {
          _isLoading = false;
          _permissionDenied = true;
        });
      }
    }
  }

  Future<void> _startTrackingAndNavigate() async {
    // Start foreground service for persistent notification
    await ForegroundStepService().start();

    ref.read(stepProvider.notifier).setPermissionStatus(true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mintBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentBlack),
                )
              : _buildPermissionUI(context),
        ),
      ),
    );
  }

  Widget _buildPermissionUI(BuildContext context) {
    final theme = Theme.of(context);

    if (_sensorUnavailable) {
      return _buildErrorState(
        theme: theme,
        icon: Icons.sensors_off_rounded,
        title: 'Sensor Unavailable',
        message:
            'Your device doesn\'t have a step counter sensor. '
            'StepPulse requires this sensor to track your steps.',
        buttonText: 'Close App',
        onPressed: () => Navigator.of(context).pop(),
      );
    }

    if (_permissionDenied) {
      final isIOS = Platform.isIOS;
      return _buildErrorState(
        theme: theme,
        icon: Icons.directions_walk_rounded,
        title: 'Permission Required',
        message: isIOS
            ? 'StepPulse needs access to Motion & Fitness data to count your steps. '
                  'Please enable it in Settings → Privacy → Motion & Fitness.'
            : 'StepPulse needs access to your activity data to count your steps. '
                  'Please grant the Activity Recognition permission.',
        buttonText: 'Open Settings',
        onPressed: _openSettings,
      );
    }

    return const Center(
      child: CircularProgressIndicator(color: AppTheme.accentBlack),
    );
  }

  Widget _buildErrorState({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: AppTheme.cardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppTheme.mintBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppTheme.accentBlack),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            ),

            // Retry button
            if (_permissionDenied) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _checkPermission,
                child: Text(
                  'Try Again',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }
}
