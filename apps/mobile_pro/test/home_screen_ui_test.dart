import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:castnow_pro/screens/home_screen.dart';
import 'package:castnow_pro/core/subscription_service.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';

class MockSubscriptionService extends Mock implements SubscriptionService {
  @override
  bool get isSubscribed => false;

  @override
  bool get isPurchasing => false;
}

void main() {
  testWidgets('HomeScreen UI changes verification test', (WidgetTester tester) async {
    final mockSubService = MockSubscriptionService();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<SubscriptionService>.value(
          value: mockSubService,
          child: const HomeScreen(),
        ),
      ),
    );

    // Verify app name 'cast' and 'now' are present
    expect(find.byType(RichText), findsAtLeastNWidgets(1));
    final richTextFinder = find.byType(RichText);
    bool foundCastNow = false;
    for (var widget in tester.widgetList<RichText>(richTextFinder)) {
      final textSpan = widget.text as TextSpan;
      final textContent = textSpan.toPlainText();
      if (textContent.contains('castnow')) {
        foundCastNow = true;
      }
    }
    expect(foundCastNow, true, reason: "The screen should display the title 'castnow'");

    // Verify "Pro" suffix is NOT present in the title
    final proTextFinder = find.text('Pro');
    expect(proTextFinder, findsNothing, reason: "'Pro' suffix should be removed from the title");

    // Verify "GET PRO" badge is present on the screen
    expect(find.text('GET PRO'), findsOneWidget);
  });
}
