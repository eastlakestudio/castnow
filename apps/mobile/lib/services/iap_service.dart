import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class IAPService {
  static const String kUnlimitedProductId = 'unlimited.castnow.eastlakestudio.com';
  static const String kProStatusKey = 'is_pro_version';

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isPro = false;

  bool get isPro => _isPro;
  List<ProductDetails> get products => _products;

  final _proStatusController = StreamController<bool>.broadcast();
  Stream<bool> get proStatusStream => _proStatusController.stream;

  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  Future<void> initialize() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) return;

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint("IAP Error: $error");
    });

    await loadProStatus();
    await _checkLegacyVersion();
    await queryProducts();
    
    // Note: In a real app, you should also call restorePurchases() 
    // or handle past purchases on startup more robustly.
  }

  Future<void> loadProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(kProStatusKey) ?? false;
    _proStatusController.add(_isPro);
  }

  Future<void> queryProducts() async {
    if (!_isAvailable) return;
    
    const Set<String> ids = {kUnlimitedProductId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);
    
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint("Products not found: ${response.notFoundIDs}");
    }
    
    _products = response.productDetails;
  }

  Future<void> buyUnlimited() async {
    if (_products.isEmpty) {
      await queryProducts();
    }
    
    if (_products.isEmpty) {
      throw Exception("Product not found");
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: _products.first);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint("Purchase Error: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          _verifyPurchase(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _checkLegacyVersion() async {
    final prefs = await SharedPreferences.getInstance();
    // If already checked or already Pro, skip
    if (prefs.getBool('legacy_pro_checked') ?? false) return;
    if (_isPro) {
      await prefs.setBool('legacy_pro_checked', true);
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;

      // Logic: Grant Pro if version is 1.0.1 or earlier.
      // Assuming version strings like "1.0.1", "1.0.0", "0.9.0" etc.
      bool isLegacy = false;
      final parts = version.split('.');
      if (parts.isNotEmpty) {
        int major = int.tryParse(parts[0]) ?? 0;
        int minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        int patch = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

        if (major < 1) {
          isLegacy = true;
        } else if (major == 1 && minor == 0) {
          if (patch <= 1) {
            isLegacy = true;
          }
        }
      }

      if (isLegacy) {
        debugPrint("Legacy user detected (v$version). Granting Pro status.");
        _isPro = true;
        await prefs.setBool(kProStatusKey, true);
        _proStatusController.add(true);
      }
      
      await prefs.setBool('legacy_pro_checked', true);
    } catch (e) {
      debugPrint("Error checking legacy version: $e");
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // In a production app, you should verify the receipt on your server.
    // For this simple version, we'll trust the device notification for the 'unlimited' ID.
    if (purchaseDetails.productID == kUnlimitedProductId) {
      _isPro = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kProStatusKey, true);
      _proStatusController.add(true);
    }
  }

  void dispose() {
    _subscription.cancel();
    _proStatusController.close();
  }
}
