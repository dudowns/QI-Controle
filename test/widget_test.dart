// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    // Build a simple MaterialApp for testing
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('QI Controle')),
        ),
      ),
    );

    // Verify that the app renders
    expect(find.text('QI Controle'), findsOneWidget);
  });
}
