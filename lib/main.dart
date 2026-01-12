import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'services/storage_service.dart';
import 'services/foreground_service.dart';
import 'services/smart_notifications.dart';
import 'providers/settings_provider.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize storage service
  final storageService = StorageService();
  await storageService.init();

  // Initialize foreground service
  await ForegroundStepService().init();

  // Initialize smart notifications
  await SmartNotificationService().init();

  // Run the app with Riverpod
  runApp(
    ProviderScope(
      overrides: [
        // Provide the initialized storage service
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const StepPulseApp(),
    ),
  );
}
