// ============================================================
//  food_photo_screen.dart — HalalCalorie v1.0
//  AI-Powered Food Photo Analyzer
//  Camera / Gallery → Claude Vision → Nutrition + Halal check
// ============================================================

import 'dart:io'; import'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:image_picker/image_picker.dart'; import'../../core/theme.dart'; import'../../core/providers.dart'; import'../../core/ai_service.dart'; import'../../data/models/models.dart';

// ── Analysis state ─────────────────────────────
enum AnalysisState { idle, analyzing, done, error }

class FoodPhotoScreen extends ConsumerStatefulWidget {
  const FoodPhotoScreen({super.key});
  @override ConsumerState<FoodPhotoScreen> createState() => _FoodPhotoState();
}

class _FoodPhotoState extends ConsumerState<FoodPhotoScreen>
    with SingleTickerProviderStateMixin {

  final _picker = ImagePicker();
  File?           _image;
  AnalysisState   _state  = AnalysisState.idle;
  FoodPhotoResult? _result;
  String?         _error;

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
        _result  = null;
        _error   = null;
      });
    } catch (e) { final isAr = ref.read(languageProvider) =='ar';
      if (mounted) setState(() {
        _error = isAr ?'تعذّر فتح الكاميرا. تأكد من إذن الكاميرا في الإعدادات.' :'Could not open camera. Check camera permissions in settings.';
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
      if (mounted) setState(() { _result = result; _state = AnalysisState.done; });
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() { _error = lang =='ar' ?'تعذّر التحليل. تحقق من اتصالك بالإنترنت.' :'Analysis failed. Check your internet connection.';
        _state = AnalysisState.error;
      });
    }
  }

  // ── Add to tracker ────────────────────────────
  void _addToTracker() {
    if (_result == null) return;
    final lang  = ref.read(languageProvider); final isAr  = lang =='ar';
    ref.read(caloriesProvider.notifier).addEntry(
      isAr ? _result!.foodName : _result!.foodNameEn,
      _result!.kcal,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text(isAr ?'✓ تمت الإضافة للعداد' : '✓ Added to tracker', style: const TextStyle(fontFamily:'Cairo')),
      backgroundColor: AppColors.sunnahGreen,
      duration: const Duration(seconds: 2),
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
            if (_state == AnalysisState.error && _error != null)
              _errorCard(_error!, isAr, isDark),

            // ── Results ───────────────────────────────────
            if (_state == AnalysisState.done && _result != null) ...[
              const SizedBox(height: 16),
              _resultCard(_result!, isAr, isDark, bg, muted),
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
          isAr ?'التقط صورة لطعامك\nوسأحلله فوراً' :'Take a photo of your food\nand I\'ll analyze it instantly',
          textAlign: TextAlign.center, style: const TextStyle(fontFamily:'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, height: 1.5),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 6, children: [ _badge('🔥', isAr ? 'سعرات' : 'Calories'), _badge('🥩', isAr ? 'بروتين' : 'Protein'), _badge('🍚', isAr ? 'كربوهيدرات' : 'Carbs'), _badge('✅', isAr ? 'حكم حلال' : 'Halal Check'),
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
        Text( isAr ?'جاري التحليل…' : 'Analyzing…', style: const TextStyle(fontFamily:'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          isAr ?'Claude AI يتعرف على الطعام\nويحسب القيم الغذائية والحكم الشرعي' :'Claude AI is identifying the food\nand calculating nutritional values & halal status',
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

  Widget _resultCard(FoodPhotoResult r, bool isAr, bool isDark, Color bg, Color muted) {
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
            Text(name, style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w900, fontSize: 18)),
            Text(r.halalStatus.label, style: TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700, fontSize: 13, color: statusColor)),
            if ((r.halalExplanation).isNotEmpty)
              Text(r.halalExplanation, style: TextStyle(fontFamily:'Cairo', fontSize: 11, color: muted, height: 1.4)),
          ])),
          Column(children: [ Text('$confPct%', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: muted)), Text(isAr ?'دقة' : 'conf.', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: muted)),
          ]),
        ]),
      ),

      // ── Calorie big number ────────────────────────────
      Container(
        color: bg,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Column(children: [ Text('${r.kcal}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 52, fontWeight: FontWeight.w900, color: AppColors.haramRed, height: 1)), Text(isAr ?'سعرة حرارية • ${r.portionSize}' : 'kcal • ${r.portionSize}', style: TextStyle(fontFamily:'Cairo', fontSize: 12, color: muted)),
          ]),
        ]),
      ),

      // ── Macros row ────────────────────────────────────
      Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(children: [ _macroChip(isAr ?'بروتين' : 'Protein', '${r.proteinG}g', AppColors.halalGreen),
          const SizedBox(width: 8), _macroChip(isAr ?'كربوهيدرات' : 'Carbs', '${r.carbsG}g', AppColors.waterBlue),
          const SizedBox(width: 8), _macroChip(isAr ?'دهون' : 'Fat', '${r.fatG}g', AppColors.barakahGold),
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
              Expanded(child: Text(r.sunnahNote ?? '', style: const TextStyle(fontFamily:'Cairo', fontSize: 11, height: 1.5, color: AppColors.lightMuted))),
            ]),
          ),
        ),

      // ── Ingredients ───────────────────────────────────
      if (r.ingredients.isNotEmpty)
        Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(isAr ?'🥗 المكونات الرئيسية:' : '🥗 Main ingredients:', style: const TextStyle(fontFamily:'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
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
            onPressed: _addToTracker,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sunnahGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ), child: Text(isAr ?'+ أضف للعداد' : '+ Add to Tracker', style: const TextStyle(fontFamily:'Cairo', color: Colors.white, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => setState(() { _image = null; _result = null; _state = AnalysisState.idle; }),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              side: const BorderSide(color: AppColors.sunnahGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ), child: Text(isAr ?'↺ جديد' : '↺ New', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.sunnahGreen)),
          ),
        ]),
      ),

      const SizedBox(height: 4),
      Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text(
          isAr ?'* النتائج تقديرية من Claude AI — دقة ٧٠-٩٠٪ حسب وضوح الصورة' :'* Results are AI estimates — 70-90% accuracy depending on photo clarity', style: TextStyle(fontFamily:'Cairo', fontSize: 9, color: muted, height: 1.5),
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

  Widget _tipsCard(bool isAr, bool isDark, Color bg, Color muted) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(isAr ?'💡 نصائح للحصول على نتائج أدق' : '💡 Tips for better results', style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
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
