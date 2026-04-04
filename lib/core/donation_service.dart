// donation_service.dart — HalalCalorie v1.0
// Sadaqa jariya donation button
// RevenueCat activated when purchases_flutter key is ready

class DonationService {
  static const donation5  = 'donation_5';
  static const donation10 = 'donation_10';
  static const donation20 = 'donation_20';

  static Future<bool> donate(String productId) async {
    // Real purchase via RevenueCat when key is configured
    // For now: show thank you message
    return false;
  }

  static Map<String, String> get donationOptions => {
    donation5:  'EGP 50',
    donation10: 'EGP 100',
    donation20: 'EGP 200',
  };
}
