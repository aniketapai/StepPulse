// Widget test for StepPulse app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_steps_app/app.dart';

void main() {
  testWidgets('StepPulse app loads permission screen', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: StepPulseApp()));

    // Verify that the app loads (will show loading indicator initially)
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
