import 'dart:async';
import 'package:pedometer/pedometer.dart';

/// Service for reading step count from device sensor
class StepService {
  StreamSubscription<StepCount>? _subscription;
  final _stepController = StreamController<int>.broadcast();

  /// Stream of raw step count from sensor
  /// Note: Returns total steps since device boot, not daily steps
  Stream<int> get stepStream => _stepController.stream;

  /// Whether the step sensor is available
  bool _isAvailable = true;
  bool get isAvailable => _isAvailable;

  /// Start listening to step counter sensor
  void startListening() {
    try {
      final stream = Pedometer.stepCountStream;
      _subscription = stream.listen(
        (StepCount event) {
          _stepController.add(event.steps);
        },
        onError: (error) {
          _isAvailable = false;
          _stepController.addError(error);
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isAvailable = false;
      _stepController.addError(e);
    }
  }

  /// Stop listening to step counter
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Dispose resources
  void dispose() {
    stopListening();
    _stepController.close();
  }
}
