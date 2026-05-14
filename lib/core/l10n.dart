// l10n.dart -- HalalCalorie multilingual support
// ar=Arabic  en=English  fr=French  tr=Turkish  ur=Urdu  ms=Malay  id=Indonesian

// ── Global helper used by all screens ─────────────────────────────────────
// Usage: String t(String ar, String en) => tLang(lang, ar, en);
// Screens that have fr/tr/ms/id strings can call tLang with extra params.
String tLang(String lang, String ar, String en,
    [String fr = '', String tr = '', String ms = '', String id = '']) {
  switch (lang) {
    case 'ar':
    case 'ur': return ar;
    case 'fr': return fr.isEmpty ? en : fr;
    case 'tr': return tr.isEmpty ? en : tr;
    case 'ms': return ms.isEmpty ? en : ms;
    case 'id': return id.isEmpty ? en : id;
    default:   return en;
  }
}

class L {
  final String lang;
  const L._(this.lang);
  static L fromLang(String lang) => L._(lang);

  bool get isAr  => lang == 'ar' || lang == 'ur';
  bool get isRtl => lang == 'ar' || lang == 'ur';

  String t(String ar, String en) => tLang(lang, ar, en);

  String t6(String ar, String en, String fr, String tr, String ms, String id) =>
      tLang(lang, ar, en, fr, tr, ms, id);

  // ── App ────────────────────────────────────────────────────────────────
  String get appName    => 'HalalCalorie';
  String get appTagline => t6('حلال في كل لقمة',
      'Halal in every bite', 'Halal à chaque bouchette',
      'Her lokmada Helal', 'Halal dalam setiap suapan', 'Halal di setiap suapan');

  // ── Common UI ──────────────────────────────────────────────────────────
  String get start   => t6('ابدأ ✨', 'Start ✨',
      'Débuter ✨', 'Başla ✨', 'Mula ✨', 'Mulai ✨');
  String get next    => t6('التالي', 'Next',
      'Suivant', 'Sonraki', 'Seterusnya', 'Berikutnya');
  String get back    => t6('رجوع', 'Back',
      'Retour', 'Geri', 'Kembali', 'Kembali');
  String get save    => t6('حفظ', 'Save',
      'Enregistrer', 'Kaydet', 'Simpan', 'Simpan');
  String get cancel  => t6('إلغاء', 'Cancel',
      'Annuler', 'İptal', 'Batal', 'Batal');
  String get done    => t6('تم ✓', 'Done ✓',
      'Terminé ✓', 'Tamam ✓', 'Selesai ✓', 'Selesai ✓');
  String get skip    => t6('تخطي', 'Skip',
      'Passer', 'Atla', 'Langkau', 'Lewati');

  // ── Halal status ───────────────────────────────────────────────────────
  String get halal    => t6('حلال ✓', 'Halal ✓',
      'Halal ✓', 'Helal ✓', 'Halal ✓', 'Halal ✓');
  String get doubtful => t6('مشبوه ⚠️', 'Doubtful ⚠️',
      'Douteux ⚠️', 'Şüpheli ⚠️',
      'Syubhah ⚠️', 'Syubhat ⚠️');
  String get haram    => t6('حرام ✕', 'Haram ✕',
      'Haram ✕', 'Haram ✕', 'Haram ✕', 'Haram ✕');
  String get unknown  => t6('غير معروف ?',
      'Unknown ?', 'Inconnu ?', 'Bilinmiyor ?', 'Tidak diketahui ?', 'Tidak diketahui ?');

  // ── Navigation ─────────────────────────────────────────────────────────
  String get navHome      => t6('الرئيسية', 'Home',
      'Accueil', 'Ana Sayfa', 'Utama', 'Beranda');
  String get navNutrition => t6('تغذية', 'Nutrition',
      'Nutrition', 'Beslenme', 'Pemakanan', 'Nutrisi');
  String get navFitness   => t6('لياقة', 'Fitness',
      'Forme', 'Fitness', 'Kecergasan', 'Kebugaran');
  String get navHealth    => t6('صحة', 'Health',
      'Santé', 'Sağlık', 'Kesihatan', 'Kesehatan');
  String get navProfile   => t6('ملفي', 'Profile',
      'Profil', 'Profil', 'Profil', 'Profil');

  // ── Nutrition ──────────────────────────────────────────────────────────
  String get addFood   => t6('أضف طعام', 'Add Food',
      'Ajouter aliment', 'Yemek Ekle', 'Tambah Makanan', 'Tambah Makanan');
  String get protein   => t6('بروتين', 'Protein',
      'Protéines', 'Protein', 'Protein', 'Protein');
  String get carbs     => t6('كربوهيدرات', 'Carbs',
      'Glucides', 'Karbonhidrat', 'Karbohidrat', 'Karbohidrat');
  String get fat       => t6('دهون', 'Fat',
      'Lipides', 'Yağ', 'Lemak', 'Lemak');
  String get calories  => t6('سعرات', 'Calories',
      'Calories', 'Kalori', 'Kalori', 'Kalori');
  String get water     => t6('ماء', 'Water',
      'Eau', 'Su', 'Air', 'Air');
  String get breakfast => t6('إفطار', 'Breakfast',
      'Petit-déjeuner', 'Kahvaltı', 'Sarapan', 'Sarapan');
  String get lunch     => t6('غداء', 'Lunch',
      'Déjeuner', 'Öğle', 'Tengahari', 'Siang');
  String get dinner    => t6('عشاء', 'Dinner',
      'Dîner', 'Akşam', 'Malam', 'Malam');
  String get snack     => t6('وجبة خفيفة', 'Snack',
      'Collation', 'Atlıştırmalık', 'Snek', 'Camilan');
  String get addToLog  => t6('أضف للسجل', 'Add to Log',
      'Ajouter au journal', 'Kayıta Ekle', 'Tambah ke Log', 'Tambah ke Log');

  // ── Fitness ────────────────────────────────────────────────────────────
  String get workout  => t6('تمرين', 'Workout',
      'Entraînement', 'Antrenman', 'Latihan', 'Latihan');
  String get steps    => t6('خطوات', 'Steps',
      'Pas', 'Adımlar', 'Langkah', 'Langkah');

  // ── Settings ───────────────────────────────────────────────────────────
  String get settings      => t6('الإعدادات', 'Settings',
      'Réglages', 'Ayarlar', 'Tetapan', 'Pengaturan');
  String get language      => t6('اللغة', 'Language',
      'Langue', 'Dil', 'Bahasa', 'Bahasa');
  String get notifications => t6('الإشعارات', 'Notifications',
      'Notifications', 'Bildirimler', 'Pemberitahuan', 'Notifikasi');
  String get macroPlans    => t6('خطط الماكرو', 'Macro Plans',
      'Plans macro', 'Makro Planları', 'Pelan Makro', 'Rencana Makro');
  String get noInternet    => t6('⚠️ لا يوجد اتصال',
      '⚠️ No internet connection',
      '⚠️ Pas de connexion', '⚠️ İnternet yok',
      '⚠️ Tiada internet', '⚠️ Tidak ada internet');

  // ── Ramadan ────────────────────────────────────────────────────────────
  String get ramadanKareem => t6('رمضان كريم',
      'Ramadan Kareem', 'Ramadan Karîm', 'Ramazan Kareem',
      'Ramadan Kareem', 'Ramadan Kareem');
  String get iftarIn  => t6('الإفطار بعد', 'Iftar in',
      'Iftar dans', 'İftar’a kalan', 'Iftar dalam', 'Iftar dalam');
  String get suhoorIn => t6('السحور بعد', 'Suhoor in',
      'Suhoor dans', 'Sahura kalan', 'Sahur dalam', 'Sahur dalam');
  String get suhoor   => t6('سحور', 'Suhoor',
      'Suhoor', 'Sahur', 'Sahur', 'Sahur');
  String get iftar    => t6('إفطار', 'Iftar',
      'Iftar', 'İftar', 'Iftar', 'Iftar');
}
