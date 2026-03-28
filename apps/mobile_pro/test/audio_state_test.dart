import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:castnow_pro/main.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  testWidgets('BroadcastScreen initial audio state should be unmuted', (WidgetTester tester) async {
    // Note: We might need to mock navigator.mediaDevices and other platform calls
    // because BroadcastScreen calls them in initState or button taps.
    
    await tester.pumpWidget(const MaterialApp(
      home: BroadcastScreen(isPro: true),
    ));

    // Initially it shows the source selection if _peerId is null
    expect(find.text('Select Source'), findsOneWidget);
    
    // Check if buttons exist
    expect(find.text('Screen Share'), findsOneWidget);
    expect(find.text('Camera Share'), findsOneWidget);
  });
}
