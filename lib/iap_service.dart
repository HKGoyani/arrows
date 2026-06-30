import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'analytics_service.dart';
import 'prefs.dart';

/// In-app purchase: "Remove Ads" non-consumable.
class IapService {
  static const String removeAdsId = 'remove_ads';

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static ProductDetails? _removeAdsProduct;
  static bool _available = false;

  static bool get available => _available;
  static String get priceText => _removeAdsProduct?.price ?? '\$3.99';

  /// Call once at app startup.
  static Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate, onDone: () {
      _sub?.cancel();
    }, onError: (_) {});

    final response = await _iap.queryProductDetails({removeAdsId});
    if (response.productDetails.isNotEmpty) {
      _removeAdsProduct = response.productDetails.first;
    }
  }

  /// Starts the purchase flow. Result arrives via the purchase stream.
  static Future<void> buyRemoveAds() async {
    if (!_available || _removeAdsProduct == null) return;
    final param = PurchaseParam(productDetails: _removeAdsProduct!);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Restores previous purchases (App Store / Play Store).
  static Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  static void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID == removeAdsId) {
        if (p.status == PurchaseStatus.purchased) {
          AnalyticsService.purchaseRemoveAds(); // new purchase only, not restore
          Prefs.setRemoveAds(true);
        } else if (p.status == PurchaseStatus.restored) {
          Prefs.setRemoveAds(true);
        }
      }
      if (p.pendingCompletePurchase) {
        _iap.completePurchase(p);
      }
    }
  }

  static void dispose() {
    _sub?.cancel();
  }
}
