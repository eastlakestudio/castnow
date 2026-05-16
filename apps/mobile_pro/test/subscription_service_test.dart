import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:castnow_pro/core/subscription_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'subscription_service_test.mocks.dart';

class MockProductDetails extends ProductDetails {
  MockProductDetails({
    required super.id,
    required super.title,
    required super.description,
    required super.price,
    required super.rawPrice,
    required super.currencyCode,
  });
}

class MockPurchaseDetails extends PurchaseDetails {
  MockPurchaseDetails({
    required super.productID,
    required super.verificationData,
    required super.transactionDate,
    required super.status,
  });
}

@GenerateMocks([InAppPurchase])
void main() {
  late SubscriptionService service;
  late MockInAppPurchase mockIap;
  late StreamController<List<PurchaseDetails>> purchaseStreamController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockIap = MockInAppPurchase();
    purchaseStreamController = StreamController<List<PurchaseDetails>>.broadcast();
    
    when(mockIap.purchaseStream).thenAnswer((_) => purchaseStreamController.stream);
    when(mockIap.isAvailable()).thenAnswer((_) async => true);
    
    SubscriptionService.setMockInstance(mockIap);
    service = SubscriptionService();
  });

  test('init() sets isAvailable and loads products', () async {
    final response = ProductDetailsResponse(
      productDetails: [
        MockProductDetails(
          id: 'year.inapppurchase.castnow.eastlakestudio',
          title: 'Yearly Pro',
          description: 'Pro Subscription',
          price: '\$19.99',
          rawPrice: 19.99,
          currencyCode: 'USD',
        )
      ],
      notFoundIDs: [],
    );
    when(mockIap.queryProductDetails(any)).thenAnswer((_) async => response);

    await service.init();
    
    expect(service.isAvailable, true);
    expect(service.products.length, 1);
    expect(service.products.first.id, 'year.inapppurchase.castnow.eastlakestudio');
  });

  test('buyYearlySubscription() calls InAppPurchase.buyNonConsumable', () async {
    final response = ProductDetailsResponse(
      productDetails: [
        MockProductDetails(
          id: 'year.inapppurchase.castnow.eastlakestudio',
          title: 'Yearly Pro',
          description: 'Pro Subscription',
          price: '\$19.99',
          rawPrice: 19.99,
          currencyCode: 'USD',
        )
      ],
      notFoundIDs: [],
    );
    when(mockIap.queryProductDetails(any)).thenAnswer((_) async => response);
    when(mockIap.buyNonConsumable(purchaseParam: anyNamed('purchaseParam'))).thenAnswer((_) async => true);

    await service.init();
    service.buyYearlySubscription();
    
    expect(service.isPurchasing, true);
    verify(mockIap.buyNonConsumable(purchaseParam: anyNamed('purchaseParam'))).called(1);
  });

  test('Successful purchase updates isSubscribed status', () async {
    when(mockIap.queryProductDetails(any)).thenAnswer((_) async => ProductDetailsResponse(productDetails: [], notFoundIDs: []));
    when(mockIap.completePurchase(any)).thenAnswer((_) async => {});

    await service.init();
    expect(service.isSubscribed, false);

    // Simulate successful purchase
    final purchaseDetails = MockPurchaseDetails(
      productID: 'year.inapppurchase.castnow.eastlakestudio',
      verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: ''),
      transactionDate: '123456789',
      status: PurchaseStatus.purchased,
    );
    purchaseDetails.pendingCompletePurchase = true;
    
    purchaseStreamController.add([purchaseDetails]);
    
    // Allow stream listeners to process
    await Future.delayed(const Duration(milliseconds: 100));
    
    expect(service.isSubscribed, true);
    expect(service.isPurchasing, false);
    verify(mockIap.completePurchase(purchaseDetails)).called(1);
    
    // Check if shared_preferences was updated
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('is_subscribed'), true);
  });
}
