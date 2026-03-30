// ============================================================
//  donation_service.dart — HalalCalorie
//  One-time "Sadaqah Jariyah" donation support button
// ============================================================
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';

class DonationService {
  // Product IDs — create these in Google Play Console
  static const _donations = [
    'donation_5',   // 5 USD / ~250 EGP
    'donation_10',  // 10 USD / ~500 EGP
    'donation_20',  // 20 USD / ~1000 EGP
  ];

  static Future<List<StoreProduct>> getProducts() async {
    try {
      final products = await Purchases.getProducts(
        _donations,
        productCategory: ProductCategory.nonSubscription,
      );
      return products;
    } catch (e) {
      debugPrint('Donation products error: \$e');
      return [];
    }
  }

  static Future<bool> donate(StoreProduct product) async {
    try {
      final result = await Purchases.purchaseStoreProduct(product);
      return result.customerInfo.nonSubscriptionTransactions.isNotEmpty;
    } catch (e) {
      debugPrint('Donation error: \$e');
      return false;
    }
  }
}
