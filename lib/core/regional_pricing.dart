// regional_pricing.dart — HalalCalorie v1.0
// Regional pricing logic — RevenueCat activated when key is ready

class RegionalPricing {
  // Egypt pricing
  static const egyptMonthly  = 'EGP 99';
  static const egyptYearly   = 'EGP 799';
  static const egyptLifetime = 'EGP 1,999';

  // Gulf / international pricing
  static const gulfMonthly  = '\$4.99';
  static const gulfYearly   = '\$34.99';
  static const gulfLifetime = '\$99.99';

  static bool isEgypt(String? countryCode) =>
      countryCode?.toUpperCase() == 'EG';

  static String monthlyPrice(String? countryCode) =>
      isEgypt(countryCode) ? egyptMonthly : gulfMonthly;

  static String yearlyPrice(String? countryCode) =>
      isEgypt(countryCode) ? egyptYearly : gulfYearly;

  static String lifetimePrice(String? countryCode) =>
      isEgypt(countryCode) ? egyptLifetime : gulfLifetime;

  // Stub — real offering from RevenueCat when key is configured
  static Future<dynamic> getOffering() async => null;

  static Future<String?> getCountryCode() async => null;
}
