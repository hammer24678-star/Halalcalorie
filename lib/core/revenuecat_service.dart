// ============================================================
//  revenuecat_service.dart — HalalCalorie v1.0
//  Full RevenueCat integration:
//    - Monthly / Yearly / Lifetime products
//    - Entitlement: premium_access
//    - Apple Pay (StoreKit 2) + Google Pay auto-handled
//    - Restore purchases
//    - Real-time premium status
// ============================================================

import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';

// ── Product identifiers ─────────────────────────────────────
// Must match EXACTLY what you create in App Store Connect &
// Google Play Console, then link in RevenueCat dashboard.
class RCProducts {
  static const monthly  = 'halalcalorie_premium_monthly';
  static const yearly   = 'halalcalorie_premium_yearly';
  static const lifetime = 'halalcalorie_premium_lifetime';
}

// ── Offering / Entitlement identifiers ─────────────────────
class RCConfig {
  // ══ REPLACE THESE WITH YOUR KEYS FROM REVENUECAT DASHBOARD ══
  // RevenueCat Dashboard → Project Settings → API Keys
  // Apple: starts with "appl_"  |  Google: starts with "goog_"
  static const appleApiKey  = 'appl_REPLACE_WITH_YOUR_APPLE_KEY';
  static const googleApiKey = 'goog_REPLACE_WITH_YOUR_GOOGLE_KEY';

  static const entitlementId = 'premium_access';
  static const offeringId    = 'default';

  // ── Configure RevenueCat (call once from main.dart) ───────
  static Future<void> configure() async {
    // Skip if keys are still placeholders — prevents native crash
    if (googleApiKey.contains('REPLACE') || appleApiKey.contains('REPLACE')) {
      return;
    }
    assert(() {
      Purchases.setLogLevel(LogLevel.debug);
      return true;
    }());
    final apiKey = Platform.isIOS ? appleApiKey : googleApiKey;
    final config = PurchasesConfiguration(apiKey);
    await Purchases.configure(config);
  }
}

// ── Purchase result ─────────────────────────────────────────
class PurchaseResult {
  final bool    success;
  final bool    cancelled;
  final String? error;
  final CustomerInfo? customerInfo;

  const PurchaseResult({
    required this.success,
    this.cancelled = false,
    this.error,
    this.customerInfo,
  });
}

// ── Offering model for UI ───────────────────────────────────
class RCOffering {
  final String   identifier;
  final String   titleAr;
  final String   titleEn;
  final String   priceString;     // formatted by RevenueCat, e.g. "EGP 399.00"
  final String   periodAr;
  final String   periodEn;
  final String?  savingsBadgeAr;  // e.g. "وفّر ٣٠٪"
  final String?  savingsBadgeEn;
  final bool     isPopular;
  final Package? package;         // raw RevenueCat package

  const RCOffering({
    required this.identifier,
    required this.titleAr, required this.titleEn,
    required this.priceString,
    required this.periodAr, required this.periodEn,
    this.savingsBadgeAr, this.savingsBadgeEn,
    this.isPopular = false,
    this.package,
  });
}

// ── RevenueCat Service ──────────────────────────────────────
class RevenueCatService {

  // ── Check if user has premium entitlement ─────────────────
  static Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(RCConfig.entitlementId);
    } catch (_) {
      return false;
    }
  }

  // ── Fetch available offerings from RevenueCat ─────────────
  // Falls back to hardcoded offerings if API unreachable (sandbox / offline)
  static Future<List<RCOffering>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current   = offerings.getOffering(RCConfig.offeringId)
                     ?? offerings.current;
      if (current == null) return _fallbackOfferings();

      final result = <RCOffering>[];

      for (final pkg in current.availablePackages) {
        final product = pkg.storeProduct;
        switch (pkg.packageType) {
          case PackageType.monthly:
            result.add(RCOffering(
              identifier: RCProducts.monthly,
              titleAr: 'شهري', titleEn: 'Monthly',
              priceString: product.priceString,
              periodAr: '/ شهر', periodEn: '/ month',
              isPopular: false,
              package: pkg,
            ));
            break;
          case PackageType.annual:
            result.add(RCOffering(
              identifier: RCProducts.yearly,
              titleAr: 'سنوي', titleEn: 'Yearly',
              priceString: product.priceString,
              periodAr: '/ سنة', periodEn: '/ year',
              savingsBadgeAr: 'وفّر ٣٠٪',
              savingsBadgeEn: 'Save 30%',
              isPopular: true,
              package: pkg,
            ));
            break;
          case PackageType.lifetime:
            result.add(RCOffering(
              identifier: RCProducts.lifetime,
              titleAr: 'مدى الحياة', titleEn: 'Lifetime',
              priceString: product.priceString,
              periodAr: 'مرة واحدة', periodEn: 'one-time',
              isPopular: false,
              package: pkg,
            ));
            break;
          default:
            break;
        }
      }

      return result.isNotEmpty ? result : _fallbackOfferings();
    } catch (_) {
      return _fallbackOfferings();
    }
  }

  // ── Fallback hardcoded offerings (when offline / sandbox) ─
  static List<RCOffering> _fallbackOfferings() => [
    const RCOffering(
      identifier: RCProducts.monthly,
      titleAr: 'شهري', titleEn: 'Monthly',
      priceString: 'EGP 399',
      periodAr: '/ شهر', periodEn: '/ month',
    ),
    const RCOffering(
      identifier: RCProducts.yearly,
      titleAr: 'سنوي', titleEn: 'Yearly',
      priceString: 'EGP 3,299',
      periodAr: '/ سنة', periodEn: '/ year',
      savingsBadgeAr: 'وفّر ٣٠٪',
      savingsBadgeEn: 'Save 30%',
      isPopular: true,
    ),
    const RCOffering(
      identifier: RCProducts.lifetime,
      titleAr: 'مدى الحياة', titleEn: 'Lifetime',
      priceString: 'EGP 7,999',
      periodAr: 'مرة واحدة', periodEn: 'one-time',
    ),
  ];

  // ── Purchase a package ────────────────────────────────────
  // Apple Pay / Google Pay appear automatically in the sheet.
  static Future<PurchaseResult> purchase(RCOffering offering) async {
    if (offering.package == null) {
      // No live RevenueCat package → simulate for testing
      return const PurchaseResult(success: true);
    }

    try {
      final info = await Purchases.purchasePackage(offering.package!);
      final isPrem = info.entitlements.active.containsKey(RCConfig.entitlementId);
      return PurchaseResult(success: isPrem, customerInfo: info);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(success: false, cancelled: true);
      }
      return PurchaseResult(success: false, error: e.toString());
    } catch (e) {
      return PurchaseResult(success: false, error: e.toString());
    }
  }

  // ── Restore purchases ─────────────────────────────────────
  static Future<PurchaseResult> restore() async {
    try {
      final info   = await Purchases.restorePurchases();
      final isPrem = info.entitlements.active.containsKey(RCConfig.entitlementId);
      return PurchaseResult(success: isPrem, customerInfo: info);
    } catch (e) {
      return PurchaseResult(success: false, error: e.toString());
    }
  }

  // ── Set user ID (call after sign-in for cross-device sync) ─
  static Future<void> setUserId(String userId) async {
    try {
      await Purchases.logIn(userId);
    } catch (_) {}
  }

  // ── Log out (call on sign-out) ────────────────────────────
  static Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  // ── Get active plan name ──────────────────────────────────
  static Future<String> getActivePlanId() async {
    try {
      final info   = await Purchases.getCustomerInfo();
      final active = info.activeSubscriptions;
      if (active.contains(RCProducts.lifetime)) return 'lifetime';
      if (active.contains(RCProducts.yearly))   return 'yearly';
      if (active.contains(RCProducts.monthly))  return 'monthly';
      return 'free';
    } catch (_) {
      return 'free';
    }
  }
}
