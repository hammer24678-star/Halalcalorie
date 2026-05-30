import 'package:go_router/go_router.dart';
// ============================================================
//  food_photo_screen.dart — HalalCalorie v1.0
//  AI-Powered Food Photo Analyzer
//  Camera / Gallery → Claude Vision → Nutrition + Halal check
// ============================================================

import 'dart:io'; import'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:image_picker/image_picker.dart'; import'../../core/theme.dart'; import'../../core/providers.dart'; import'../../core/ai_service.dart'; import'../../data/models/models.dart';
import '../../core/l10n.dart';
import'../../core/l10n.dart';

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

  // Shimmer animation for loading
  late AnimationController _shimmer;
  late Animation<double>   _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _shimmerAnim = Tween(begin: 0.3, end: 1.0).animate(_shimmer);
  }

  @override void dispose() { _shimmer.dispose(); super.dispose(); }

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
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            content: Text(
              isAr
                ? 'لقد استخدمت 3 تحليلات مجانية.\nاشترك في البريميوم للحصول على تحليلات غير محدودة 🌟'
                : 'You have used your 3 free AI scans.\nUpgrade to Premium for unlimited scans 🌟',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isAr ? 'لاحقاً' : 'Later')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sunnahGreen,
                  foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/paywall');
                },
                child: Text(isAr ? 'ترقية 🌟' : 'Upgrade 🌟',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800))),
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
    if (mounted) setState(() { _state = AnalysisState.analyzing; _error = null; });

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
      final msg = errStr.contains('GROQ_API_KEY') || errStr.contains('401')
        ? (lang == 'ar' ? 'مفتاح API غير مُعدّ — أضفه في GitHub Secrets' : 'API key not configured — add it to GitHub Secrets')
        : errStr.contains('timeout') || errStr.contains('TimeoutException')
        ? (lang == 'ar' ? 'انتهت مهلة الاتصال، حاول مجدداً' : 'Connection timed out, try again')
        : (lang == 'ar' ? 'تعذّر التحليل: $errStr' : 'Analysis failed: $errStr');
      if (mounted) setState(() { _error = msg; _state = AnalysisState.error; });
    }
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
        style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: AppColors.sunnahGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Add ALL results to tracker ─────────────────
  void _addAllToTracker() {
    final lang = ref.read(languageProvider);
    final isAr = lang == 'ar';
    for (final r in _results) {
      ref.read(caloriesProvider.notifier).addEntry(
        isAr ? r.foodName : r.foodNameEn,
        r.kcal,
        proteinG: r.proteinG,
        carbsG:   r.carbsG,
        fatG:     r.fatG,
      );
    }
    final total = _results.fold(0, (s, r) => s + r.kcal);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        tLang(lang, '✓ أُضيفت كل الأطعمة ($total سعرة)', '✓ All foods added ($total kcal)', '✓ All foods added ($total kcal)', '✓ All foods added ($total kcal)', '✓ All foods added ($total kcal)', '✓ All foods added ($total kcal)'),
        style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: AppColors.sunnahGreen,
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
        appBar: AppBar( title: Text(t('📸 تحليل الطعام بـ AI', '📸 AI Food Analyzer')),
          backgroundColor: AppColors.sunnahGreen,
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
            // ── Intro banner ─────────────────────────────
            if (_image == null) _introBanner(isAr, isDark),

            // ── Image preview ─────────────────────────────
            if (_image != null) _imagePreview(bg),

            const SizedBox(height: 14),

            // ── Pick buttons ──────────────────────────────
            Row(children: [
              Expanded(child: _pickBtn(
                icon: Icons.camera_alt, label: t('📷 الكاميرا', '📷 Camera'),
                color: AppColors.sunnahGreen,
                onTap: () => _pick(ImageSource.camera),
              )),
              const SizedBox(width: 10),
              Expanded(child: _pickBtn(
                icon: Icons.photo_library, label: t('🖼️ المعرض', '🖼️ Gallery'),
                color: AppColors.waterBlue,
                onTap: () => _pick(ImageSource.gallery),
              )),
            ]),

            const SizedBox(height: 12),

            // ── Analyze button ────────────────────────────
            if (_image != null && _state != AnalysisState.analyzing)
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: _analyze, icon: const Text('🤖', style: TextStyle(fontSize: 18)), label: Text(t('تحليل الآن 🔍', 'Analyze Now 🔍'), style: const TextStyle(fontFamily:'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.barakahGold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              )),

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
              // Total summary bar if multiple items
              if (_results.length > 1) _totalSummaryBar(_results, isAr, isDark),
              ..._results.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _resultCard(e.value, isAr, isDark, bg, muted,
                    itemIndex: e.key + 1, totalItems: _results.length),
              )),
              // Add All button when multiple foods
              if (_results.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _addAllToTracker,
                    icon: const Icon(Icons.playlist_add, color: Colors.white),
                    label: Text(
                      tLang(lang, 'إضافة كل الأطعمة للعداد (${_results.fold(0,(s,r)=>s+r.kcal)} سعرة)', 'Add All Foods to Tracker (${_results.fold(0,(s,r)=>s+r.kcal)} kcal)', 'Add All Foods to Tracker (${_results.fold(0,(s,r)=>s+r.kcal)} kcal)', 'Add All Foods to Tracker (${_results.fold(0,(s,r)=>s+r.kcal)} kcal)', 'Add All Foods to Tracker (${_results.fold(0,(s,r)=>s+r.kcal)} kcal)', 'Add All Foods to Tracker (${_results.fold(0,(s,r)=>s+r.kcal)} kcal)'),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sunnahGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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

  Widget _introBanner(bool isAr, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.sunnahGreen, AppColors.darkGreen],
          begin: Alignment.topRight, end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.sunnahGreen.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: [ const Text('📸', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 10),
        Text(
          tLang(lang, 'التقط صورة لطعامك\nوسأحلله فوراً', 'Take a photo of your food\nand I\'ll analyze it instantly', 'Prenez une photo de votre repas\net analysez-la instantanément', 'Yemeğinizin fotoğrafını çekin\nve anında analiz edeceğim', 'Ambil foto makanan anda\ndan saya akan menganalisisnya', 'Ambil foto makanan Anda\ndan saya akan menganalisisnya'),
          textAlign: TextAlign.center, style: const TextStyle(fontFamily:'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, height: 1.5),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 6, children: [ _badge('🔥', tLang(lang, 'سعرات', 'Calories', 'Calories', 'Kalori', 'Kalori', 'Kalori')), _badge('🥩', tLang(lang, 'بروتين', 'Protein', 'Protéines', 'Protein', 'Protein', 'Protein')), _badge('🍚', tLang(lang, 'كربوهيدرات', 'Carbs', 'Glucides', 'Karbonhidrat', 'Karbohidrat', 'Karbohidrat')), _badge('✅', tLang(lang, 'حكم حلال', 'Halal Check', 'Vérification Halal', 'Helal Kontrol', 'Semakan Halal', 'Cek Halal')),
        ]),
      ]),
    );
  }

  Widget _badge(String emoji, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text('$emoji $text', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
  );

  Widget _imagePreview(Color bg) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          Image.file(_image!, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image, color: Colors.grey, size: 48)),
          if (_state == AnalysisState.analyzing)
            Container(
              color: Colors.black45,
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: AppColors.barakahGold, strokeWidth: 3),
                const SizedBox(height: 10), const Text('🤖', style: TextStyle(fontSize: 28)),
              ])),
            ),
        ]),
      ),
    );
  }

  Widget _pickBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4), Text(label, style: TextStyle(fontFamily:'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  Widget _loadingCard(bool isAr, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(children: [
        AnimatedBuilder(
          animation: _shimmerAnim,
          builder: (_, __) => Opacity(
            opacity: _shimmerAnim.value, child: const Text('🤖', style: TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: 10),
        Text( tLang(lang, 'جاري التحليل…', 'Analyzing…', 'Analyse en cours…', 'Analiz ediliyor…', 'Menganalisis…', 'Menganalisis…'), style: const TextStyle(fontFamily:'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          tLang(lang, 'Claude AI يتعرف على الطعام\nويحسب القيم الغذائية والحكم الشرعي', 'Claude AI is identifying the food\nand calculating nutritional values & halal status', 'Claude AI is identifying the food\nand calculating nutritional values & halal status', 'Claude AI is identifying the food\nand calculating nutritional values & halal status', 'Claude AI is identifying the food\nand calculating nutritional values & halal status', 'Claude AI is identifying the food\nand calculating nutritional values & halal status'),
          textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 12,
            color: isDark ? AppColors.darkMuted : AppColors.lightMuted, height: 1.6),
        ),
        const SizedBox(height: 14),
        const LinearProgressIndicator(
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation(AppColors.sunnahGreen),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.doubtOrange.withOpacity(0.6), width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('⚠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(
            tLang(lang, 'مفتاح AI غير مُعدّ', 'AI Key Not Configured', 'Clé AI non configurée', 'AI Anahtarı Yapılandırılmamış', 'Kunci AI Tidak Dikonfigurasi', 'Kunci AI Belum Dikonfigurasi'),
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                fontSize: 14, color: AppColors.doubtOrange))),
        ]),
        const SizedBox(height: 8),
        Text(
          tLang(lang, 'أضف ANTHROPIC_API_KEY في GitHub Secrets ثم أعد البناء:\nSettings → Secrets → Actions', 'Add ANTHROPIC_API_KEY to GitHub repo secrets and rebuild.\nSettings → Secrets and variables → Actions', 'Add ANTHROPIC_API_KEY to GitHub repo secrets and rebuild.\nSettings → Secrets and variables → Actions', 'Add ANTHROPIC_API_KEY to GitHub repo secrets and rebuild.\nSettings → Secrets and variables → Actions', 'Add ANTHROPIC_API_KEY to GitHub repo secrets and rebuild.\nSettings → Secrets and variables → Actions', 'Add ANTHROPIC_API_KEY to GitHub repo secrets and rebuild.\nSettings → Secrets and variables → Actions'),
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12,
              color: Colors.white70, height: 1.5)),
        const SizedBox(height: 12),
        Text(
          'docs.codemagic.io → Environment variables',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 10,
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
      child: Row(children: [ const Text('⚠️', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(child: Text(error, style: const TextStyle(fontFamily:'Cairo', fontSize: 12, color: AppColors.haramRed, height: 1.5))),
      ]),
    );
  }

  // ── Total summary bar ──────────────────────────
  Widget _totalSummaryBar(List<FoodPhotoResult> items, bool isAr, bool isDark) {
    final totalKcal  = items.fold(0,    (s, r) => s + r.kcal);
    final totalProt  = items.fold(0.0,  (s, r) => s + r.proteinG);
    final totalCarbs = items.fold(0.0,  (s, r) => s + r.carbsG);
    final totalFat   = items.fold(0.0,  (s, r) => s + r.fatG);
    final card = isDark ? AppColors.darkCard : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.barakahGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.barakahGold.withOpacity(0.4))),
      child: Column(children: [
        Text(
          tLang(lang, '📊 المجموع: $totalKcal سعرة', '📊 Total: $totalKcal kcal', '📊 Total: $totalKcal kcal', '📊 Total: $totalKcal kcal', '📊 Total: $totalKcal kcal', '📊 Total: $totalKcal kcal'),
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
              fontSize: 16, color: AppColors.barakahGold)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _macroChip('💪 P', '${totalProt.toInt()}g', AppColors.sunnahGreen),
          _macroChip('🍚 C', '${totalCarbs.toInt()}g', AppColors.waterBlue),
          _macroChip('🥑 F', '${totalFat.toInt()}g', AppColors.doubtOrange),
          _macroChip('🍽️', '${items.length} ${isAr ? "صنف" : "items"}', AppColors.barakahGold),
        ]),
      ]),
    );
  }

  Widget _resultCard(FoodPhotoResult r, bool isAr, bool isDark, Color bg, Color muted,
      {int itemIndex = 1, int totalItems = 1}) {
    final statusColor = _statusColor(r.halalStatus);
    final name = isAr ? r.foodName : r.foodNameEn;
    final confPct = (r.confidence * 100).toInt();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Header: Food name + halal badge ──────────────
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [statusColor.withOpacity(0.15), statusColor.withOpacity(0.05)],
          ),
          border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(children: [
          Text(r.halalStatus.emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (totalItems > 1)
              Text('$itemIndex / $totalItems',
                style: const TextStyle(fontFamily:'Cairo', fontSize: 10, color: AppColors.lightMuted)),
            Text(name, style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w900, fontSize: 18)),
            Text(isAr ? r.halalStatus.label : r.halalStatus.labelEn, style: TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700, fontSize: 13, color: statusColor)),
            if ((isAr ? r.halalExplanation : r.halalExplanationEn).isNotEmpty)
              Text(isAr ? r.halalExplanation : r.halalExplanationEn, style: TextStyle(fontFamily:'Cairo', fontSize: 11, color: muted, height: 1.4)),
          ])),
          Column(children: [ Text('$confPct%', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: muted)), Text(tLang(lang, 'دقة', 'conf.', 'conf.', 'conf.', 'conf.', 'conf.'), style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: muted)),
          ]),
        ]),
      ),

      // ── Calorie big number ────────────────────────────
      Container(
        color: bg,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Column(children: [ Text('${r.kcal}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 52, fontWeight: FontWeight.w900, color: AppColors.haramRed, height: 1)), Text(tLang(lang, 'سعرة حرارية • ${r.portionSize}', 'kcal • ${r.portionSize}', 'kcal • ${r.portionSize}', 'kcal • ${r.portionSize}', 'kcal • ${r.portionSize}', 'kcal • ${r.portionSize}'), style: TextStyle(fontFamily:'Cairo', fontSize: 12, color: muted)),
          ]),
        ]),
      ),

      // ── Macros row ────────────────────────────────────
      Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(children: [ _macroChip(tLang(lang, 'بروتين', 'Protein', 'Protéines', 'Protein', 'Protein', 'Protein'), '${r.proteinG}g', AppColors.halalGreen),
          const SizedBox(width: 8), _macroChip(tLang(lang, 'كربوهيدرات', 'Carbs', 'Glucides', 'Karbonhidrat', 'Karbohidrat', 'Karbohidrat'), '${r.carbsG}g', AppColors.waterBlue),
          const SizedBox(width: 8), _macroChip(tLang(lang, 'دهون', 'Fat', 'Lipides', 'Yağ', 'Lemak', 'Lemak'), '${r.fatG}g', AppColors.barakahGold),
        ]),
      ),

      // ── Sunnah note ───────────────────────────────────
      if ((r.sunnahNote ?? '').isNotEmpty)
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.barakahGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.barakahGold.withOpacity(0.3)),
            ),
            child: Row(children: [ const Text('📖', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text((isAr ? r.sunnahNote : r.sunnahNoteEn) ?? '', style: const TextStyle(fontFamily:'Cairo', fontSize: 11, height: 1.5, color: AppColors.lightMuted))),
            ]),
          ),
        ),

      // ── Ingredients ───────────────────────────────────
      if (r.ingredients.isNotEmpty)
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(tLang(lang, '🥗 المكونات الرئيسية:', '🥗 Main ingredients:', '🥗 Ingrédients principaux :', '🥗 Ana malzemeler:', '🥗 Bahan-bahan utama:', '🥗 Bahan-bahan utama:'), style: const TextStyle(fontFamily:'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: r.ingredients.map((ing) => Chip( label: Text(ing, style: const TextStyle(fontFamily:'Cairo', fontSize: 10, color: Colors.white)),
              backgroundColor: AppColors.sunnahGreen,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList()),
          ]),
        ),

      // ── Add to tracker button ─────────────────────────
      Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(children: [
          Expanded(child: ElevatedButton(
            onPressed: () => _addToTracker(r),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sunnahGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ), child: Text(tLang(lang, '+ أضف للعداد', '+ Add to Tracker', '+ Ajouter au suivi', '+ Takibe Ekle', '+ Tambah ke Penjejak', '+ Tambah ke Pelacak'), style: const TextStyle(fontFamily:'Cairo', color: Colors.white, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => setState(() { _image = null; _results = []; _state = AnalysisState.idle; }),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              side: const BorderSide(color: AppColors.sunnahGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ), child: Text(tLang(lang, '↺ جديد', '↺ New', '↺ Nouveau', '↺ Yeni', '↺ Baru', '↺ Baru'), style: const TextStyle(fontFamily: 'Cairo', color: AppColors.sunnahGreen)),
          ),
        ]),
      ),

      const SizedBox(height: 4),
      Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text(
          tLang(lang, '* النتائج تقديرية من Claude AI — دقة ٧٠-٩٠٪ حسب وضوح الصورة', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity'), style: TextStyle(fontFamily:'Cairo', fontSize: 9, color: muted, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ),

      Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
        ),
        height: 4,
      ),
    ]);
  }

  Widget _macroChip(String label, String val, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [ Text(val, style: TextStyle(fontFamily:'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: color)), Text(label, style: const TextStyle(fontFamily:'Cairo', fontSize: 9, color: AppColors.lightMuted)),
      ]),
    ));
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(tLang(lang, '💡 نصائح للحصول على نتائج أدق', '💡 Tips for better results', '💡 Conseils pour de meilleurs résultats', '💡 Daha iyi sonuçlar için ipucu', '💡 Petua untuk hasil lebih baik', '💡 Tips untuk hasil lebih baik'), style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        ...(isAr ? [ '📸 التقط الصورة من فوق مباشرةً', '💡 استخدم إضاءة جيدة', '🍽️ اجعل الطبق يملأ معظم الصورة', '🚫 تجنب الصور المعتمة أو المضببة', '✅ الأطعمة المفردة تعطي نتائج أدق',
        ] : [ '📸 Take the photo from directly above', '💡 Use good lighting', '🍽️ Fill the frame with the food', '🚫 Avoid dark or blurry photos', '✅ Single food items give more accurate results',
        ]).map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 5), child: Text(tip, style: TextStyle(fontFamily:'Cairo', fontSize: 12, color: muted, height: 1.4)),
        )),
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
      sunnahNote: '',
      sunnahNoteEn: '',
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
                const Icon(Icons.flash_on_rounded, color: AppColors.barakahGold, size: 22),
                const SizedBox(width: 8),
                Text('Quick Entry',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 18,
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
                    hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted),
                    filled: true, fillColor: surf,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  style: TextStyle(fontFamily: 'Cairo', color: textC, fontSize: 13),
                )),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _analyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.barakahGold,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    style: const TextStyle(fontFamily: 'Cairo',
                        color: AppColors.haramRed, fontSize: 12)),
              ),
            if (_aiResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AI Results',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13,
                        fontWeight: FontWeight.w700, color: AppColors.barakahGold)),
                  const SizedBox(height: 8),
                  ..._aiResults.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.barakahGold.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(isAr ? r.foodName : r.foodNameEn,
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                              fontSize: 14, color: textC)),
                        Text('${r.kcal} kcal  P ${r.proteinG.toInt()}g  C ${r.carbsG.toInt()}g  F ${r.fatG.toInt()}g',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: muted)),
                      ])),
                      ElevatedButton(
                        onPressed: () => widget.onAdd(r),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sunnahGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('+ Add',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
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
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                                fontWeight: FontWeight.w600, color: textC),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${food.kcal} kcal',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: muted)),
                        ],
                      )),
                      const SizedBox(width: 4),
                      Icon(Icons.add_circle_outline, size: 18, color: AppColors.sunnahGreen),
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
