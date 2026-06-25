// revenuecat_service.dart — HalalCalorie v1.0
// RevenueCat wired up (Build 44).
// Requires: purchases_flutter: ^8.0.0 in pubspec
//           RC_GOOGLE_KEY dart-define in CI (secrets.RC_GOOGLE_KEY)
//           RC_APPLE_KEY dart-define in CI (secrets.RC_APPLE_KEY)

import 'package:purchases_flutter/purchases_flutter.dart';

class RCProducts {
  static const monthly  = 'halalcalorie_premium_monthly';
  static const yearly   = 'halalcalorie_premium_yearly';
  static const lifetime = 'halalcalorie_premium_lifetime';
}

class RCConfig {
  // Keys injected at build time via --dart-define
  static const googleApiKey = String.fromEnvironment(
      'RC_GOOGLE_KEY', defaultValue: '');
  static const appleApiKey  = String.fromEnvironment(
      'RC_APPLE_KEY',  defaultValue: '');
  static const entitlementId = 'Halalcalorie Pro';

  static bool get isConfigured =>
      googleApiKey.isNotEmpty || appleApiKey.isNotEmpty;

  static Future<void> configure() async {
    if (!isConfigured) return; // Keys not injected yet — stub mode
    final config = PurchasesConfiguration(
      // Platform selection is handled by purchases_flutter internally;
      // we pass both and the SDK picks the right one at runtime.
      googleApiKey.isNotEmpty ? googleApiKey : appleApiKey,
    );
    await Purchases.configure(config);
  }
}

class PurchaseResult {
  final bool    success;
  final bool    cancelled;
  final String? error;
  const PurchaseResult({
    required this.success,
    this.cancelled = false,
    this.error,
  });
}

class RCOffering {
  final String  identifier;
  final String  titleAr;
  final String  titleEn;
  final String  priceString;
  final String  periodAr;
  final String  periodEn;
  final String? savingsBadgeAr;
  final String? savingsBadgeEn;
  final bool    isPopular;
  // Carries the underlying RC Package for purchase
  final dynamic rcPackage; // Package? — typed as dynamic to avoid
                           //             import leaking into callers

  const RCOffering({
    required this.identifier,
    required this.titleAr, required this.titleEn,
    required this.priceString,
    required this.periodAr, required this.periodEn,
    this.savingsBadgeAr, this.savingsBadgeEn,
    this.isPopular = false,
    this.rcPackage,
  });
}

class RevenueCatService {
  // ── isPremium ─────────────────────────────────────────────────────
  static Future<bool> isPremium() async {
    if (!RCConfig.isConfigured) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active
          .containsKey(RCConfig.entitlementId);
    } catch (_) {
      return false;
    }
  }

  // ── getOfferings ──────────────────────────────────────────────────
  static Future<List<RCOffering>> getOfferings() async {
    if (!RCConfig.isConfigured) return _localStubOfferings();
    try {
      final offerings = await Purchases.getOfferings();
      final current   = offerings.current;
      if (current == null) return _localStubOfferings();

      final result = <RCOffering>[];
      for (final pkg in current.availablePackages) {
        final product   = pkg.storeProduct;
        final id        = pkg.packageType.name.toLowerCase();
        bool   isYearly = id.contains('annual') || id.contains('yearly');
        bool   isLife   = id.contains('lifetime');
        result.add(RCOffering(
          identifier:     product.identifier,
          titleAr:        isLife ? 'مدى الحياة' : isYearly ? 'سنوي' : 'شهري',
          titleEn:        isLife ? 'Lifetime'    : isYearly ? 'Yearly' : 'Monthly',
          priceString:    product.priceString,
          periodAr:       isLife ? 'مرة واحدة' : isYearly ? '/ سنة' : '/ شهر',
          periodEn:       isLife ? 'one-time'   : isYearly ? '/ year' : '/ month',
          savingsBadgeAr: isYearly ? 'وفّر ٣٠٪' : null,
          savingsBadgeEn: isYearly ? 'Save 30%' : null,
          isPopular:      isYearly,
          rcPackage:      pkg,
        ));
      }
      return result.isEmpty ? _localStubOfferings() : result;
    } catch (_) {
      return _localStubOfferings();
    }
  }

  // ── purchase ──────────────────────────────────────────────────────
  static Future<PurchaseResult> purchase(RCOffering offering) async {
    if (!RCConfig.isConfigured) {
      return const PurchaseResult(
          success: false,
          error: 'RevenueCat key not configured — rebuild with RC_GOOGLE_KEY secret');
    }
    try {
      if (offering.rcPackage == null) {
        return const PurchaseResult(
            success: false, error: 'Package data unavailable — refresh offerings');
      }
      final info = await Purchases.purchasePackage(
          offering.rcPackage as Package);
      final active = info.entitlements.active
          .containsKey(RCConfig.entitlementId);
      return PurchaseResult(success: active);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return const PurchaseResult(success: false, cancelled: true);
      }
      return PurchaseResult(success: false, error: e.toString());
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('userCancelled') ||
          msg.contains('PurchaseCancelledError') ||
          msg.contains('USER_CANCELED')) {
        return const PurchaseResult(success: false, cancelled: true);
      }
      return PurchaseResult(success: false, error: msg);
    }
  }

  // ── restore ───────────────────────────────────────────────────────
  static Future<PurchaseResult> restore() async {
    if (!RCConfig.isConfigured) {
      return const PurchaseResult(
          success: false, error: 'RevenueCat key not configured');
    }
    try {
      final info   = await Purchases.restorePurchases();
      final active = info.entitlements.active
          .containsKey(RCConfig.entitlementId);
      return PurchaseResult(success: active,
          error: active ? null : 'No active subscription found');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('userCancelled') ||
          msg.contains('PurchaseCancelledError') ||
          msg.contains('USER_CANCELED')) {
        return const PurchaseResult(success: false, cancelled: true);
      }
      return PurchaseResult(success: false, error: msg);
    }
  }

  // ── helpers ───────────────────────────────────────────────────────
  static Future<void> setUserId(String userId) async {
    if (!RCConfig.isConfigured) return;
    try { await Purchases.logIn(userId); } catch (_) {}
  }

  static Future<void> logOut() async {
    if (!RCConfig.isConfigured) return;
    try { await Purchases.logOut(); } catch (_) {}
  }

  static Future<String> getActivePlanId() async {
    if (!RCConfig.isConfigured) return 'free';
    try {
      final info = await Purchases.getCustomerInfo();
      final ent  = info.entitlements.active[RCConfig.entitlementId];
      return ent?.productIdentifier ?? 'free';
    } catch (_) { return 'free'; }
  }

  // ── local stub (shown when RC key not yet configured) ─────────────
  static List<RCOffering> _localStubOfferings() => const [
    RCOffering(
      identifier:  RCProducts.monthly,
      titleAr: 'شهري',   titleEn: 'Monthly',
      priceString: 'EGP 99',
      periodAr: '/ شهر', periodEn: '/ month',
    ),
    RCOffering(
      identifier:  RCProducts.yearly,
      titleAr: 'سنوي',   titleEn: 'Yearly',
      priceString: 'EGP 799',
      periodAr: '/ سنة', periodEn: '/ year',
      savingsBadgeAr: 'وفّر ٣٠٪',
      savingsBadgeEn: 'Save 30%',
      isPopular: true,
    ),
    RCOffering(
      identifier:  RCProducts.lifetime,
      titleAr: 'مدى الحياة', titleEn: 'Lifetime',
      priceString: 'EGP 1,999',
      periodAr: 'مرة واحدة', periodEn: 'one-time',
    ),
  ];
}
