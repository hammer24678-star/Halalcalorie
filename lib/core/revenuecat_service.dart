// revenuecat_service.dart — HalalCalorie v1.0
// Full RevenueCat interface — native package activated when key is ready
// To restore: add purchases_flutter: ^8.0.0 to pubspec + real keys below

class RCProducts {
  static const monthly  = 'halalcalorie_premium_monthly';
  static const yearly   = 'halalcalorie_premium_yearly';
  static const lifetime = 'halalcalorie_premium_lifetime';
}

class RCConfig {
  static const appleApiKey  = 'appl_REPLACE_WITH_YOUR_APPLE_KEY';
  static const googleApiKey = 'goog_REPLACE_WITH_YOUR_GOOGLE_KEY';
  static const entitlementId = 'premium_access';
  static const offeringId    = 'default';

  static Future<void> configure() async {
    // Activated when real keys are added + purchases_flutter restored
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

  const RCOffering({
    required this.identifier,
    required this.titleAr, required this.titleEn,
    required this.priceString,
    required this.periodAr, required this.periodEn,
    this.savingsBadgeAr, this.savingsBadgeEn,
    this.isPopular = false,
  });
}

class RevenueCatService {
  static Future<bool> isPremium() async => false;

  static Future<List<RCOffering>> getOfferings() async => [
    const RCOffering(
      identifier: RCProducts.monthly,
      titleAr: 'شهري', titleEn: 'Monthly',
      priceString: 'EGP 99',
      periodAr: '/ شهر', periodEn: '/ month',
    ),
    const RCOffering(
      identifier: RCProducts.yearly,
      titleAr: 'سنوي', titleEn: 'Yearly',
      priceString: 'EGP 799',
      periodAr: '/ سنة', periodEn: '/ year',
      savingsBadgeAr: 'وفّر ٣٠٪',
      savingsBadgeEn: 'Save 30%',
      isPopular: true,
    ),
    const RCOffering(
      identifier: RCProducts.lifetime,
      titleAr: 'مدى الحياة', titleEn: 'Lifetime',
      priceString: 'EGP 1,999',
      periodAr: 'مرة واحدة', periodEn: 'one-time',
    ),
  ];

  static Future<PurchaseResult> purchase(RCOffering offering) async =>
      const PurchaseResult(success: false, error: 'RevenueCat not configured yet');

  static Future<PurchaseResult> restore() async =>
      const PurchaseResult(success: false, error: 'RevenueCat not configured yet');

  static Future<void> setUserId(String userId) async {}
  static Future<void> logOut() async {}
  static Future<String> getActivePlanId() async => 'free';
}
