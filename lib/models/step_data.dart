/// Model for daily step data
class StepData {
  final String date; // YYYY-MM-DD format
  final int steps;

  const StepData({required this.date, required this.steps});

  /// Create from map (Hive storage)
  factory StepData.fromMap(Map<String, dynamic> map) {
    return StepData(date: map['date'] as String, steps: map['steps'] as int);
  }

  /// Convert to map for Hive storage
  Map<String, dynamic> toMap() {
    return {'date': date, 'steps': steps};
  }

  @override
  String toString() => 'StepData(date: $date, steps: $steps)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StepData && other.date == date && other.steps == steps;
  }

  @override
  int get hashCode => date.hashCode ^ steps.hashCode;
}
