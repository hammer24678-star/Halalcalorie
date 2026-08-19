// l10n.dart -- HalalCalorie multilingual support
// ar=Arabic  en=English  fr=French  tr=Turkish  ur=Urdu  ms=Malay  id=Indonesian
//
// Every string in the app funnels through [tLang]. Callers may pass explicit
// translations, but when one is missing (or is just the English string echoed
// into a positional slot, which older call sites do) the shared dictionary in
// translations.dart fills the gap. That keeps all seven languages live without
// needing every call site to spell out seven variants.

import 'translations.dart';

const kSupportedLangs = ['ar', 'en', 'fr', 'tr', 'ur', 'ms', 'id'];

/// True for languages that lay out right-to-left.
bool isRtlLang(String lang) => lang == 'ar' || lang == 'ur';

/// Resolves one language slot: explicit value → dictionary → English.
String _pick(String code, String provided, String en) {
  if (provided.isNotEmpty && provided != en) return provided;
  final hit = kAutoTranslations[en]?[code];
  if (hit != null && hit.isNotEmpty) return hit;
  return en;
}

// ── Global helper used by all screens ────────────────────────────────────────
// Usage: final l = L.fromLang(lang); then l.someGetter or l.t(ar, en)
String tLang(String lang, String ar, String en,
    [String fr = '', String tr = '', String ms = '', String id = '',
     String ur = '']) {
  switch (lang) {
    case 'ar': return ar;
    case 'fr': return _pick('fr', fr, en);
    case 'tr': return _pick('tr', tr, en);
    case 'ms': return _pick('ms', ms, en);
    case 'id': return _pick('id', id, en);
    case 'ur': return _pick('ur', ur, en);
    default:   return en;
  }
}

class L {
  final String lang;
  const L._(this.lang);
  static L fromLang(String lang) => L._(lang);

  /// True only for Arabic — Urdu is its own language with its own strings.
  bool get isAr  => lang == 'ar';
  bool get isRtl => isRtlLang(lang);

  String t(String ar, String en) => tLang(lang, ar, en);

  String t6(String ar, String en, String fr, String tr, String ms, String id,
          [String ur = '']) =>
      tLang(lang, ar, en, fr, tr, ms, id, ur);

  // ── App ─────────────────────────────────────────────────────────────────────
  String get appName    => 'HalalCalorie';
  String get appTagline => t6('حلال في كل لقمة',
      'Halal in every bite', 'Halal à chaque bouchée',
      'Her lokmada Helal', 'Halal dalam setiap suapan', 'Halal di setiap suapan');

  // ── Common UI ──────────────────────────────────────────────────────────────
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

  // ── Halal status ────────────────────────────────────────────────────────────
  String get halal    => t6('حلال ✓', 'Halal ✓',
      'Halal ✓', 'Helal ✓', 'Halal ✓', 'Halal ✓');
  String get doubtful => t6('مشبوه ⚠️', 'Doubtful ⚠️',
      'Douteux ⚠️', 'Şüpheli ⚠️',
      'Syubhah ⚠️', 'Syubhat ⚠️');
  String get haram    => t6('حرام ✕', 'Haram ✕',
      'Haram ✕', 'Haram ✕', 'Haram ✕', 'Haram ✕');
  String get unknown  => t6('غير معروف ?',
      'Unknown ?', 'Inconnu ?', 'Bilinmiyor ?', 'Tidak diketahui ?', 'Tidak diketahui ?');

  // ── Navigation ──────────────────────────────────────────────────────────────
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

  // ── Nutrition ─────────────────────────────────────────────────────────────
  String get addFood    => t6('أضف طعام', 'Add Food',
      'Ajouter aliment', 'Yemek Ekle', 'Tambah Makanan', 'Tambah Makanan');
  String get protein    => t6('بروتين', 'Protein',
      'Protéines', 'Protein', 'Protein', 'Protein');
  String get carbs      => t6('كربوهيدرات', 'Carbs',
      'Glucides', 'Karbonhidrat', 'Karbohidrat', 'Karbohidrat');
  String get fat        => t6('دهون', 'Fat',
      'Lipides', 'Yağ', 'Lemak', 'Lemak');
  String get calories   => t6('سعرات', 'Calories',
      'Calories', 'Kalori', 'Kalori', 'Kalori');
  String get water      => t6('ماء', 'Water',
      'Eau', 'Su', 'Air', 'Air');
  String get breakfast  => t6('إفطار', 'Breakfast',
      'Petit-déjeuner', 'Kahvaltı', 'Sarapan', 'Sarapan');
  String get lunch      => t6('غداء', 'Lunch',
      'Déjeuner', 'Öğle', 'Tengahari', 'Siang');
  String get dinner     => t6('عشاء', 'Dinner',
      'Dîner', 'Akşam', 'Malam', 'Malam');
  String get snack      => t6('وجبة خفيفة', 'Snack',
      'Collation', 'Atlıştirmalık', 'Snek', 'Camilan');
  String get addToLog   => t6('أضف للسجل', 'Add to Log',
      'Ajouter au journal', 'Kayıta Ekle', 'Tambah ke Log', 'Tambah ke Log');
  String get eaten      => t6('مُستهلَك', 'Eaten',
      'Consommé', 'Yenilen', 'Dimakan', 'Dimakan');
  String get burned     => t6('محروق', 'Burned',
      'Brûlé', 'Yakılan', 'Dibakar', 'Dibakar');
  String get left       => t6('متبقّي', 'Left',
      'Restant', 'Kalan', 'Baki', 'Sisa');
  String get todayTab   => t6('اليوم', 'Today',
      'Aujourd’hui', 'Bugün', 'Hari ini', 'Hari ini');
  String get recipesTab => t6('وصفات', 'Recipes',
      'Recettes', 'Tarifler', 'Resipi', 'Resep');
  String get aiPlanTab  => t6('خطة AI', 'AI Plan',
      'Plan IA', 'Yapay Zeka Planı', 'Pelan AI', 'Rencana AI');
  String get balanced   => t6('متوازن', 'Balanced',
      'Équilibré', 'Dengeli', 'Seimbang', 'Seimbang');
  String get highProtein => t6('بروتين عالي', 'High Protein',
      'Riche en protéines', 'Yüksek Protein', 'Protein Tinggi', 'Protein Tinggi');
  String get highCarb   => t6('كارب عالي', 'High Carb',
      'Riche en glucides', 'Yüksek Karbonhidrat', 'Karbohidrat Tinggi', 'Karbohidrat Tinggi');
  String get mindfulEatingTip => t6(
      'كُل ببطء وانتبه لأول شعور بالشبع',
      'Eat slowly and stop at the first sign of fullness',
      'Mangez lentement et arrêtez dès la première sensation de satiété',
      'Yavaş ye ve ilk doyma işaretinde dur',
      'Makan perlahan dan berhenti pada tanda pertama rasa kenyang',
      'Makan perlahan dan berhenti pada tanda pertama rasa kenyang',
      'آہستہ کھائیں اور پیٹ بھرنے کے پہلے احساس پر رک جائیں');

  // ── Greetings ─────────────────────────────────────────────────────────────
  String get goodMorning   => t6('صباح الخير ☀️', 'Good Morning ☀️',
      'Bonjour ☀️', 'Günaydın ☀️', 'Selamat pagi ☀️', 'Selamat pagi ☀️');
  String get goodAfternoon => t6('نهارك سعيد 🌟', 'Good Afternoon 🌟',
      'Bon après-midi 🌟', 'İyi öğledenler 🌟', 'Selamat tengahari 🌟', 'Selamat siang 🌟');
  String get goodEvening   => t6('مساء الخير 🌙', 'Good Evening 🌙',
      'Bonsoir 🌙', 'İyi akşamlar 🌙', 'Selamat petang 🌙', 'Selamat malam 🌙');

  // ── Fitness ───────────────────────────────────────────────────────────────
  String get workout        => t6('تمرين', 'Workout',
      'Entraînement', 'Antrenman', 'Latihan', 'Latihan');
  String get steps          => t6('خطوات', 'Steps',
      'Pas', 'Adımlar', 'Langkah', 'Langkah');
  String get fitnessTitle   => t6('اللياقة', 'Fitness',
      'Forme', 'Fitness', 'Kecergasan', 'Kebugaran', 'فٹنس');
  String get ramadanModeLabel => t6(
      '🌙 وضع رمضان — التمارين الخفيفة أولاً',
      'Ramadan mode — light workouts first',
      'Mode Ramadan — exercices légers d’abord',
      'Ramazan modu — önce hafif antrenmanlar',
      'Mod Ramadan — senaman ringan dahulu',
      'Mode Ramadan — latihan ringan dahulu');
  String get recommendedNow => t6('موصى به الآن', 'Recommended Now',
      'Recommandé maintenant', 'Şiimdi Önerilen',
      'Disyorkan Sekarang', 'Direkomendasikan Sekarang');
  String get filterAll      => t6('الكل', 'All', 'Tout', 'Hepsi', 'Semua', 'Semua');
  String get filterWalk     => t6('مشي', 'Walk', 'Marche', 'Yürüyüş', 'Jalan', 'Jalan');
  String get filterStrength => t6('قوة', 'Strength', 'Force', 'Güç', 'Kekuatan', 'Kekuatan');
  String get filterGentle   => t6('لطيف', 'Gentle', 'Doux', 'Hafif', 'Lembut', 'Lembut');
  String get filterRamadan  => t6('رمضان', 'Ramadan', 'Ramadan', 'Ramazan', 'Ramadan', 'Ramadan');
  String get filterBreathe  => t6('تنفس', 'Breathe', 'Respirer', 'Nefes al', 'Bernafas', 'Bernafas');
  String get minLabel       => t6('د', 'min', 'min', 'dak', 'min', 'mnt');

  // ── Health screen ───────────────────────────────────────────────────────────
  String get healthAndWellness  => t6(
      'الصحة والعافية', 'Health & Wellness',
      'Santé & Bien-être', 'Sağlık & Zindelik',
      'Kesihatan & Kesejahteraan', 'Kesehatan & Kebugaran');
  String get dailyHealthScore   => t6(
      'نقاط صحتك اليوم', 'Your Daily Health Score',
      'Votre score santé quotidien', 'Günlük Sağlık Puanı',
      'Skor Kesihatan Harian', 'Skor Kesehatan Harian');
  String get scoreExcellent     => t6('ممتاز', 'Excellent',
      'Excellent', 'Mükemmel', 'Cemerlang', 'Luar biasa');
  String get scoreVeryGood      => t6('جيد جداً', 'Very Good',
      'Très bien', 'Çok İyi', 'Sangat Baik', 'Sangat Baik');
  String get scoreGood          => t6('جيد', 'Good',
      'Bien', 'İyi', 'Baik', 'Baik');
  String get scoreKeepGoing     => t6('يحتاج تحسيناً', 'Keep improving',
      'Continuez à progresser', 'Gelişmeye devam', 'Teruskan usaha', 'Terus tingkatkan');
  String get dailyWaterSec      => t6('💧 الماء اليومي',
      '💧 Daily Water', '💧 Eau quotidienne',
      '💧 Günlük Su', '💧 Air Harian', '💧 Air Harian');
  String get sleepLabel         => t6('النوم', 'Sleep',
      'Sommeil', 'Uyku', 'Tidur', 'Tidur');
  String get stepsLabel         => t6('الخطوات', 'Steps',
      'Pas', 'Adımlar', 'Langkah', 'Langkah');
  String get moodLabel          => t6('المزاج', 'Mood',
      'Humeur', 'Rüh hali', 'Mood', 'Suasana hati');
  String get trackingTab        => t6('تتبع', 'Tracking',
      'Suivi', 'Takip', 'Penjejakan', 'Pelacakan');
  String get calculatorsTab     => t6('حاسبات', 'Calculators',
      'Calculateurs', 'Hesaplayıcılar', 'Kalkulator', 'Kalkulator');
  String get articlesTab        => t6('مقالات', 'Articles',
      'Articles', 'Makaleler', 'Artikel', 'Artikel');
  String get addCup             => t6('+ كوب', '+ Cup',
      '+ Tasse', '+ Bardak', '+ Cawan', '+ Cangkir');
  String get removeCup          => t6('- كوب', '- Cup',
      '- Tasse', '- Bardak', '- Cawan', '- Cangkir');

  // ── Profile screen ─────────────────────────────────────────────────────────
  String get myProfile          => t6('ملفي الشخصي', 'My Profile',
      'Mon profil', 'Profilim', 'Profil Saya', 'Profil Saya');
  String get lifetimeStats      => t6('إحصائيات الحياة', 'Lifetime Stats',
      'Stats à vie', 'Yaşam Boyu', 'Statistik Seumur Hidup', 'Statistik Seumur Hidup');
  String get bodyMetrics        => t6('مقاييس الجسم', 'Body Metrics',
      'Métriques corporelles', 'Vücut Ölçümleri', 'Metrik Badan', 'Metrik Tubuh');
  String get streakLabel        => t6('استمرارية', 'Streak',
      'Série', 'Seri', 'Streak', 'Streak');
  String get tonightSleep       => t6('الليلة', 'Tonight',
      'Ce soir', 'Bu gece', 'Malam ini', 'Malam ini');
  String get viewAll            => t6('عرض الكل', 'View All',
      'Tout afficher', 'Hepsini gör', 'Lihat Semua', 'Lihat Semua');
  String get menMode            => t6('وضع الرجال', 'Men Mode',
      'Mode Hommes', 'Erkek Modu', 'Mod Lelaki', 'Mode Pria');
  String get sistersMode        => t6('وضع النساء', 'Women Mode',
      'Mode Femmes', 'Kadın Modu', 'Mod Wanita', 'Mode Wanita');
  String get manLabel           => t6('رجل', 'Man', 'Homme', 'Adam', 'Lelaki', 'Pria');
  String get womanLabel         => t6('امرأة', 'Woman', 'Femme', 'Kadın', 'Wanita', 'Wanita');
  String get yrsLabel           => t6('سنة', 'yrs', 'ans', 'yaş', 'thn', 'thn');

  // ── Settings ─────────────────────────────────────────────────────────────
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

  // ── Ascent System ─────────────────────────────────────────────────────────
  String get ascentTitle    => t6('الصعود', 'Ascent',
      'Ascension', 'Yükseliş', 'Pendakian', 'Pendakian', 'عروج');
  String get ascentNavLabel => t6('صعود', 'Ascent',
      'Ascension', 'Yükseliş', 'Daki', 'Daki', 'عروج');
  String get todayLabel     => t6('اليوم', 'Today',
      'Aujourd’hui', 'Bugün', 'Hari ini', 'Hari ini', 'آج');
  String get systemLabel    => t6('النظام', 'SYSTEM',
      'SYSTÈME', 'SİSTEM', 'SISTEM', 'SISTEM', 'سسٹم');
  String get levelShort     => t6('المستوى', 'LEVEL',
      'NIVEAU', 'SEVİYE', 'TAHAP', 'LEVEL', 'لیول');
  String get rankLabel      => t6('الرتبة', 'Rank',
      'Rang', 'Rütbe', 'Pangkat', 'Peringkat', 'درجہ');
  String get maxLevel       => t6('أقصى مستوى', 'Max level',
      'Niveau max', 'En üst seviye', 'Tahap maksimum', 'Level maksimum',
      'اعلیٰ ترین لیول');
  String get dailyScore     => t6('نقاط اليوم', 'Today’s score',
      'Score du jour', 'Bugünün puanı', 'Skor hari ini', 'Skor hari ini',
      'آج کا اسکور');
  String get dailyQuests    => t6('مهام اليوم', 'Daily quests',
      'Quêtes du jour', 'Günlük görevler', 'Misi harian', 'Misi harian',
      'روزانہ مشن');
  String get dailyQuestsHint => t6(
      'أكمل ما تستطيع — كل مهمة ترفع نقاطك وخبرتك',
      'Clear what you can — each quest adds score and XP',
      'Faites ce que vous pouvez — chaque quête ajoute score et XP',
      'Elinden geleni yap — her görev puan ve XP kazandırır',
      'Selesaikan apa yang mampu — setiap misi menambah skor dan XP',
      'Selesaikan yang kamu bisa — tiap misi menambah skor dan XP',
      'جو ہو سکے مکمل کریں — ہر مشن اسکور اور XP بڑھاتا ہے');
  String get questsLabel    => t6('مهام', 'quests',
      'quêtes', 'görev', 'misi', 'misi', 'مشن');
  String get titlesLabel    => t6('الألقاب', 'Titles',
      'Titres', 'Unvanlar', 'Gelaran', 'Gelar', 'القاب');
  String get weeklyReview   => t6('مراجعة الأسبوع', 'Weekly review',
      'Bilan hebdomadaire', 'Haftalık özet', 'Ulasan mingguan',
      'Ulasan mingguan', 'ہفتہ وار جائزہ');
  String get averageLabel   => t6('المتوسط', 'Average',
      'Moyenne', 'Ortalama', 'Purata', 'Rata-rata', 'اوسط');
  String get bestLabel      => t6('الأفضل', 'Best',
      'Meilleur', 'En iyi', 'Terbaik', 'Terbaik', 'بہترین');
  String get levelUp        => t6('ارتقاء المستوى', 'LEVEL UP',
      'NIVEAU SUPÉRIEUR', 'SEVİYE ATLADIN', 'NAIK TAHAP', 'NAIK LEVEL',
      'لیول اپ');
  String get levelUpNote    => t6(
      'خطوة صغيرة تكررت حتى صارت عادة. واصل غداً.',
      'A small step, repeated until it became a habit. Keep going tomorrow.',
      'Un petit pas, répété jusqu’à devenir une habitude. Continuez demain.',
      'Küçük bir adım, alışkanlığa dönüşene kadar tekrarlandı. Yarın da devam.',
      'Langkah kecil, diulang sampai jadi kebiasaan. Teruskan esok.',
      'Langkah kecil, diulang sampai jadi kebiasaan. Lanjutkan besok.',
      'ایک چھوٹا قدم، جو عادت بن گیا۔ کل بھی جاری رکھیں۔');
  String get continueLabel  => t6('متابعة', 'Continue',
      'Continuer', 'Devam', 'Teruskan', 'Lanjutkan', 'جاری رکھیں');
  String get ascentLockedTitle => t6('نظام الصعود — بريميوم',
      'The Ascent System — Premium',
      'Le système d’Ascension — Premium', 'Yükseliş Sistemi — Premium',
      'Sistem Pendakian — Premium', 'Sistem Pendakian — Premium',
      'عروج سسٹم — پریمیم');
  String get ascentLockedBody => t6(
      'ثماني مهام يومية ترفع مستواك ورتبتك، مع مراجعة أسبوعية وألقاب تُفتح مع الوقت.',
      'Eight daily quests that raise your level and rank, plus a weekly review and titles you unlock over time.',
      'Huit quêtes quotidiennes qui font monter votre niveau et votre rang, avec un bilan hebdomadaire et des titres à débloquer.',
      'Seviyenizi ve rütbenizi yükselten sekiz günlük görev, haftalık özet ve zamanla açılan unvanlar.',
      'Lapan misi harian yang menaikkan tahap dan pangkat anda, dengan ulasan mingguan dan gelaran yang dibuka.',
      'Delapan misi harian yang menaikkan level dan peringkat, plus ulasan mingguan dan gelar yang terbuka.',
      'آٹھ روزانہ مشن جو آپ کا لیول اور درجہ بڑھاتے ہیں، ہفتہ وار جائزہ اور القاب کے ساتھ۔');
  String get upgradeCta     => t6('ترقية للبريميوم', 'Upgrade to Premium',
      'Passer à Premium', 'Premium’a geç', 'Naik taraf ke Premium',
      'Upgrade ke Premium', 'پریمیم میں اپ گریڈ کریں');
  String get ascentHomeCard => t6('صعودك اليوم', 'Your ascent today',
      'Votre ascension du jour', 'Bugünkü yükselişin',
      'Pendakian anda hari ini', 'Pendakianmu hari ini', 'آج کا عروج');

  // ── Ranked lifting ────────────────────────────────────────────────────────
  String get liftTitle       => t6('القوة المصنّفة', 'Ranked Lifts',
      'Levées classées', 'Sıralı Kaldırışlar', 'Angkatan Berpangkat',
      'Angkatan Berperingkat', 'درجہ بند لفٹس');
  String get liftNavLabel    => t6('قوة', 'Lifts',
      'Levées', 'Kaldırış', 'Angkatan', 'Angkatan', 'لفٹس');
  String get overallRankLabel => t6('رتبتك العامة', 'Overall rank',
      'Rang général', 'Genel rütbe', 'Pangkat keseluruhan',
      'Peringkat keseluruhan', 'مجموعی درجہ');
  String get maxRankReached  => t6('بلغت أعلى رتبة', 'Top rank reached',
      'Rang maximum atteint', 'En üst rütbeye ulaştın',
      'Pangkat tertinggi dicapai', 'Peringkat tertinggi tercapai',
      'اعلیٰ ترین درجہ حاصل');
  String get toNextDivision  => t6('للقسم التالي', 'to the next division',
      'vers la division suivante', 'sonraki dereceye',
      'ke bahagian seterusnya', 'ke divisi berikutnya', 'اگلے ڈویژن تک');
  String get setsToday       => t6('مجموعات اليوم', 'Sets today',
      'Séries aujourd’hui', 'Bugün set', 'Set hari ini', 'Set hari ini',
      'آج کے سیٹ');
  String get volumeToday     => t6('حجم اليوم', 'Volume today',
      'Volume du jour', 'Bugünkü hacim', 'Jumlah hari ini',
      'Volume hari ini', 'آج کا حجم');
  String get liftsRanked     => t6('تمارين مصنّفة', 'Lifts ranked',
      'Levées classées', 'Sıralanan hareket', 'Angkatan berpangkat',
      'Angkatan berperingkat', 'درجہ بند لفٹس');
  String get needBodyweight  => t6(
      'أضف وزنك أولاً — الرتب تُحسب من وزنك مقارنة بما ترفعه',
      'Add your bodyweight first — ranks compare what you lift to what you weigh',
      'Ajoutez votre poids d’abord — les rangs comparent la charge à votre poids',
      'Önce vücut ağırlığını gir — rütbeler kaldırdığını ağırlığınla karşılaştırır',
      'Masukkan berat badan dahulu — pangkat membandingkan angkatan dengan berat anda',
      'Masukkan berat badanmu dulu — peringkat membandingkan angkatan dengan beratmu',
      'پہلے اپنا وزن درج کریں — درجہ آپ کے وزن کے مقابلے میں طے ہوتا ہے');
  String get needBodyweightShort => t6('أضف وزنك أولاً', 'Add your bodyweight',
      'Ajoutez votre poids', 'Vücut ağırlığını gir', 'Masukkan berat badan',
      'Masukkan berat badan', 'اپنا وزن درج کریں');
  String get notRankedYet    => t6('لم يُصنّف بعد — سجّل مجموعة',
      'Not ranked yet — log a set',
      'Pas encore classé — enregistrez une série',
      'Henüz sıralanmadı — bir set kaydet',
      'Belum berpangkat — log satu set',
      'Belum berperingkat — catat satu set',
      'ابھی درجہ نہیں — ایک سیٹ درج کریں');
  String get repsLabel       => t6('تكرار', 'reps',
      'répét.', 'tekrar', 'ulangan', 'repetisi', 'ریپس');
  String get weightLabel     => t6('الوزن', 'Weight',
      'Charge', 'Ağırlık', 'Berat', 'Beban', 'وزن');
  String get addedWeight     => t6('وزن مضاف', 'Added weight',
      'Charge ajoutée', 'Eklenen ağırlık', 'Berat tambahan',
      'Beban tambahan', 'اضافی وزن');
  String get holdLabel       => t6('المدة', 'Hold',
      'Durée', 'Süre', 'Tahan', 'Tahan', 'دورانیہ');
  String get logASet         => t6('سجّل مجموعة', 'Log a set',
      'Enregistrer une série', 'Set kaydet', 'Log satu set',
      'Catat satu set', 'سیٹ درج کریں');
  String get logSetCta       => t6('سجّل المجموعة', 'Log set',
      'Enregistrer', 'Seti kaydet', 'Log set', 'Catat set', 'سیٹ درج کریں');
  String get setLogged       => t6('سُجّلت المجموعة', 'Set logged',
      'Série enregistrée', 'Set kaydedildi', 'Set dilog', 'Set dicatat',
      'سیٹ درج ہو گیا');
  String get newPersonalBest => t6('رقم شخصي جديد!', 'New personal best!',
      'Nouveau record personnel !', 'Yeni kişisel rekor!',
      'Rekod peribadi baharu!', 'Rekor pribadi baru!', 'نیا ذاتی ریکارڈ!');
  String get thisSetWouldRank => t6('هذه المجموعة تساوي',
      'This set would rank',
      'Cette série vaudrait', 'Bu set şu rütbeye denk',
      'Set ini setaraf', 'Set ini setara', 'یہ سیٹ برابر ہے');
  String get bodyweightShort => t6('وزن الجسم', 'bodyweight',
      'poids du corps', 'vücut ağırlığı', 'berat badan', 'berat badan',
      'جسمانی وزن');
  String get bodyweightOnly  => t6('وزن الجسم فقط', 'Bodyweight only',
      'Poids du corps seul', 'Sadece vücut ağırlığı', 'Berat badan sahaja',
      'Berat badan saja', 'صرف جسمانی وزن');
  String get restTimer       => t6('راحة', 'Rest',
      'Repos', 'Dinlenme', 'Rehat', 'Istirahat', 'آرام');
  String get standardsTitle  => t6('معايير الرتب', 'Rank standards',
      'Barèmes des rangs', 'Rütbe standartları', 'Piawaian pangkat',
      'Standar peringkat', 'درجہ معیارات');
  String get standardsHint   => t6('ما تحتاجه كل رتبة بوزنك الحالي',
      'What each tier asks for at your bodyweight',
      'Ce que chaque palier demande à votre poids',
      'Her kademenin senin ağırlığında istediği',
      'Apa yang setiap tahap perlukan pada berat anda',
      'Yang tiap tingkat butuhkan pada beratmu',
      'آپ کے وزن پر ہر درجے کا تقاضا');
  String get historyTitle    => t6('السجل', 'History',
      'Historique', 'Geçmiş', 'Sejarah', 'Riwayat', 'تاریخ');
  String get noSetsYet       => t6('لا مجموعات بعد', 'No sets yet',
      'Aucune série', 'Henüz set yok', 'Tiada set lagi', 'Belum ada set',
      'ابھی کوئی سیٹ نہیں');
  String get perSide         => t6('لكل جهة', 'Per side',
      'Par côté', 'Her tarafta', 'Setiap sisi', 'Tiap sisi', 'فی طرف');
  String get platesNotExact  => t6('لا يمكن تكوين هذا الوزن بأقراص قياسية',
      'Standard plates cannot make this exact weight',
      'Les disques standards ne font pas ce poids exact',
      'Standart plakalarla bu ağırlık tam yapılamaz',
      'Plat piawai tidak boleh membentuk berat tepat ini',
      'Plat standar tidak bisa membentuk berat persis ini',
      'معیاری پلیٹوں سے یہ وزن ممکن نہیں');
  String get rankUp          => t6('ترقية رتبة', 'RANK UP',
      'RANG SUPÉRIEUR', 'RÜTBE ATLADIN', 'NAIK PANGKAT', 'NAIK PERINGKAT',
      'درجہ بلند');
  String get yesterdayLabel  => t6('أمس', 'Yesterday',
      'Hier', 'Dün', 'Semalam', 'Kemarin', 'کل');
  String get notFound        => t6('غير موجود', 'Not found',
      'Introuvable', 'Bulunamadı', 'Tidak dijumpai', 'Tidak ditemukan',
      'نہیں ملا');
  String get strengthCardTitle => t6('قوتك', 'Your strength',
      'Votre force', 'Gücün', 'Kekuatan anda', 'Kekuatanmu', 'آپ کی طاقت');
  String get openLifts       => t6('افتح القوة المصنّفة', 'Open ranked lifts',
      'Ouvrir les levées classées', 'Sıralı kaldırışları aç',
      'Buka angkatan berpangkat', 'Buka angkatan berperingkat',
      'درجہ بند لفٹس کھولیں');

  // ── Scanner ───────────────────────────────────────────────────────────────
  String get cameraError => t6(
      'تعذّر فتح الكاميرا. تأكد من إذن الكاميرا في الإعدادات.',
      'Could not open camera. Check camera permissions in settings.',
      'Impossible d\'ouvrir la caméra. Vérifiez les autorisations.',
      'Kamera açılamadı. Kamera izinlerini ayarlardan kontrol edin.',
      'Tidak dapat buka kamera. Semak kebenaran kamera dalam tetapan.',
      'Tidak dapat membuka kamera. Periksa izin kamera di pengaturan.');

  // Returns Sun→Sat single-letter initials for the weekly review chart.
  // Encoded as a comma-separated string then split — avoids a List getter.
  List<String> get weekDaysShort => t6(
      'أ,إ,ث,ر,خ,ج,س',
      'S,M,T,W,T,F,S',
      'D,L,M,M,J,V,S',
      'Pa,Pt,Sa,Ça,Pe,Cu,Ct',
      'Ah,Is,Se,Ra,Kh,Ju,Sa',
      'Mi,Sn,Se,Ra,Ka,Ju,Sa').split(',');

  // ── Ramadan ───────────────────────────────────────────────────────────────
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
  String get dayLabel  => t6('يوم', 'Day',
      'Jour', 'Gün', 'Hari', 'Hari', 'دن');
  String get inDaysLabel => t6('بعد', 'In',
      'Dans', 'Kalan', 'Dalam', 'Dalam', 'میں');
  String get daysShort => t6('يوم', 'days',
      'jours', 'gün', 'hari', 'hari', 'دن');
  String get ramadanTimesEstimated => t6(
      'أوقات تقديرية — اضبط مدينتك للحصول على أوقات دقيقة',
      'Estimated times — set your city for exact times',
      'Heures estimées — indiquez votre ville pour des heures exactes',
      'Tahmini saatler — kesin saatler için şehrinizi seçin',
      'Waktu anggaran — tetapkan bandar anda untuk waktu tepat',
      'Perkiraan waktu — atur kotamu untuk waktu akurat',
      'اندازاً اوقات — درست اوقات کے لیے اپنا شہر منتخب کریں');
  String get ramadanFasting => t6('صائم الآن', 'Fasting now',
      'Jeûne en cours', 'Şu anda oruçlu', 'Sedang berpuasa',
      'Sedang berpuasa', 'ابھی روزہ');
  String get ramadanIftarSoon => t6('الإفطار قريب — استعد',
      'Iftar is close — get ready',
      'Iftar approche — préparez-vous', 'İftar yakın — hazırlan',
      'Iftar dekat — bersiaplah', 'Iftar dekat — bersiaplah',
      'افطار قریب ہے — تیار ہو جائیں');
  String get ramadanSuhoorSoon => t6('السحور ينتهي قريباً',
      'Suhoor window closing soon',
      'La fenêtre du suhoor se ferme bientôt', 'Sahur vakti bitiyor',
      'Waktu sahur hampir tamat', 'Waktu sahur segera berakhir',
      'سحری کا وقت ختم ہونے والا ہے');
  String get ramadanEvening => t6('وقت الفطور — خذ وقتك',
      'Evening window — take your time',
      'Soirée — prenez votre temps', 'Akşam vakti — acele etme',
      'Waktu malam — ambil masa anda', 'Waktu malam — santai saja',
      'شام کا وقت — آرام سے');
  String get ramadanTipFasting => t6(
      'وزّع سعراتك بين الإفطار والسحور، ولا تعوّض كل شيء في وجبة واحدة',
      'Spread your calories across iftar and suhoor rather than one large meal',
      'Répartissez vos calories entre l’iftar et le suhoor plutôt qu’un seul gros repas',
      'Kalorilerini tek büyük öğün yerine iftar ve sahura yay',
      'Bahagikan kalori antara iftar dan sahur, bukan satu hidangan besar',
      'Bagi kalorimu antara buka dan sahur, bukan satu porsi besar',
      'اپنی کیلوریز افطار اور سحری میں تقسیم کریں، ایک ہی وقت میں نہیں');
  String get ramadanTipIftarSoon => t6(
      'ابدأ بشيء خفيف وماء، ثم انتظر قليلاً قبل الوجبة الأساسية',
      'Start light with water, then pause before the main meal',
      'Commencez léger avec de l’eau, puis attendez avant le plat principal',
      'Suyla hafif başla, ana yemekten önce biraz bekle',
      'Mulakan ringan dengan air, kemudian jeda sebelum hidangan utama',
      'Mulai ringan dengan air, lalu jeda sebelum makan utama',
      'پانی سے ہلکی شروعات کریں، پھر اصل کھانے سے پہلے وقفہ دیں');
  String get ramadanTipSuhoor => t6(
      'اختر بروتيناً وكارب بطيء الامتصاص — يبقيك أطول بلا جوع',
      'Choose protein and slow carbs — they keep you full for longer',
      'Choisissez protéines et glucides lents — la satiété dure plus longtemps',
      'Protein ve yavaş karbonhidrat seç — daha uzun tok tutar',
      'Pilih protein dan karbohidrat perlahan — kekal kenyang lebih lama',
      'Pilih protein dan karbo lambat — bikin kenyang lebih lama',
      'پروٹین اور سست کاربوہائیڈریٹ چنیں — زیادہ دیر پیٹ بھرا رہے گا');
  String get ramadanTipEvening => t6(
      'اشرب أكوابك تدريجياً حتى السحور بدل شربها مرة واحدة',
      'Space your water out until suhoor instead of drinking it all at once',
      'Étalez votre eau jusqu’au suhoor au lieu de tout boire d’un coup',
      'Suyunu sahura kadar yay, hepsini birden içme',
      'Agihkan air anda hingga sahur, jangan minum sekali gus',
      'Sebar minum airmu sampai sahur, jangan sekaligus',
      'سحری تک پانی وقفے وقفے سے پییں، ایک ساتھ نہیں');
  String get planIftar => t6('خطّط إفطارك', 'Plan iftar',
      'Planifier l’iftar', 'İftarı planla', 'Rancang iftar',
      'Rencanakan buka', 'افطار کی منصوبہ بندی');
  String get logWater => t6('سجّل كوب ماء', 'Log water',
      'Noter l’eau', 'Su kaydet', 'Log air', 'Catat air', 'پانی درج کریں');
  String get openNutrition => t6('التغذية', 'Nutrition',
      'Nutrition', 'Beslenme', 'Pemakanan', 'Nutrisi', 'غذائیت');

  // ── Home screen ────────────────────────────────────────────────────────────
  String get todayCalories => t6('سعرات اليوم', "Today's Calories",
      'Calories du jour', "Bugünün Kalorileri", 'Kalori Hari Ini', 'Kalori Hari Ini');
  String get nextPrayer    => t6('الصلاة القادمة', 'Next Prayer',
      'Prochaine prière', 'Sonraki Namaz', 'Solat Seterusnya', 'Sholat Berikutnya');
  String get dailyNote     => t6('📖 كلمة اليوم', '📖 Note of the day',
      '📖 Note du jour', '📖 Günün notu',
      '📖 Nota hari ini', '📖 Catatan hari ini', '📖 آج کی بات');
  String get sleep         => t6('نوم', 'Sleep',
      'Sommeil', 'Uyku', 'Tidur', 'Tidur');
  String get streak        => t6('تتابع', 'Streak',
      'Série', 'Seri', 'Jujukan', 'Rangkaian');
  String get lifeStats     => t6('إحصائيات الحياة', 'Lifetime Stats',
      'Stats à vie', 'Tüm Zamanlar', 'Statistik Seumur Hidup', 'Statistik Seumur Hidup');
  String get fasting       => t6('صيام', 'Fasting',
      'Jeûne', 'Oruç', 'Puasa', 'Puasa');
  String get stayStrong    => t6('ثبت واحتسب 🤍', 'Stay strong 🤍',
      'Restez fort 🤍', 'Güçlü kal 🤍',
      'Tetap kuat 🤍', 'Tetap kuat 🤍');
}
