import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../core/theme/app_theme.dart';

/// Auto-update service that checks GitHub releases for new versions.
///
/// Usage:
/// ```dart
/// // Call on app start or periodically
/// await UpdateService.checkForUpdate(context);
/// ```
class UpdateService {
  // GitHub repository info
  static const String _owner = 'aniketapai';
  static const String _repo = 'StepPulse';

  /// Check for updates and show dialog if available (silent - for app launch)
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final updateInfo = await _checkGitHubRelease();

      if (updateInfo != null && context.mounted) {
        _showUpdateDialog(context, updateInfo);
      }
    } catch (e) {
      // Silently fail - don't interrupt user experience
      debugPrint('Update check failed: $e');
    }
  }

  /// Manual check with loading indicator and user feedback
  static Future<void> checkForUpdateManually(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.accentBlack),
            SizedBox(width: 20),
            Text('Checking for updates...'),
          ],
        ),
      ),
    );

    try {
      final updateInfo = await _checkGitHubRelease();

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      if (updateInfo != null && context.mounted) {
        // Update available - show update dialog
        _showUpdateDialog(context, updateInfo);
      } else if (context.mounted) {
        // No update available - show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('You\'re on the latest version!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Could not check for updates'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// Check GitHub releases API for newer version
  static Future<UpdateInfo?> _checkGitHubRelease() async {
    // Get current app version
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    debugPrint('🔄 Update check: Current version = $currentVersion');

    // Fetch latest release from GitHub
    final url = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';
    debugPrint('🔄 Fetching: $url');
    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    debugPrint('🔄 Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('🔄 Failed to fetch releases');
      return null;
    }

    final data = jsonDecode(response.body);
    final latestTag = data['tag_name'] as String; // e.g., "v2.0.0"
    final latestVersion = latestTag.replaceFirst('v', ''); // "2.0.0"
    debugPrint('🔄 Latest version on GitHub: $latestVersion');
    debugPrint(
      '🔄 Is newer: ${_isNewerVersion(latestVersion, currentVersion)}',
    );

    // Compare versions
    if (_isNewerVersion(latestVersion, currentVersion)) {
      // Find APK asset
      String? apkUrl;
      final assets = data['assets'] as List;
      for (final asset in assets) {
        final name = asset['name'] as String;
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String;
          break;
        }
      }
      debugPrint('🔄 APK URL found: $apkUrl');

      if (apkUrl != null) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          releaseNotes: data['body'] as String? ?? 'New version available!',
          downloadUrl: apkUrl,
          releaseName: data['name'] as String? ?? 'New Update',
        );
      }
    }

    return null;
  }

  /// Compare version strings (e.g., "2.0.0" vs "1.0.0")
  static bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;

      if (l > c) return true;
      if (l < c) return false;
    }

    return false;
  }

  /// Show update available dialog
  static void _showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UpdateDialog(info: info),
    );
  }
}

/// Update information
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;
  final String releaseName;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releaseName,
  });
}

/// Update dialog widget
class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentBlack,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Available!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'v${widget.info.currentVersion} → v${widget.info.latestVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.info.releaseName,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: Text(
                _cleanReleaseNotes(widget.info.releaseNotes),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: AppTheme.bg(context),
              valueColor: const AlwaysStoppedAnimation(AppTheme.accentBlack),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: _isDownloading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Later',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: _downloadAndInstall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlack,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Update Now'),
              ),
            ],
    );
  }

  String _cleanReleaseNotes(String notes) {
    // Remove markdown headers and clean up
    return notes
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll('**', '')
        .replaceAll('- ', '• ')
        .trim();
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _status = 'Starting download...';
    });

    try {
      // Get download directory
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/steppulse_update.apk';
      final file = File(filePath);

      // Download with progress
      final request = http.Request('GET', Uri.parse(widget.info.downloadUrl));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();

      await response.stream
          .map((chunk) {
            received += chunk.length;
            if (contentLength > 0) {
              setState(() {
                _progress = received / contentLength;
                _status =
                    'Downloading... ${(_progress * 100).toStringAsFixed(0)}%';
              });
            }
            return chunk;
          })
          .pipe(sink);

      setState(() {
        _status = 'Opening installer...';
      });

      // Open APK for installation
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done) {
        throw Exception('Failed to open APK: ${result.message}');
      }

      // Close dialog after opening installer
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _status = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
