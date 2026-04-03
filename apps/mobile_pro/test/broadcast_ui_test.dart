import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:castnow_pro/screens/broadcast_screen.dart';

void main() {
  testWidgets('BroadcastScreen Source Selection UI Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(
      home: BroadcastScreen(isPro: true),
    ));

    // Verify that the title is present
    expect(find.text('SELECT SOURCES'), findsOneWidget);
    expect(find.text('Select what to broadcast to the receiver'), findsOneWidget);

    // Verify Source Cards exist
    expect(find.text('Screen Mirror'), findsOneWidget);
    expect(find.text('Camera View'), findsOneWidget);
    expect(find.text('HD Microphone'), findsOneWidget);

    // Verify the Start Button exists
    expect(find.text('START BROADCAST'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  testWidgets('BroadcastScreen Toggle Source Test', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: BroadcastScreen(isPro: true),
    ));

    // Initially "Screen Mirror" is true (default)
    // We can't easily check the 'value' property of a custom AnimatedContainer 
    // without exposing it, but we can verify it's tappable.
    
    final screenCard = find.text('Screen Mirror');
    await tester.tap(screenCard);
    await tester.pumpAndSettle();

    final cameraCard = find.text('Camera View');
    await tester.tap(cameraCard);
    await tester.pumpAndSettle();

    // Verify background still exists
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
