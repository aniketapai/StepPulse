import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import 'settings_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return FirestoreService(storage);
});
