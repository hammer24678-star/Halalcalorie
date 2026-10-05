import 'package:go_router/go_router.dart';
// ============================================================
//  food_photo_screen.dart — HalalCalorie v1.0
//  AI-Powered Food Photo Analyzer
//  Camera / Gallery → Claude Vision → Nutrition + Halal check
// ============================================================

import 'dart:io'; import'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:image_picker/image_picker.dart'; import'../../core/theme.dart'; import'../../core/providers.dart'; import'../../core/ai_service.dart'; import'../../data/models/models.dart';
import '../../core/l10n.dart';
import '../../core/fx6.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../core/fx5.dart' show SheenSweep, ScanLoader, VerdictSeal, MacroRing, SealKind;
import '../../core/fx8.dart';
import '../../core/fx.dart' show ShineButton;
import '../../core/motion.dart' show Reveal, PressFx, Motion, CountUp;import'../../core/l10n.dart';

// ── Analysis state ─────────────────────────────
enum AnalysisState { idle, analyzing, done, error }

class FoodPhotoScreen extends ConsumerStatefulWidget {
  const FoodPhotoScreen({super.key});
  @override ConsumerState<FoodPhotoScreen> createState() => _FoodPhotoState();
}

class _FoodPhotoState extends ConsumerState<FoodPhotoScreen>
    with SingleTickerProviderStateMixin {
  String get lang => ref.read(languageProvider);

  final _picker = ImagePicker();
  File?           _image;
  AnalysisState         _state   = AnalysisState.idle;
  List<FoodPhotoResult> _results = [];
  String?               _error;

  // Results already added to the log (v56)
  final Set<int> _addedIdx = {};

  // ── Pick image ────────────────────────────────
  Future<void> _pick(ImageSource src) async {
    // ── Free-tier gate: 3 scans, then paywall ────────────────────
    final isPremium  = ref.read(premiumProvider);
    final scanCount  = ref.read(scanCountProvider.notifier);
    if (!isPremium && !scanCount.canScan) {
      if (mounted) {
        final lang = ref.read(languageProvider);
        final isAr = lang == 'ar' || lang == 'ur';
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isAr ? '🔒 وصلت للحد المجاني' : '🔒 Free limit reached',
              style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w800)),
            content: Text(
              isAr
                ? 'لقد استخدمت 3 تحليلات مجانية.\nاشترك في البريميوم للحصول على تحليلات غير محدودة 🌟'
                : 'You have used your 3 free AI scans.\nUpgrade to Premium for unlimited scans 🌟',
              style: const TextStyle(fontFamily: 'Aligarh', fontSize: 14, height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isAr ? 'لاحقاً' : 'Later')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/paywall');
                },
                child: Text(isAr ? 'ترقية 🌟' : 'Upgrade 🌟',
                  style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w800))),
            ],
          ),
        );
      }
      return;
    }
    try {
      final xf = await _picker.pickImage(
        source: src,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (xf == null) return;
      if (mounted) setState(() {
        _image   = File(xf.path);
        _addedIdx.clear();
        _state   = AnalysisState.idle;
        _results = [];
        _error   = null;
      });
    } catch (e) {
      final _l = L.fromLang(ref.read(languageProvider));
      if (mounted) setState(() {
        _error = _l.cameraError;
        _state = AnalysisState.error;
      });
    }
  }

  // ── Run analysis ──────────────────────────────
  Future<void> _analyze() async {
    if (_image == null) return;
    final lang = ref.read(languageProvider);
    if (mounted) setState(() { _state = AnalysisState.analyzing; _error = null; _addedIdx.clear(); });

    try {
      final result = await AIService.analyzeFoodPhoto(
        imagePath: _image!.path,
        language: lang,
      );
      if (!mounted) return;
      if (mounted) setState(() { _results = result; _state = AnalysisState.done; });
        // Increment free scan counter (no-op for premium)
        if (!ref.read(premiumProvider)) {
          ref.read(scanCountProvider.notifier).increment();
        }
      // Increment daily AI scan counter
      ref.read(aiPhotoScanProvider.notifier).increment();
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString();
      if (e is ApiKeyMissingException) {
        if (mounted) setState(() { _error = '__API_KEY_MISSING__'; _state = AnalysisState.error; });
        return;
      }
      final msg = _friendlyAiError(errStr, lang);
      if (mounted) setState(() { _error = msg; _state = AnalysisState.error; });
    }
  }

  /// Maps an AIService failure to something a person can act on. The raw text
  /// (the provider's JSON body, developer hints like "add it to GitHub Secrets")
  /// goes to the log, not the screen.
  String _friendlyAiError(String raw, String lang) {
    debugPrint('food analysis failed: $raw');
    final status = RegExp(r'API (\d{3})').firstMatch(raw)?.group(1);
    final lower = raw.toLowerCase();
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return tLang(lang, 'انتهت مهلة الاتصال، حاول مجدداً',
          'Connection timed out, try again');
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception')) {
      return tLang(lang, '⚠️ لا يوجد اتصال بالإنترنت', '⚠️ No internet connection');
    }
    if (status == '401' || status == '403' || raw.contains('GROQ_API_KEY')) {
      return tLang(
          lang,
          'تحليل الصور غير متاح حالياً. حاول لاحقاً.',
          'Photo analysis is unavailable right now. Please try again later.',
          'L’analyse photo est indisponible pour le moment. Réessayez plus tard.',
          'Fotoğraf analizi şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.',
          'Analisis foto tidak tersedia buat masa ini. Sila cuba lagi nanti.',
          'Analisis foto sedang tidak tersedia. Silakan coba lagi nanti.',
          'فوٹو تجزیہ اس وقت دستیاب نہیں۔ براہ کرم بعد میں کوشش کریں۔');
    }
    if (status == '429') {
      return tLang(
          lang,
          'الطلبات كثيرة الآن — انتظر دقيقة ثم حاول مجدداً.',
          'Too many requests right now — wait a minute and try again.',
          'Trop de requêtes en ce moment — patientez une minute puis réessayez.',
          'Şu anda çok fazla istek var — bir dakika bekleyip tekrar deneyin.',
          'Terlalu banyak permintaan — tunggu seminit dan cuba lagi.',
          'Terlalu banyak permintaan — tunggu semenit lalu coba lagi.',
          'اس وقت بہت زیادہ درخواستیں ہیں — ایک منٹ رکیں اور دوبارہ کوشش کریں۔');
    }
    return tLang(
        lang,
        'تعذّر تحليل الصورة. جرّب صورة أوضح.',
        'Couldn’t analyze this photo. Try a clearer one.',
        'Impossible d’analyser cette photo. Essayez-en une plus nette.',
        'Bu fotoğraf analiz edilemedi. Daha net bir fotoğraf deneyin.',
        'Tidak dapat menganalisis foto ini. Cuba foto yang lebih jelas.',
        'Foto ini tidak dapat dianalisis. Coba foto yang lebih jelas.',
        'یہ تصویر تجزیہ نہیں ہو سکی۔ زیادہ واضح تصویر آزمائیں۔');
  }

  // ── Add single result to tracker ──────────────
  void _addToTracker(FoodPhotoResult r) {
    final lang  = ref.read(languageProvider);
    final isAr  = lang == 'ar';
    ref.read(caloriesProvider.notifier).addEntry(
      isAr ? r.foodName : r.foodNameEn,
      r.kcal,
      proteinG: r.proteinG,
      carbsG:   r.carbsG,
      fatG:     r.fatG,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        tLang(lang, '✓ ${r.foodName} أُضيفت', '✓ ${r.foodNameEn} added', '✓ ${r.foodNameEn} added', '✓ ${r.foodNameEn} added', '✓ ${r.foodNameEn} added', '✓ ${r.foodNameEn} added'),
        style: const TextStyle(fontFamily: 'Aligarh')),
      backgroundColor: AppColors.brandGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Add ALL results to tracker ─────────────────
  void _addAllToTracker() {
    final lang = ref.read(languageProvider);
    final isAr = lang == 'ar';
    for (var i = 0; i < _results.length; i++) {
      if (_addedIdx.contains(i)) continue;
      final r = _results[i];
      ref.read(caloriesProvider.notifier).addEntry(
        isAr ? r.foodName : r.foodNameEn,
        r.kcal,
        proteinG: r.proteinG,
        carbsG:   r.carbsG,
        fatG:     r.fatG,
      );
    }
    final total = _results.fold(0, (s, r) => s + r.kcal);
    setState(() { for (var i = 0; i < _results.length; i++) { _addedIdx.add(i); } });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        '${tLang(lang, '✓ أُضيفت كل الأطعمة', '✓ All foods added')} '
        '($total ${tLang(lang, 'سعرة', 'kcal')})',
        style: const TextStyle(fontFamily: 'Aligarh')),
      backgroundColor: AppColors.brandGreen,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang  = ref.watch(languageProvider); final isAr  = lang =='ar';
    final isDark = ref.watch(themeProvider);
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String t(String ar, String en) => isAr ? ar : en;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('تحليل الطعام بـ AI', 'AI Food Analyzer')),
          backgroundColor: AppColors.brandGreen,
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
              tooltip: tLang(lang, 'إدخال سريع بالنص', 'Quick Text Entry', 'Saisie rapide', 'Hızlı Metin Girişi', 'Kemasukan Teks Pantas', 'Entri Teks Cepat'),
              onPressed: () => _showQuickEntrySheet(isAr, isDark),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Intro hero / photo preview ───────────────
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.curve,
              alignment: Alignment.topCenter,
              child: _image == null
                  ? _heroBanner(isAr, isDark)
                  : _imagePreview(bg, isAr),
            ),

            const SizedBox(height: 14),

            // ── Pick buttons ──────────────────────────────
            Row(children: [
              Expanded(child: _pickBtn(
                glyph: GlyphKind.camera, label: t('الكاميرا', 'Camera'),
                color: AppColors.brandGreen,
                onTap: () => _pick(ImageSource.camera),
              )),
              const SizedBox(width: 10),
              Expanded(child: _pickBtn(
                glyph: GlyphKind.gallery, label: t('المعرض', 'Gallery'),
                color: AppColors.waterBlue,
                onTap: () => _pick(ImageSource.gallery),
              )),
            ]),

            const SizedBox(height: 12),

            // ── Analyze button ────────────────────────────
            if (_image != null && _state != AnalysisState.analyzing)
              Reveal(
                offset: 0.2,
                child: ShineButton(
                  label: t('تحليل الآن', 'Analyze Now'),
                  icon: Icons.auto_awesome_rounded,
                  onPressed: _analyze,
                  height: 54,
                ),
              ),

            // ── Loading state ─────────────────────────────
            if (_state == AnalysisState.analyzing)
              _loadingCard(isAr, isDark),

            // ── Error state ───────────────────────────────
            if (_state == AnalysisState.error && _error == '__API_KEY_MISSING__')
              _apiKeyBanner(isAr, isDark),
            if (_state == AnalysisState.error && _error != null && _error != '__API_KEY_MISSING__')
              _errorCard(_error!, isAr, isDark),

            // ── Results ───────────────────────────────────
            if (_state == AnalysisState.done && _results.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (_results.length > 1) _totalSummaryBar(_results, isAr, isDark),
              ..._results.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Reveal(
                  index: e.key,
                  offset: 0.08,
                  child: _resultCard(e.value, isAr, isDark, bg, muted,
                      itemIndex: e.key + 1, totalItems: _results.length),
                ),
              )),
              if (_results.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _addedIdx.length >= _results.length ? null : _addAllToTracker,
                    icon: Icon(
                      _addedIdx.length >= _results.length
                          ? Icons.check_rounded : Icons.playlist_add,
                      color: Colors.white),
                    label: Text(
                      '${tLang(lang, 'إضافة كل الأطعمة للعداد', 'Add All Foods to Tracker')} '
                      '(${_results.fold(0,(s,r)=>s+r.kcal)} ${tLang(lang, 'سعرة', 'kcal')})',
                      style: const TextStyle(fontFamily: 'Aligarh', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                      disabledBackgroundColor: AppColors.brandGreen.withOpacity(0.55),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  )),
                ),
            ],

            const SizedBox(height: 20),

            // ── Tips ──────────────────────────────────────
            _tipsCard(isAr, isDark, bg, muted),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Intro hero ────────────────────────────────────────────
  Widget _heroBanner(bool isAr, bool isDark) {
    const r = 24.0;
    return SheenSweep(
      borderRadius: BorderRadius.circular(r),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.brandGreen, AppColors.darkGreen],
            begin: Alignment.topRight, end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(r),
          boxShadow: [BoxShadow(
            color: AppColors.brandGreen.withOpacity(0.32),
            blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          const FoodCameraHero(height: 150),
          const SizedBox(height: 8),
          Text(
            tLang(lang, 'التقط صورة لطعامك\nوسأحلله فوراً', 'Take a photo of your food\nand I’ll analyze it instantly', 'Prenez une photo de votre repas\net analysez-la instantanément', 'Yemeğinizin fotoğrafını çekin\nve anında analiz edeceğim', 'Ambil foto makanan anda\ndan saya akan menganalisisnya', 'Ambil foto makanan Anda\ndan saya akan menganalisisnya'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Aligarh', fontSize: 18,
                fontWeight: FontWeight.w700, color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8, runSpacing: 8,
            children: [
              GlyphChip(glyph: GlyphKind.flame, color: Colors.white,
                  text: tLang(lang, 'سعرات', 'Calories', 'Calories', 'Kalori', 'Kalori', 'Kalori')),
              GlyphChip(glyph: GlyphKind.dumbbell, color: Colors.white,
                  text: tLang(lang, 'بروتين', 'Protein', 'Protéines', 'Protein', 'Protein', 'Protein')),
              GlyphChip(glyph: GlyphKind.wheat, color: Colors.white,
                  text: tLang(lang, 'كربوهيدرات', 'Carbs', 'Glucides', 'Karbonhidrat', 'Karbohidrat', 'Karbohidrat')),
              GlyphChip(glyph: GlyphKind.shield, color: Colors.white,
                  text: tLang(lang, 'حكم حلال', 'Halal Check', 'Vérification Halal', 'Helal Kontrol', 'Semakan Halal', 'Cek Halal')),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Photo preview with scan overlay ───────────────────────
  Widget _imagePreview(Color bg, bool isAr) {
    final analyzing = _state == AnalysisState.analyzing;
    final done = _state == AnalysisState.done && _results.isNotEmpty;
    return Container(
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color: (analyzing ? AppColors.halalGreen : Colors.black)
              .withOpacity(analyzing ? 0.30 : 0.14),
          blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(fit: StackFit.expand, children: [
          Image.file(_image!, fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) =>
                const Icon(Icons.broken_image, color: Colors.grey, size: 48)),
          AnimatedSwitcher(
            duration: Motion.base,
            child: analyzing
                ? const PhotoScanOverlay(key: ValueKey('scan'))
                : const SizedBox.expand(key: ValueKey('idle')),
          ),
          PositionedDirectional(
            start: 12, bottom: 12,
            child: AnimatedSwitcher(
              duration: Motion.quick,
              child: analyzing
                  ? _photoPill(
                      key: const ValueKey('busy'), busy: true,
                      text: tLang(lang, 'جارٍ التحليل…', 'Analyzing…', 'Analyse en cours…', 'Analiz ediliyor…', 'Menganalisis…', 'Menganalisis…'))
                  : (done
                      ? _photoPill(
                          key: const ValueKey('done'), busy: false,
                          text: tLang(lang, 'تم التحليل', 'Analysis complete', 'Analyse terminée', 'Analiz tamamlandı', 'Analisis selesai', 'Analisis selesai'))
                      : const SizedBox.shrink(key: ValueKey('none'))),
            ),
          ),
          PositionedDirectional(
            top: 10, end: 10,
            child: GestureDetector(
              onTap: analyzing ? null : () => setState(() {
                _image = null; _results = []; _error = null;
                _state = AnalysisState.idle; _addedIdx.clear();
              }),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.50),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _photoPill({Key? key, required bool busy, required String text}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (busy)
          const ScanLoader(color: AppColors.halalGreen, width: 40, height: 14)
        else
          const PaintedGlyph(kind: GlyphKind.check, color: AppColors.halalGreen, size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
            fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }

  Widget _pickBtn({required GlyphKind glyph, required String label, required Color color, required VoidCallback onTap}) {
    return PressFx(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color.withOpacity(0.18), color.withOpacity(0.05)],
          ),
          border: Border.all(color: color.withOpacity(0.38), width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          PaintedGlyph(kind: glyph, color: color, size: 26),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
              fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }

  Widget _loadingCard(bool isAr, bool isDark) {
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandGreen.withOpacity(0.28)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(children: [
        const ScanLoader(color: AppColors.brandGreen),
        const SizedBox(height: 14),
        StageText(
          lines: [
            tLang(lang, 'جارٍ التعرّف على الطعام…', 'Identifying the food…', 'Identification du plat…', 'Yemek tanınıyor…', 'Mengenal pasti makanan…', 'Mengenali makanan…'),
            tLang(lang, 'تقدير الحصة والوزن…', 'Estimating portion size…', 'Estimation de la portion…', 'Porsiyon tahmin ediliyor…', 'Menganggar saiz hidangan…', 'Memperkirakan porsi…'),
            tLang(lang, 'حساب السعرات والماكروز…', 'Calculating calories and macros…', 'Calcul des calories et macros…', 'Kalori ve makrolar hesaplanıyor…', 'Mengira kalori dan makro…', 'Menghitung kalori dan makro…'),
            tLang(lang, 'فحص حالة الحلال…', 'Checking halal status…', 'Vérification halal…', 'Helal durumu kontrol ediliyor…', 'Menyemak status halal…', 'Memeriksa status halal…'),
          ],
          style: const TextStyle(fontFamily: 'Aligarh', fontSize: 14,
              fontWeight: FontWeight.w700, color: AppColors.brandGreen),
        ),
        const SizedBox(height: 6),
        Text(
          tLang(lang, 'عادةً يستغرق بضع ثوانٍ', 'Usually takes a few seconds', 'Prend généralement quelques secondes', 'Genellikle birkaç saniye sürer', 'Biasanya mengambil beberapa saat', 'Biasanya hanya beberapa detik'),
          style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: muted),
        ),
      ]),
    );
  }

  Widget _apiKeyBanner(bool isAr, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A00),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.doubtOrange.withOpacity(0.6), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PaintedGlyph(kind: GlyphKind.alert, color: AppColors.doubtOrange, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(
            tLang(lang, 'مفتاح AI غير مُعدّ', 'AI Key Not Configured', 'Clé AI non configurée', 'AI Anahtarı Yapılandırılmamış', 'Kunci AI Tidak Dikonfigurasi', 'Kunci AI Belum Dikonfigurasi'),
            style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w800,
                fontSize: 14, color: AppColors.doubtOrange))),
        ]),
        const SizedBox(height: 8),
        Text(
          tLang(lang, 'خدمة التحليل غير مهيّأة في هذه النسخة.', 'Photo analysis is not configured in this build.'),
          style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12,
              color: Colors.white70, height: 1.5)),
        const SizedBox(height: 12),
        Text(
          'docs.codemagic.io → Environment variables',
          style: TextStyle(fontFamily: 'Aligarh', fontSize: 10,
              color: AppColors.doubtOrange.withOpacity(0.7))),
      ]),
    );
  }

  Widget _errorCard(String error, bool isAr, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.haramRed.withOpacity(0.08),
        border: Border.all(color: AppColors.haramRed.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [ const PaintedGlyph(kind: GlyphKind.alert, color: AppColors.haramRed, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(error, style: const TextStyle(fontFamily:'Aligarh', fontSize: 12, color: AppColors.haramRed, height: 1.5))),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────
  SealKind _sealKind(HalalStatus s) {
    switch (s) {
      case HalalStatus.halal:    return SealKind.halal;
      case HalalStatus.doubtful: return SealKind.doubtful;
      case HalalStatus.haram:    return SealKind.haram;
      case HalalStatus.unknown:  return SealKind.unknown;
    }
  }

  String _g(double v) =>
      v == v.roundToDouble() ? '${v.round()}g' : '${v.toStringAsFixed(1)}g';

  // ── Total summary bar ──────────────────────────
  Widget _totalSummaryBar(List<FoodPhotoResult> items, bool isAr, bool isDark) {
    final totalKcal  = items.fold(0,    (s, r) => s + r.kcal);
    final totalProt  = items.fold(0.0,  (s, r) => s + r.proteinG);
    final totalCarbs = items.fold(0.0,  (s, r) => s + r.carbsG);
    final totalFat   = items.fold(0.0,  (s, r) => s + r.fatG);
    final eP = totalProt * 4, eC = totalCarbs * 4, eF = totalFat * 9;
    final eT = (eP + eC + eF) <= 0 ? 1.0 : (eP + eC + eF);
    return Reveal(
      offset: 0.08,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              AppColors.accentGold.withOpacity(0.18),
              AppColors.accentGold.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.accentGold.withOpacity(0.45))),
        child: Column(children: [
          Row(children: [
            const PaintedGlyph(kind: GlyphKind.flame, color: AppColors.accentGold, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tLang(lang, 'مجموع الوجبة', 'Meal total', 'Total du repas', 'Öğün toplamı', 'Jumlah hidangan', 'Total hidangan'),
                style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                    color: AppColors.accentGold)),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                CountUp(value: totalKcal,
                  style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w900,
                      fontSize: 30, color: AppColors.accentGold, height: 1.1)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(tLang(lang, 'سعرة', 'kcal'),
                    style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                        color: AppColors.accentGold)),
                ),
              ]),
            ])),
            GlyphChip(
              glyph: GlyphKind.check, color: AppColors.accentGold,
              text: '${items.length} ${isAr ? "صنف" : "items"}'),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            MacroRing(value: _g(totalProt), pct: eP / eT, color: AppColors.halalGreen, size: 60,
                label: tLang(lang, 'بروتين', 'Protein', 'Protéines', 'Protein', 'Protein', 'Protein')),
            MacroRing(value: _g(totalCarbs), pct: eC / eT, color: AppColors.waterBlue, size: 60,
                label: tLang(lang, 'كربوهيدرات', 'Carbs', 'Glucides', 'Karbonhidrat', 'Karbohidrat', 'Karbohidrat')),
            MacroRing(value: _g(totalFat), pct: eF / eT, color: AppColors.accentGold, size: 60,
                label: tLang(lang, 'دهون', 'Fat', 'Lipides', 'Yağ', 'Lemak', 'Lemak')),
          ]),
        ]),
      ),
    );
  }

  Widget _resultCard(FoodPhotoResult r, bool isAr, bool isDark, Color bg, Color muted,
      {int itemIndex = 1, int totalItems = 1}) {
    final col     = _statusColor(r.halalStatus);
    final name    = isAr ? r.foodName : r.foodNameEn;
    final label   = isAr ? r.halalStatus.label : r.halalStatus.labelEn;
    final expl    = isAr ? r.halalExplanation : r.halalExplanationEn;
    final tip     = (isAr ? r.tipNote : r.tipNoteEn) ?? '';
    final added   = _addedIdx.contains(itemIndex - 1);
    final conf    = r.confidence.clamp(0.0, 1.0).toDouble();
    final eP = r.proteinG * 4, eC = r.carbsG * 4, eF = r.fatG * 9;
    final eT = (eP + eC + eF) <= 0 ? 1.0 : (eP + eC + eF);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color.lerp(bg, col, isDark ? 0.16 : 0.10)!, bg],
        ),
        border: Border.all(color: col.withOpacity(0.45), width: 1.3),
        boxShadow: [BoxShadow(color: col.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Verdict + name + confidence ────────────────
          Row(children: [
            VerdictSeal(kind: _sealKind(r.halalStatus), color: col, size: 74),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (totalItems > 1)
                Text('$itemIndex / $totalItems',
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
              Text(name, style: const TextStyle(fontFamily: 'Aligarh',
                  fontWeight: FontWeight.w900, fontSize: 19)),
              Text(label, style: TextStyle(fontFamily: 'Aligarh',
                  fontWeight: FontWeight.w800, fontSize: 14, color: col)),
            ])),
            MacroRing(
              value: '${(conf * 100).round()}%',
              label: tLang(lang, 'دقة', 'conf.', 'conf.', 'conf.', 'conf.', 'conf.'),
              pct: conf, color: AppColors.accentGold, size: 52),
          ]),

          if (expl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(expl, style: TextStyle(fontFamily: 'Aligarh',
                  fontSize: 12, color: muted, height: 1.45)),
            ),

          const Divider(height: 26),

          // ── Calories ───────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const PaintedGlyph(kind: GlyphKind.flame, color: AppColors.haramRed, size: 36),
            const SizedBox(width: 10),
            CountUp(value: r.kcal,
              style: const TextStyle(fontFamily: 'Aligarh', fontSize: 54,
                  fontWeight: FontWeight.w900, color: AppColors.haramRed, height: 1)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tLang(lang, 'سعرة حرارية', 'kcal', 'kcal', 'kcal', 'kcal', 'kcal'),
                style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
                    fontWeight: FontWeight.w700, color: muted)),
              if (r.portionSize.isNotEmpty)
                Text(r.portionSize,
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: muted)),
            ]),
          ]),

          const SizedBox(height: 16),

          // ── Macro share rings ──────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            MacroRing(value: _g(r.proteinG), pct: eP / eT, color: AppColors.halalGreen, size: 64,
                label: tLang(lang, 'بروتين', 'Protein', 'Protéines', 'Protein', 'Protein', 'Protein')),
            MacroRing(value: _g(r.carbsG), pct: eC / eT, color: AppColors.waterBlue, size: 64,
                label: tLang(lang, 'كربوهيدرات', 'Carbs', 'Glucides', 'Karbonhidrat', 'Karbohidrat', 'Karbohidrat')),
            MacroRing(value: _g(r.fatG), pct: eF / eT, color: AppColors.accentGold, size: 64,
                label: tLang(lang, 'دهون', 'Fat', 'Lipides', 'Yağ', 'Lemak', 'Lemak')),
          ]),
          const SizedBox(height: 6),
          Text(
            tLang(lang, 'حصة كل عنصر من السعرات', 'Share of calories from each', 'Part des calories de chacun', 'Kalorideki payı', 'Bahagian kalori', 'Porsi kalori'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 9, color: muted)),

          // ── Practical tip ──────────────────────────────
          if (tip.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentGold.withOpacity(0.30)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const PaintedGlyph(kind: GlyphKind.bulb, color: AppColors.accentGold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tip, style: TextStyle(fontFamily: 'Aligarh',
                      fontSize: 11, height: 1.5, color: muted))),
                ]),
              ),
            ),

          // ── Ingredients ────────────────────────────────
          if (r.ingredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tLang(lang, 'المكونات الرئيسية', 'Main ingredients', 'Ingrédients principaux', 'Ana malzemeler', 'Bahan-bahan utama', 'Bahan-bahan utama'),
                  style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: r.ingredients.map((ing) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.brandGreen.withOpacity(0.32), width: 0.8),
                  ),
                  child: Text(ing, style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                      fontWeight: FontWeight.w600, color: AppColors.halalGreen)),
                )).toList()),
              ]),
            ),

          const SizedBox(height: 16),

          // ── Actions ────────────────────────────────────
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: added ? null : () {
                HapticFeedback.mediumImpact();
                _addToTracker(r);
                setState(() => _addedIdx.add(itemIndex - 1));
              },
              icon: Icon(added ? Icons.check_rounded : Icons.add_rounded,
                  color: Colors.white, size: 18),
              label: Text(
                added
                  ? tLang(lang, 'أُضيف', 'Added', 'Ajouté', 'Eklendi', 'Ditambah', 'Ditambahkan')
                  : tLang(lang, 'أضف للعداد', 'Add to Tracker', 'Ajouter au suivi', 'Takibe Ekle', 'Tambah ke Penjejak', 'Tambah ke Pelacak'),
                style: const TextStyle(fontFamily: 'Aligarh', color: Colors.white,
                    fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                disabledBackgroundColor: AppColors.brandGreen.withOpacity(0.55),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _image = null; _results = []; _state = AnalysisState.idle; _addedIdx.clear();
              }),
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.brandGreen),
              label: Text(tLang(lang, 'جديد', 'New', 'Nouveau', 'Yeni', 'Baru', 'Baru'),
                style: const TextStyle(fontFamily: 'Aligarh', color: AppColors.brandGreen)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                side: const BorderSide(color: AppColors.brandGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ]),

          const SizedBox(height: 12),
          Text(
            tLang(lang, '* النتائج تقديرية من Claude AI — دقة ٧٠-٩٠٪ حسب وضوح الصورة', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity'),
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 9, color: muted, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  // ── Quick Entry sheet launcher ──────────────────
  void _showQuickEntrySheet(bool isAr, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickEntrySheet(
        isAr: isAr,
        isDark: isDark,
        onAdd: (r) {
          _addToTracker(r);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _tipsCard(bool isAr, bool isDark, Color bg, Color muted) {
    final tips = isAr
        ? ['التقط الصورة من فوق مباشرةً', 'استخدم إضاءة جيدة', 'اجعل الطبق يملأ معظم الصورة', 'تجنب الصور المعتمة أو المضببة', 'الأطعمة المفردة تعطي نتائج أدق']
        : ['Take the photo from directly above', 'Use good lighting', 'Fill the frame with the food', 'Avoid dark or blurry photos', 'Single food items give more accurate results'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE8E4DF), width: 0.6),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PaintedGlyph(kind: GlyphKind.bulb, color: AppColors.accentGold, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(
            tLang(lang, 'نصائح للحصول على نتائج أدق', 'Tips for better results', 'Conseils pour de meilleurs résultats', 'Daha iyi sonuçlar için ipuçları', 'Petua untuk hasil lebih baik', 'Tips untuk hasil lebih baik'),
            style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
        const SizedBox(height: 12),
        for (var i = 0; i < tips.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentGold.withOpacity(0.16),
                  border: Border.all(color: AppColors.accentGold.withOpacity(0.4), width: 0.8),
                ),
                child: Center(child: Text('${i + 1}', style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 11, fontWeight: FontWeight.w800,
                    color: AppColors.accentGold))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(tips[i], style: TextStyle(fontFamily: 'Aligarh',
                    fontSize: 12, color: muted, height: 1.4)),
              )),
            ]),
          ),
      ]),
    );
  }

  Color _statusColor(HalalStatus s) {
    switch (s) {
      case HalalStatus.halal:    return AppColors.halalGreen;
      case HalalStatus.doubtful: return AppColors.doubtOrange;
      case HalalStatus.haram:    return AppColors.haramRed;
      case HalalStatus.unknown:  return Colors.grey;
    }
  }
}

// ======================================================================
//  _QuickEntrySheet
// ======================================================================
class _QuickEntrySheet extends ConsumerStatefulWidget {
  final bool isAr;
  final bool isDark;
  final void Function(FoodPhotoResult) onAdd;
  const _QuickEntrySheet({required this.isAr, required this.isDark, required this.onAdd});
  @override
  ConsumerState<_QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<_QuickEntrySheet> {
  String get lang => ref.read(languageProvider);
  final _ctrl = TextEditingController();
  bool _loading = false;
  List<FoodPhotoResult> _aiResults = [];
  String? _error;

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _analyze() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _aiResults = []; _error = null; });
    try {
      final lang = ref.read(languageProvider);
      final results = await AIService.quickTextEntry(description: text, language: lang);
      if (mounted) setState(() { _aiResults = results; _loading = false; });
    } on ApiKeyMissingException {
      if (mounted) setState(() {
        _error = tLang(lang, 'API key not configured', 'API key not configured', 'Clé API non configurée', 'API anahtarı yapılandırılmamış', 'Kunci API tidak dikonfigurasi', 'Kunci API belum dikonfigurasi');
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = tLang(lang, 'Error - try again', 'Error - try again', 'Erreur - réessayez', 'Hata - tekrar deneyin', 'Ralat - cuba lagi', 'Error - coba lagi');
        _loading = false;
      });
    }
  }

  void _addQuickFood(QuickFood food) {
    final r = FoodPhotoResult(
      foodName: widget.isAr ? food.name : food.nameEn,
      foodNameEn: food.nameEn,
      kcal: food.kcal,
      proteinG: food.proteinG,
      carbsG: food.carbsG,
      fatG: food.fatG,
      halalStatus: HalalStatus.halal,
      halalExplanation: '',
      halalExplanationEn: '',
      tipNote: '',
      tipNoteEn: '',
    );
    widget.onAdd(r);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isAr  = widget.isAr;
    final isDark = widget.isDark;
    final bg    = isDark ? AppColors.darkCard  : Colors.white;
    final surf  = isDark ? AppColors.darkBg    : const Color(0xFFF5F5F5);
    final textC = isDark ? AppColors.darkText  : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: muted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.flash_on_rounded, color: AppColors.accentGold, size: 22),
                const SizedBox(width: 8),
                Text('Quick Entry',
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 18,
                      fontWeight: FontWeight.w900, color: textC)),
              ]),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _ctrl,
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _analyze(),
                  decoration: InputDecoration(
                    hintText: tLang(lang, 'What did you eat?', 'What did you eat? (e.g. 2 eggs and rice)', 'Qu\'avez-vous mangé ? (ex: 2 œufs et riz)', 'Ne yediniz? (örn: 2 yumurta ve pirinç)', 'Apa yang anda makan? (cth: 2 telur dan nasi)', 'Apa yang Anda makan? (misal: 2 telur dan nasi)'),
                    hintStyle: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: muted),
                    filled: true, fillColor: surf,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                  style: TextStyle(fontFamily: 'Aligarh', color: textC, fontSize: 13),
                )),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _analyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    minimumSize: Size.zero,
                  ),
                  child: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
              ]),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(_error!,
                    style: const TextStyle(fontFamily: 'Aligarh',
                        color: AppColors.haramRed, fontSize: 12)),
              ),
            if (_aiResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AI Results',
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
                        fontWeight: FontWeight.w700, color: AppColors.accentGold)),
                  const SizedBox(height: 8),
                  ..._aiResults.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isAr ? r.foodName : r.foodNameEn,
                          style: TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w700,
                              fontSize: 14, color: textC)),
                        Text('${r.kcal} kcal  P ${r.proteinG.toInt()}g  C ${r.carbsG.toInt()}g  F ${r.fatG.toInt()}g',
                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: muted)),
                      ])),
                      ElevatedButton(
                        onPressed: () => widget.onAdd(r),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('+ Add',
                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                              fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ]),
                  )),
                ]),
              ),
            Expanded(child: GridView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: kQuickFoods.length,
              itemBuilder: (_, i) {
                final food = kQuickFoods[i];
                return InkWell(
                  onTap: () => _addQuickFood(food),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: muted.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isAr ? food.name : food.nameEn,
                            style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                                fontWeight: FontWeight.w600, color: textC),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${food.kcal} kcal',
                            style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
                        ],
                      )),
                      const SizedBox(width: 4),
                      Icon(Icons.add_circle_outline, size: 18, color: AppColors.brandGreen),
                    ]),
                  ),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }
}
