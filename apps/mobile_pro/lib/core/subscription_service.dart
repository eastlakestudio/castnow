import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'revenuecat_config.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();

  factory SubscriptionService() {
    return _instance;
  }

  SubscriptionService._internal();

  bool _isAvailable = false;
  bool _isSubscribed = false;
  bool _isPurchasing = false;
  
  List<Package> _products = [];
  Package? _annualPackage;
  StoreProduct? _localStoreProduct;
  String? _errorMessage;

  static const String _prefIsSubscribedKey = 'is_subscribed';
  static const String _prefIsLegacyUserKey = 'is_legacy_user';

  @visibleForTesting
  static bool debugForceIOS = false;

  bool get _isIOS => debugForceIOS || Platform.isIOS || Platform.isMacOS;
  bool get _isAndroid => !debugForceIOS && Platform.isAndroid;

  bool get isSubscribed => _isSubscribed;
  bool get isAvailable => _isAvailable;
  bool get isPurchasing => _isPurchasing;
  List<Package> get products => _products;
  Package? get annualPackage => _annualPackage;
  StoreProduct? get localStoreProduct => _localStoreProduct;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    // 1. Load cached status immediately to unblock app logic
    await _loadCachedSubscriptionStatus();

    // 2. Initial RevenueCat Configuration
    await Purchases.setLogLevel(LogLevel.debug);
    
    PurchasesConfiguration? configuration;
    if (_isIOS) {
      configuration = PurchasesConfiguration(RevenueCatConfig.appleApiKey);
    } else if (_isAndroid && RevenueCatConfig.googleApiKey.isNotEmpty) {
      configuration = PurchasesConfiguration(RevenueCatConfig.googleApiKey);
    }
    
    if (configuration != null) {
      await Purchases.configure(configuration);
      _isAvailable = true;
    } else {
      _isAvailable = false;
      _errorMessage = "RevenueCat configuration failed or API key missing.";
      debugPrint("SubscriptionService Error: $_errorMessage");
      notifyListeners();
      return;
    }
    
    // 3. Setup Listener for future customer info changes
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _updateSubscriptionStatus(customerInfo);
    });

    // 4. Fetch Products/Offerings
    await loadProducts();
    
    // 5. Fetch fresh customer info to update from RevenueCat server
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      await _updateSubscriptionStatus(customerInfo);
    } catch (e) {
      debugPrint("Failed to get initial customer info: $e");
    }
  }

  Future<void> loadProducts() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      Offering? activeOffering = offerings.current;
      
      // Fallback: If no current offering is set, use the first one from offerings.all (e.g. 'castnow')
      if (activeOffering == null && offerings.all.isNotEmpty) {
        activeOffering = offerings.all.values.first;
        debugPrint("Current offering is null. Falling back to first offering: ${activeOffering.identifier}");
      }

      if (activeOffering != null) {
        _annualPackage = activeOffering.annual;
        _products = activeOffering.availablePackages;
        if (_annualPackage == null && _products.isNotEmpty) {
          _annualPackage = _products.first;
        }
        if (_products.isEmpty) {
          _errorMessage = "No products found in the current offering.";
        }
      } else {
        _errorMessage = "No products found in the current offering.";
      }
      
      // Fallback: If offerings are empty, fetch product directly from local StoreKit configuration
      if (_annualPackage == null) {
        debugPrint("[SubscriptionService] Offerings are empty. Attempting fallback to fetch product directly from local StoreKit for ID: ${RevenueCatConfig.entitlementID}...");
        final products = await Purchases.getProducts([RevenueCatConfig.entitlementID]);
        debugPrint("[SubscriptionService] getProducts returned ${products.length} products.");
        if (products.isNotEmpty) {
          _localStoreProduct = products.first;
          debugPrint("[SubscriptionService] Found product in local StoreKit: ${_localStoreProduct!.identifier} (${_localStoreProduct!.priceString})");
        } else {
          debugPrint("[SubscriptionService] No products returned from getProducts for ${RevenueCatConfig.entitlementID}.");
        }
      }
    } on PlatformException catch (e) {
      _errorMessage = e.message;
      debugPrint("[SubscriptionService] Error loading offerings: ${e.message} (code: ${e.code}, details: ${e.details})");
      
      // Fallback on error as well
      try {
        debugPrint("[SubscriptionService] Attempting fallback to fetch product directly from local StoreKit on error...");
        final products = await Purchases.getProducts([RevenueCatConfig.entitlementID]);
        debugPrint("[SubscriptionService] getProducts on error fallback returned ${products.length} products.");
        if (products.isNotEmpty) {
          _localStoreProduct = products.first;
          debugPrint("[SubscriptionService] Found product in local StoreKit on error fallback: ${_localStoreProduct!.identifier} (${_localStoreProduct!.priceString})");
        }
      } catch (err) {
        debugPrint("[SubscriptionService] Failed to fetch product on error fallback: $err");
      }
    }
    notifyListeners();
  }

  Future<void> _loadCachedSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if already flagged as a legacy user
    final isLegacy = prefs.getBool(_prefIsLegacyUserKey) ?? false;
    if (isLegacy) {
      _isSubscribed = true;
      notifyListeners();
      return;
    }

    // Check local pref first
    final hasSubscriptionKey = prefs.containsKey(_prefIsSubscribedKey);
    if (hasSubscriptionKey) {
      _isSubscribed = prefs.getBool(_prefIsSubscribedKey) ?? false;
      notifyListeners();
      return;
    }

    _isSubscribed = false;
    notifyListeners();
  }

  @visibleForTesting
  bool isVersionLegacy(String version) {
    version = version.trim();
    if (version == "1.0") return true;

    final intVersion = int.tryParse(version);
    if (intVersion != null) {
      return intVersion < 15;
    }

    // Split version by '.' (e.g., "1.0.0", "2.1")
    final parts = version.split('.');
    try {
      if (parts.isNotEmpty) {
        final major = int.tryParse(parts[0]);
        if (major != null && major < 3) {
          return true; // Any major version < 3 is legacy (e.g. 1.x.x, 2.x.x)
        }
      }
    } catch (e) {
      debugPrint('Error parsing version: $e');
    }
    return false;
  }

  Future<void> _updateSubscriptionStatus(CustomerInfo customerInfo) async {
    debugPrint("[SubscriptionService] _updateSubscriptionStatus called.");
    debugPrint("[SubscriptionService] Active Subscriptions: ${customerInfo.activeSubscriptions}");
    debugPrint("[SubscriptionService] All Purchased Product IDs: ${customerInfo.allPurchasedProductIdentifiers}");
    
    final entitlements = customerInfo.entitlements.all;
    debugPrint("[SubscriptionService] Entitlements count: ${entitlements.length}");
    entitlements.forEach((key, entitlementInfo) {
      debugPrint("[SubscriptionService] Entitlement: '$key', isActive: ${entitlementInfo.isActive}, productIdentifier: ${entitlementInfo.productIdentifier}");
    });

    bool isPremiumActive = false;
    // 支持用户指定的所有四种产品/权益 ID 的检测
    final activeEntitlementKeys = ["pro", "com.screenshare.castnow.vip.year", "lifetime", "yearly", "monthly"];
    for (var key in activeEntitlementKeys) {
      if (entitlements[key]?.isActive == true) {
        isPremiumActive = true;
        debugPrint("[SubscriptionService] Premium is active via entitlement: $key");
        break;
      }
    }

    // 2. 检查 iOS 上的原始购买版本（Legacy 升级逻辑 - 纯 Dart 无 MethodChannel 方案）
    if (!isPremiumActive && customerInfo.originalApplicationVersion != null) {
      final originalVersion = customerInfo.originalApplicationVersion!;
      if (isVersionLegacy(originalVersion)) {
        isPremiumActive = true;
        debugPrint("[SubscriptionService] Legacy user detected via originalApplicationVersion: $originalVersion. Upgrading to PRO.");
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefIsLegacyUserKey, true);
      }
    }
    
    if (isPremiumActive) {
      debugPrint("[SubscriptionService] Setting subscription status to TRUE.");
      await _setSubscribed(true);
    } else {
      debugPrint("[SubscriptionService] Premium is not active. Checking if we should downgrade...");
      // Don't downgrade legacy users who got it via local pref checks
      await _checkIfShouldDowngrade();
    }
  }

  Future<void> _checkIfShouldDowngrade() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefIsLegacyUserKey) == true) {
      // It's a legacy user, keep them subscribed
      return;
    }
    await _setSubscribed(false);
  }

  Future<void> _setSubscribed(bool status) async {
    _isSubscribed = status;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefIsSubscribedKey, status);
    notifyListeners();
  }

  Future<void> buyYearlySubscription() async {
    debugPrint("[SubscriptionService] buyYearlySubscription initiated.");
    _isPurchasing = true;
    _errorMessage = null;
    notifyListeners();

    final packageToBuy = _annualPackage;
    debugPrint("[SubscriptionService] buyYearlySubscription: _annualPackage is ${packageToBuy != null ? 'NOT null' : 'null'}");
    debugPrint("[SubscriptionService] buyYearlySubscription: _localStoreProduct is ${_localStoreProduct != null ? _localStoreProduct!.identifier : 'null'}");

    if (packageToBuy == null) {
      if (_localStoreProduct != null) {
        debugPrint('[SubscriptionService] Purchasing via local StoreProduct directly from StoreKit: ${_localStoreProduct!.identifier}');
        try {
          PurchaseResult purchaseResult = await Purchases.purchaseStoreProduct(_localStoreProduct!);
          debugPrint('[SubscriptionService] purchaseStoreProduct call returned PurchaseResult.');
          await _updateSubscriptionStatus(purchaseResult.customerInfo);
          debugPrint('[SubscriptionService] Successfully purchased local StoreProduct.');
        } on PlatformException catch (e) {
          var errorCode = PurchasesErrorHelper.getErrorCode(e);
          debugPrint('[SubscriptionService] purchaseStoreProduct Exception caught: '
              'code=${e.code}, message=${e.message}, details=${e.details}, errorCode=$errorCode');
          if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
            _errorMessage = e.message;
          } else {
            debugPrint('[SubscriptionService] Purchase was cancelled by the user.');
          }
        } finally {
          _isPurchasing = false;
          notifyListeners();
        }
        return;
      }

      // Local Debug Fallback: Simulate purchase on simulator if RevenueCat offerings are not configured
      debugPrint('[SubscriptionService] RevenueCat package and local StoreProduct are null. Simulating successful purchase.');
      await Future.delayed(const Duration(milliseconds: 1500));
      await _setSubscribed(true);
      _isPurchasing = false;
      notifyListeners();
      return;
    }
    
    try {
      debugPrint('[SubscriptionService] Purchasing RevenueCat package: ${packageToBuy.identifier}');
      PurchaseResult purchaseResult = await Purchases.purchasePackage(packageToBuy);
      debugPrint('[SubscriptionService] purchasePackage call returned PurchaseResult.');
      await _updateSubscriptionStatus(purchaseResult.customerInfo);
      debugPrint('[SubscriptionService] Successfully purchased package.');
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('[SubscriptionService] purchasePackage Exception caught: '
          'code=${e.code}, message=${e.message}, details=${e.details}, errorCode=$errorCode');
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        _errorMessage = e.message;
      } else {
        debugPrint('[SubscriptionService] Purchase was cancelled by the user.');
      }
    } finally {
      _isPurchasing = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    debugPrint("[SubscriptionService] restorePurchases initiated.");
    _isPurchasing = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Local Debug Fallback: If in simulator and offerings empty, simulate restore
      if (_annualPackage == null) {
        debugPrint('[SubscriptionService] RevenueCat package is null. Simulating successful restore for local debugging.');
        await Future.delayed(const Duration(milliseconds: 1000));
        await _setSubscribed(true);
        _isPurchasing = false;
        notifyListeners();
        return;
      }

      debugPrint('[SubscriptionService] Calling Purchases.restorePurchases()...');
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      debugPrint('[SubscriptionService] restorePurchases call returned CustomerInfo.');
      await _updateSubscriptionStatus(customerInfo);
      
      final entitlements = customerInfo.entitlements.all;
      bool isPremiumActive = (entitlements["pro"]?.isActive == true) || 
                            (entitlements["com.screenshare.castnow.vip.year"]?.isActive == true);
      if (!isPremiumActive) {
        _errorMessage = "No active subscription found to restore.";
        debugPrint('[SubscriptionService] Restore complete but no active entitlements found.');
      } else {
        debugPrint('[SubscriptionService] Successfully restored active purchases.');
      }
    } on PlatformException catch (e) {
      _errorMessage = e.message;
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      debugPrint('[SubscriptionService] Restore error Exception caught: '
          'code=${e.code}, message=${e.message}, details=${e.details}, errorCode=$errorCode');
    } finally {
      _isPurchasing = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _isAvailable = false;
    _isSubscribed = false;
    _isPurchasing = false;
    _products = [];
    _localStoreProduct = null;
    _errorMessage = null;
  }

  @override
  void dispose() {
    // In RevenueCat, listeners are generally static or handled differently,
    // but we'll leave this here for consistency with ChangeNotifier.
    super.dispose();
  }
}
