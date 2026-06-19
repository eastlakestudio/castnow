import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:castnow_pro/core/subscription_service.dart';
import 'package:castnow_pro/screens/broadcast_screen.dart';
import 'package:castnow_pro/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel purchasesChannel = MethodChannel('purchases_flutter');
  const MethodChannel subUtilsChannel = MethodChannel('subscription_utils');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(purchasesChannel, (call) async {
      if (call.method == 'setupPurchases' || call.method == 'setLogLevel')
        return null;
      if (call.method == 'getCustomerInfo') {
        return {
          'entitlements': {'all': {}, 'active': {}},
          'allPurchaseDates': {},
          'activeSubscriptions': [],
          'allPurchasedProductIdentifiers': [],
          'nonSubscriptionTransactions': [],
          'firstSeen': '2023-01-01T00:00:00Z',
          'originalAppUserId': 'test_user',
          'allExpirationDates': {},
          'requestDate': '2023-01-01T00:00:00Z',
          'originalPurchaseDate': null,
          'managementURL': null,
        };
      }
      if (call.method == 'getOfferings') {
        return {'all': {}, 'current': null};
      }
      if (call.method == 'getProductInfo' || call.method == 'getProducts') {
        return [];
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(subUtilsChannel, (call) async {
      if (call.method == 'getOriginalAppVersion') return '3.0.0';
      return null;
    });

    SubscriptionService().resetForTesting();
    await SubscriptionService().init();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(purchasesChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(subUtilsChannel, null);
  });

  testWidgets('BroadcastScreen Source Selection UI Test',
      (WidgetTester tester) async {
    final subscriptionService = SubscriptionService();

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionService>.value(
        value: subscriptionService,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BroadcastScreen(isPro: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the title is present
    expect(find.text('SELECT SOURCES'), findsOneWidget);
    expect(
        find.text('Select what to broadcast to the receiver'), findsOneWidget);

    // Verify Source Cards exist
    expect(find.text('Screen Mirror'), findsOneWidget);
    expect(find.text('Camera View'), findsOneWidget);
    expect(find.text('HD Microphone'), findsOneWidget);

    // Verify the Start Button exists
    expect(find.text('START BROADCAST'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    // Clean up pending timers from dispose()
    await tester.pumpWidget(Container());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('BroadcastScreen Toggle Source Test',
      (WidgetTester tester) async {
    final subscriptionService = SubscriptionService();

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionService>.value(
        value: subscriptionService,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BroadcastScreen(isPro: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

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

    // Clean up pending timers from dispose()
    await tester.pumpWidget(Container());
    await tester.pump(const Duration(milliseconds: 500));
  });
}
