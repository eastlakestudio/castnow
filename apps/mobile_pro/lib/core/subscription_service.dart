import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();

  factory SubscriptionService() {
    return _instance;
  }

  @visibleForTesting
  static void setMockInstance(InAppPurchase mockInAppPurchase) {
    _instance._inAppPurchaseMock = mockInAppPurchase;
  }

  SubscriptionService._internal();

  InAppPurchase? _inAppPurchaseMock;
  InAppPurchase get _inAppPurchase => _inAppPurchaseMock ?? InAppPurchase.instance;
  
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isAvailable = false;
  bool _isSubscribed = false;
  bool _isPurchasing = false;
  
  List<ProductDetails> _products = [];
  String? _errorMessage;

  static const String _yearlySubscriptionId = 'year.inapppurchase.castnow.eastlakestudio';
  static const String _prefIsSubscribedKey = 'is_subscribed';

  bool get isSubscribed => _isSubscribed;
  
  bool get isAvailable => _isAvailable;
  bool get isPurchasing => _isPurchasing;
  List<ProductDetails> get products => _products;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    if (!_isAvailable) {
      debugPrint('In-App Purchases are not available.');
      _errorMessage = 'In-App Purchases are not available on this device.';
      notifyListeners();
      return;
    }

    // Load cached status immediately
    await _loadCachedSubscriptionStatus();

    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint('Purchase stream error: $error');
    });

    // Fire and forget loading products so it doesn't block app startup
    loadProducts();
  }

  Future<void> loadProducts() async {
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_yearlySubscriptionId});
    
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }

    if (response.error != null) {
      debugPrint('Error loading products: ${response.error!.message}');
      _errorMessage = response.error!.message;
    }

    _products = response.productDetails;
    notifyListeners();
  }

  static const MethodChannel _platform = MethodChannel('subscription_utils');

  Future<void> _loadCachedSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Check if user already got a subscription
    final hasSubscriptionKey = prefs.containsKey(_prefIsSubscribedKey);
    if (hasSubscriptionKey) {
      _isSubscribed = prefs.getBool(_prefIsSubscribedKey) ?? false;
      notifyListeners();
      return;
    }

    // 2. Legacy user migration (StoreKit App Transaction for iOS Paid App purchasers)
    bool isLegacyBuyer = false;
    try {
      if (Platform.isIOS) {
        final String? originalVersion = await _platform.invokeMethod<String>('getOriginalAppVersion');
        if (originalVersion != null) {
          // In iOS, originalAppVersion is usually CFBundleVersion (the build number, e.g., '12' from 2.0.2+12)
          // Any build number before 15 (our 3.0 freemium update) is considered a paid legacy user.
          if (originalVersion == "1.0") {
             // Sandbox receipt sometimes returns "1.0"
             isLegacyBuyer = true; 
          } else if (int.tryParse(originalVersion) != null) {
            final buildNum = int.parse(originalVersion);
            if (buildNum < 15) {
              isLegacyBuyer = true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to get original app version: $e');
    }

    // Fallback heuristic: if they have old preferences and no subscription key yet, grant them PRO
    if (!isLegacyBuyer && prefs.containsKey('broadcast_completion_count')) {
      isLegacyBuyer = true;
    }

    if (isLegacyBuyer) {
      debugPrint('Legacy user detected. Upgrading to PRO automatically.');
      await prefs.setBool(_prefIsSubscribedKey, true);
      _isSubscribed = true;
    } else {
      _isSubscribed = false;
    }
    
    notifyListeners();
  }

  Future<void> _setSubscribed(bool status) async {
    _isSubscribed = status;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsSubscribedKey, status);
    notifyListeners();
  }

  void buyYearlySubscription() {
    if (_products.isEmpty) {
      debugPrint('No products available to buy.');
      return;
    }
    _isPurchasing = true;
    notifyListeners();
    
    final ProductDetails productDetails = _products.firstWhere((element) => element.id == _yearlySubscriptionId);
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Using buyNonConsumable since subscriptions are non-consumable for standard integration without server verification
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void restorePurchases() {
    _isPurchasing = true;
    notifyListeners();
    _inAppPurchase.restorePurchases();
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isPurchasing = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
          _errorMessage = purchaseDetails.error?.message;
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            await _setSubscribed(true);
            debugPrint('Successfully purchased/restored subscription.');
          } else {
            debugPrint('Purchase verification failed.');
          }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        
        _isPurchasing = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // In a real app, you would send purchaseDetails.verificationData to your server.
    // For this implementation, we assume if it got this far from Apple, it's valid locally.
    return true;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
