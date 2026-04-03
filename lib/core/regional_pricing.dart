// ============================================================
//  regional_pricing.dart — HalalCalorie
//  Smart regional pricing: Egypt (EGP) vs Gulf/World (USD)
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class RegionalPricing {
  // ── Detect if user is in Egypt ─────────────────────────────
  static bool get isEgypt {
    try {
      final locale = Platform.localeName.toLowerCase();
      return locale.contains('_eg') ||
             locale.contains('ar_eg') ||
             locale == 'ar';
    } catch (_) {
      return false;
    }
  }

  // ── Gulf countries ─────────────────────────────────────────
  static bool get isGulf {
    try {
      final locale = Platform.localeName.toLowerCase();
      return locale.contains('_sa') ||  // Saudi
             locale.contains('_ae') ||  // UAE
             locale.contains('_kw') ||  // Kuwait
             locale.contains('_qa') ||  // Qatar
             locale.contains('_bh') ||  // Bahrain
             locale.contains('_om');    // Oman
    } catch (_) {
      return false;
    }
  }

  // ── Get correct RevenueCat offering ────────────────────────
  static Future<Offering?> getOffering() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (isEgypt && offerings.all.containsKey('egypt')) {
        return offerings.all['egypt'];
      }
      if (isGulf && offerings.all.containsKey('gulf')) {
        return offerings.all['gulf'];
      }
      return offerings.current;
    } catch (e) {
      debugPrint('RegionalPricing error: \$e');
      return null;
    }
  }

  // ── Price display strings ───────────────────────────────────
  static String get monthlyPrice {
    if (isEgypt) return '99 ج.م / شهر';
    if (isGulf)  return '\$4.99 / month';
    return '\$2.99 / month';
  }

  static String get annualPrice {
    if (isEgypt) return '799 ج.م / سنة';
    if (isGulf)  return '\$34.99 / year';
    return '\$19.99 / year';
  }

  static String get annualMonthly {
    if (isEgypt) return '67 ج.م / شهر';
    if (isGulf)  return '\$2.91 / month';
    return '\$1.67 / month';
  }

  static String get savingPercent {
    if (isEgypt) return 'وفر 33%';
    return 'Save 33%';
  }

  // ── Currency symbol ─────────────────────────────────────────
  static String get currency {
    if (isEgypt) return 'EGP';
    if (isGulf)  return 'USD';
    return 'USD';
  }
}
