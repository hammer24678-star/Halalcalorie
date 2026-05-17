// l10n.dart -- HalalCalorie multilingual support
// ar=Arabic  en=English  fr=French  tr=Turkish  ur=Urdu  ms=Malay  id=Indonesian

// ── Global helper used by all screens ────────────────────────────────────────
// Usage: final l = L.fromLang(lang); then l.someGetter or l.t(ar, en)
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
  String get bismillahTip => t6(
      'قل بسم الله قبل الأكل، وكُل بيمينك',
      'Say Bismillah before eating, eat with your right hand',
      'Dites Bismillah avant de manger, mangez de la main droite',
      'Yemeden önce Bismillah deyin, sağ elinizle yiyin',
      'Sebut Bismillah sebelum makan, makan dengan tangan kanan',
      'Ucapkan Bismillah sebelum makan, makan dengan tangan kanan');

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
  String get islamicFitness => t6('اللياقة الإسلامية 🏃', 'Islamic Fitness 🏃',
      'Fitness Islamique 🏃', 'İslami Fitness 🏃',
      'Fitness Islam 🏃', 'Kebugaran Islam 🏃');
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

  // ── Barakah Engine ────────────────────────────────────────────────────────────────────
  String get barakahTitle    => t6('نقاط بركتك', 'Barakah Score',
      'Score Barakah', 'Bereket Puani', 'Mata Barakah', 'Skor Barakah');
  String get barakahSubtitle => t6('بركتك اليومية', 'Your daily blessing score',
      'Votre score bénédiction', 'Günlük bereket puanı', 'Skor berkat harian', 'Skor berkah harian');
  String get pillarsTitle    => t6('أعمدة البركة', 'Barakah Pillars',
      'Piliers Barakah', 'Bereket Sütunları', 'Tiang Barakah', 'Pilar Barakah');
  String get pillarNutrition => t6('تغذية', 'Nutrition',
      'Nutrition', 'Beslenme', 'Pemakanan', 'Nutrisi');
  String get pillarHydration => t6('ترطيب', 'Hydration',
      'Hydratation', 'Hidrasyon', 'Hidrasi', 'Hidrasi');
  String get pillarSleep     => t6('نوم', 'Sleep',
      'Sommeil', 'Uyku', 'Tidur', 'Tidur');
  String get pillarMovement  => t6('حركة', 'Movement',
      'Mouvement', 'Hareket', 'Pergerakan', 'Gerakan');
  String get pillarFasting   => t6('صيام', 'Fasting',
      'Jeûne', 'Oruç', 'Puasa', 'Puasa');
  String get pillarSunnahFood=> t6('أكل سنة', 'Sunnah Food',
      'Nourriture Sunnah', 'Sünnet Yemek', 'Makanan Sunnah', 'Makanan Sunnah');
  String get pillarWorkout   => t6('تمرين', 'Workout',
      'Entraînement', 'Antrenman', 'Latihan', 'Latihan');
  String get pillarDhikr     => t6('ذكر', 'Dhikr',
      'Dhikr', 'Zikir', 'Zikir', 'Zikir');
  String get dhikrDone       => t6('ذكرتك اليوم ✓', 'Dhikr done today ✓',
      'Dhikr fait aujourd’hui ✓', 'Bugün zikir yapıldı ✓',
      'Zikir hari ini selesai ✓', 'Zikir hari ini selesai ✓');
  String get dhikrTap        => t6('اضغط لتأكيد ذكرك', 'Tap to confirm dhikr',
      'Appuyer pour confirmer', 'Zikir onaylamak için dokunun',
      'Ketuk untuk sahkan zikir', 'Ketuk untuk konfirmasi zikir');
  String get badgesTitle     => t6('شاراتك', 'Your Badges',
      'Vos Badges', 'Rozetleriniz', 'Lencana Anda', 'Lencana Anda');
  String get weeklyReport    => t6('تقرير الجمعة', 'Friday Report',
      'Rapport Vendredi', 'Cuma Raporu', 'Laporan Jumaat', 'Laporan Jumat');
  String get barakahNavLabel => t6('بركة', 'Barakah',
      'Barakah', 'Bereket', 'Barakah', 'Barakah');
  String get barakahHomeCard => t6('نقاط بركتك', 'Barakah Score',
      'Score Barakah', 'Bereket Puanı', 'Mata Barakah', 'Skor Barakah');

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

  // ── Home screen ────────────────────────────────────────────────────────────
  String get todayCalories => t6('سعرات اليوم', "Today's Calories",
      'Calories du jour', "Bugünün Kalorileri", 'Kalori Hari Ini', 'Kalori Hari Ini');
  String get nextPrayer    => t6('الصلاة القادمة', 'Next Prayer',
      'Prochaine prière', 'Sonraki Namaz', 'Solat Seterusnya', 'Sholat Berikutnya');
  String get todayHadith   => t6('📖 حديث اليوم', "📖 Today's Hadith",
      '📖 Hadith du jour', '📖 Günün Hadisi',
      '📖 Hadis Hari Ini', '📖 Hadis Hari Ini');
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
