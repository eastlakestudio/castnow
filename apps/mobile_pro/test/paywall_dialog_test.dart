import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:castnow_pro/core/subscription_service.dart';
import 'package:castnow_pro/widgets/paywall_dialog.dart';

class MockSubscriptionService extends ChangeNotifier implements SubscriptionService {
  @override
  bool isAvailable = true;
  @override
  bool isSubscribed = false;
  @override
  bool isPurchasing = false;
  
  bool buyYearlySubscriptionCalled = false;
  bool restorePurchasesCalled = false;

  @override
  Package? annualPackage;
  
  @override
  StoreProduct? localStoreProduct;

  @override
  List<Package> get products => [];
  
  @override
  String? errorMessage;

  @override
  Future<void> buyYearlySubscription() async {
    buyYearlySubscriptionCalled = true;
    notifyListeners();
  }

  @override
  Future<void> restorePurchases() async {
    restorePurchasesCalled = true;
    notifyListeners();
  }

  @override
  Future<void> init() async {}
  
  @override
  Future<void> loadProducts() async {}
  
  @override
  void resetForTesting() {}
  
  @override
  bool isVersionLegacy(String version) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('purchases_flutter');
  bool impressionTracked = false;

  setUp(() {
    impressionTracked = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'trackCustomPaywallImpression') {
        impressionTracked = true;
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('PaywallDialog renders correctly and triggers impression tracking when offeringId exists', (WidgetTester tester) async {
    final mockService = MockSubscriptionService();

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionService>.value(
        value: mockService,
        child: const MaterialApp(
          home: Scaffold(
            body: PaywallDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Upgrade to PRO'), findsOneWidget);
    expect(find.text('Subscribe Now'), findsOneWidget);
    expect(find.text('Restore Purchases'), findsOneWidget);
  });

  testWidgets('PaywallDialog calls buyYearlySubscription when "Subscribe Now" is tapped', (WidgetTester tester) async {
    final mockService = MockSubscriptionService();

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionService>.value(
        value: mockService,
        child: const MaterialApp(
          home: Scaffold(
            body: PaywallDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final subscribeButton = find.text('Subscribe Now');
    expect(subscribeButton, findsOneWidget);

    await tester.tap(subscribeButton);
    await tester.pump();

    expect(mockService.buyYearlySubscriptionCalled, isTrue);
  });

  testWidgets('PaywallDialog calls restorePurchases when "Restore Purchases" is tapped', (WidgetTester tester) async {
    final mockService = MockSubscriptionService();

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionService>.value(
        value: mockService,
        child: const MaterialApp(
          home: Scaffold(
            body: PaywallDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final restoreButton = find.text('Restore Purchases');
    expect(restoreButton, findsOneWidget);

    await tester.tap(restoreButton);
    await tester.pump();

    expect(mockService.restorePurchasesCalled, isTrue);
  });

  testWidgets('PaywallDialog auto-pops when user becomes subscribed', (WidgetTester tester) async {
    final mockService = MockSubscriptionService();

    await tester.pumpWidget(
      ChangeNotifierProvider<SubscriptionService>.value(
        value: mockService,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const PaywallDialog(),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Open the dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();
    
    expect(find.byType(PaywallDialog), findsOneWidget);

    // Simulate successful subscription
    mockService.isSubscribed = true;
    mockService.notifyListeners();

    await tester.pumpAndSettle();

    // The dialog should have popped itself
    expect(find.byType(PaywallDialog), findsNothing);
  });
}
