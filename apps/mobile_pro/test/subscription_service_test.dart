import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:castnow_pro/core/subscription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('purchases_flutter');
  const MethodChannel subUtilsChannel = MethodChannel('subscription_utils');

  Map<String, dynamic> mockCustomerInfo = {};

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    SubscriptionService().resetForTesting();
    SubscriptionService.debugForceIOS = false;

    mockCustomerInfo = {
      'entitlements': {
        'all': {},
        'active': {}
      },
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
    
    // Mock the platform channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'setupPurchases') {
        return null;
      }
      if (methodCall.method == 'setLogLevel') {
        return null;
      }
      if (methodCall.method == 'getCustomerInfo') {
        return mockCustomerInfo;
      }
      if (methodCall.method == 'getOfferings') {
        final mockPackage = {
          'identifier': '\$rc_annual',
          'packageType': 'ANNUAL',
          'product': {
            'identifier': 'com.screenshare.castnow.vip.year',
            'description': 'Yearly Premium',
            'title': 'Premium Yearly',
            'price': 22.0,
            'priceString': '\$22.00',
            'currencyCode': 'USD',
          },
          'offeringIdentifier': 'default',
          'presentedOfferingContext': {
            'offeringIdentifier': 'default',
            'placementIdentifier': null,
            'targetingContext': null,
          }
        };
        return {
          'current': {
            'identifier': 'default',
            'serverDescription': 'Default Offering',
            'metadata': {},
            'availablePackages': [mockPackage],
            'annual': mockPackage,
          },
          'all': {
            'default': {
              'identifier': 'default',
              'serverDescription': 'Default Offering',
              'metadata': {},
              'availablePackages': [mockPackage],
              'annual': mockPackage,
            }
          }
        };
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(subUtilsChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getOriginalAppVersion') {
        return '3.0.0'; // Default is non-legacy
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(subUtilsChannel, null);
    SubscriptionService.debugForceIOS = false;
  });

  test('init() completes without crashing', () async {
    final service = SubscriptionService();
    await service.init();
    expect(service, isNotNull);
  });

  test('Normal user without subscription is free', () async {
    SubscriptionService.debugForceIOS = true;
    final service = SubscriptionService();
    await service.init();
    expect(service.isSubscribed, isFalse);
  });

  test('iOS legacy user (build < 15) is migrated and keeps PRO', () async {
    SubscriptionService.debugForceIOS = true;
    
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(subUtilsChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getOriginalAppVersion') {
        return '10'; // build number < 15
      }
      return null;
    });

    final service = SubscriptionService();
    await service.init();

    expect(service.isSubscribed, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('is_legacy_user'), isTrue);
  });

  test('Android legacy user (broadcast_completion_count exists) is migrated and keeps PRO', () async {
    SubscriptionService.debugForceIOS = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('broadcast_completion_count', 5);

    final service = SubscriptionService();
    await service.init();

    expect(service.isSubscribed, isTrue);
    expect(prefs.getBool('is_legacy_user'), isTrue);
  });

  test('Non-legacy user is downgraded if RevenueCat has no active entitlement', () async {
    SubscriptionService.debugForceIOS = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_subscribed', true);

    final service = SubscriptionService();
    await service.init();

    expect(service.isSubscribed, isFalse);
  });

  test('Legacy user is NOT downgraded when RevenueCat has no active entitlement', () async {
    SubscriptionService.debugForceIOS = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_legacy_user', true);
    await prefs.setBool('is_subscribed', true);

    final service = SubscriptionService();
    await service.init();

    expect(service.isSubscribed, isTrue);
  });

  test('isVersionLegacy correctly classifies legacy versions', () {
    final service = SubscriptionService();

    // Legacy
    expect(service.isVersionLegacy('1.0'), isTrue);
    expect(service.isVersionLegacy('1.0.0'), isTrue);
    expect(service.isVersionLegacy('2.5'), isTrue);
    expect(service.isVersionLegacy('2.9.9'), isTrue);
    expect(service.isVersionLegacy('14'), isTrue);
    expect(service.isVersionLegacy(' 1.0.0 '), isTrue);

    // Non-legacy
    expect(service.isVersionLegacy('3.0.1'), isFalse);
    expect(service.isVersionLegacy('15'), isFalse);
    expect(service.isVersionLegacy('4.0.0'), isFalse);
    
    expect(service.isVersionLegacy('3.0.0+15'), isFalse);
    expect(service.isVersionLegacy('3.0.1+16'), isFalse);
    expect(service.isVersionLegacy('3.1.0'), isFalse);
    expect(service.isVersionLegacy('3.1.0+17'), isFalse);
  });

  test('User with "pro" active entitlement is subscribed', () async {
    SubscriptionService.debugForceIOS = true;
    
    mockCustomerInfo['entitlements'] = {
      'all': {
        'pro': {
          'identifier': 'pro',
          'isActive': true,
          'willRenew': true,
          'periodType': 'NORMAL',
          'latestPurchaseDate': '2023-01-01T00:00:00Z',
          'originalPurchaseDate': '2023-01-01T00:00:00Z',
          'expirationDate': '2028-01-01T00:00:00Z',
          'store': 'APP_STORE',
          'productIdentifier': 'com.screenshare.castnow.vip.year',
          'isSandbox': true,
          'unsubscribeDetectedAt': null,
          'billingIssueDetectedAt': null,
        }
      },
      'active': {
        'pro': {
          'identifier': 'pro',
          'isActive': true,
          'willRenew': true,
          'periodType': 'NORMAL',
          'latestPurchaseDate': '2023-01-01T00:00:00Z',
          'originalPurchaseDate': '2023-01-01T00:00:00Z',
          'expirationDate': '2028-01-01T00:00:00Z',
          'store': 'APP_STORE',
          'productIdentifier': 'com.screenshare.castnow.vip.year',
          'isSandbox': true,
          'unsubscribeDetectedAt': null,
          'billingIssueDetectedAt': null,
        }
      }
    };

    final service = SubscriptionService();
    await service.init();
    expect(service.isSubscribed, isTrue);
  });

  test('User with "com.screenshare.castnow.vip.year" active entitlement is subscribed', () async {
    SubscriptionService.debugForceIOS = true;
    
    mockCustomerInfo['entitlements'] = {
      'all': {
        'com.screenshare.castnow.vip.year': {
          'identifier': 'com.screenshare.castnow.vip.year',
          'isActive': true,
          'willRenew': true,
          'periodType': 'NORMAL',
          'latestPurchaseDate': '2023-01-01T00:00:00Z',
          'originalPurchaseDate': '2023-01-01T00:00:00Z',
          'expirationDate': '2028-01-01T00:00:00Z',
          'store': 'APP_STORE',
          'productIdentifier': 'com.screenshare.castnow.vip.year',
          'isSandbox': true,
          'unsubscribeDetectedAt': null,
          'billingIssueDetectedAt': null,
        }
      },
      'active': {
        'com.screenshare.castnow.vip.year': {
          'identifier': 'com.screenshare.castnow.vip.year',
          'isActive': true,
          'willRenew': true,
          'periodType': 'NORMAL',
          'latestPurchaseDate': '2023-01-01T00:00:00Z',
          'originalPurchaseDate': '2023-01-01T00:00:00Z',
          'expirationDate': '2028-01-01T00:00:00Z',
          'store': 'APP_STORE',
          'productIdentifier': 'com.screenshare.castnow.vip.year',
          'isSandbox': true,
          'unsubscribeDetectedAt': null,
          'billingIssueDetectedAt': null,
        }
      }
    };

    final service = SubscriptionService();
    await service.init();
    expect(service.isSubscribed, isTrue);
  });

  test('loadProducts populates annualPackage', () async {
    SubscriptionService.debugForceIOS = true;
    final service = SubscriptionService();
    await service.init();
    
    expect(service.annualPackage, isNotNull);
    expect(service.annualPackage!.identifier, equals('\$rc_annual'));
    expect(service.annualPackage!.storeProduct.priceString, equals('\$22.00'));
  });
}
