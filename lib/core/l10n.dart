// l10n.dart — HalalCalorie Bilingual String System
// languageProvider lives in providers.dart - not here
import 'package:flutter/material.dart';

class L {
  final String lang;
  const L._(this.lang);

  // Use L.fromLang(ref.watch(languageProvider)) instead of L.of(context)
  static L fromLang(String lang) => L._(lang);

  bool get isAr => lang == 'ar';
  String t(String ar, String en) => isAr ? ar : en;

  String get appName        => 'HalalCalorie';
  String get appTagline     => t('حلال في كل لقمة', 'Halal in every bite');
  String get start          => t('ابدأ ✨', 'Start ✨');
  String get next           => t('التالي', 'Next');
  String get back           => t('رجوع', 'Back');
  String get skip           => t('تخطي', 'Skip');
  String get done           => t('تم ✓', 'Done ✓');
  String get save           => t('حفظ', 'Save');
  String get cancel         => t('إلغاء', 'Cancel');
  String get halal          => t('حلال ✓', 'Halal ✓');
  String get doubtful       => t('مشبوه ⚠️', 'Doubtful ⚠️');
  String get haram          => t('حرام ✕', 'Haram ✕');
  String get unknown        => t('غير معروف ?', 'Unknown ?');

  String get navHome        => t('الرئيسية', 'Home');
  String get navNutrition   => t('تغذية', 'Nutrition');
  String get navFitness     => t('لياقة', 'Fitness');
  String get navHealth      => t('صحة', 'Health');
  String get navProfile     => t('ملفي', 'Profile');
}
