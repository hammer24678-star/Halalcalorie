import 'package:image_picker/image_picker.dart';
// ============================================================
//  body_photo_screen.dart — HalalCalorie v1.0
//  AI Body Composition Photo Analyzer — Premium Feature
//  Front photo → Estimated body fat %, muscle, body type
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/ai_service.dart';
import '../../data/models/models.dart';
import '../../data/models/user_profile.dart';

enum BodyAnalysisState { idle, analyzing, done, error }

class BodyPhotoScreen extends ConsumerStatefulWidget {
  const BodyPhotoScreen({super.key});
  @override ConsumerState<BodyPhotoScreen> createState() => _BodyPhotoState();
}

class _BodyPhotoState extends ConsumerState<BodyPhotoScreen>
    with SingleTickerProviderStateMixin {

  final _picker = ImagePicker();
  File?              _image;
  BodyAnalysisState  _state  = BodyAnalysisState.idle;
  BodyPhotoResult?   _result;
  String?            _error;
  bool               _privacyConsented = false;

  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override void dispose() { _pulse.dispose(); super.dispose(); }

  Future<void> _pick(ImageSource src) async {
    try {
      final xf = await _picker.pickImage(
        source: src, imageQuality: 80,
        maxWidth: 1024, maxHeight: 1024,
      );
      if (xf == null) return;
      if (mounted) setState(() {
        _image  = File(xf.path);
        _state  = BodyAnalysisState.idle;
        _result = null;
        _error  = null;
      });
    } catch (e) {
      final isAr = ref.read(languageProvider) == 'ar';
      if (mounted) setState(() {
        _error = tLang(lang, 'تعذّر فتح الكاميرا.', 'Could not open camera.', 'Impossible d\'ouvrir la caméra.', 'Kamera açılamadı.', 'Tidak dapat buka kamera.', 'Tidak dapat membuka kamera.');
        _state = BodyAnalysisState.error;
      });
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    final profile = ref.read(userProfileProvider);
    final lang    = ref.read(languageProvider);

    if (mounted) setState(() { _state = BodyAnalysisState.analyzing; _error = null; });

    try {
      final result = await AIService.analyzeBodyPhoto(
        imagePath:  _image!.path,
        isMale:     profile?.isMale ?? true,
        weightKg:   profile?.weightKg ?? 70,
        heightCm:   profile?.heightCm ?? 170,
        age:        profile?.age ?? 25,
        language:   lang,
      );
      if (!mounted) return;
      if (mounted) setState(() { _result = result; _state = BodyAnalysisState.done; });
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() {
        _error = lang == 'ar'
          ? 'تعذّر التحليل. تحقق من اتصالك بالإنترنت.'
          : 'Analysis failed. Check your internet connection.';
        _state = BodyAnalysisState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang      = ref.watch(languageProvider);
    final isAr      = lang == 'ar';
    final isDark    = ref.watch(themeProvider);
    final isPremium = ref.watch(premiumProvider);
    final profile   = ref.watch(userProfileProvider);
    final bg        = isDark ? AppColors.darkCard : Colors.white;
    final muted     = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String t(String ar, String en) => isAr ? ar : en;

    // ── Premium gate ──────────────────────────────
    if (!isPremium) {
      return Scaffold(
        appBar: AppBar(title: Text(t('تحليل الجسم بالصورة 💪', 'Body Photo Analysis 💪'))),
        body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 14),
            Text(t('ميزة بريميوم حصرية', 'Premium Exclusive Feature'),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              t(
                'تحليل تركيبة جسمك من صورة واحدة:\n• تقدير نسبة الدهون\n• كتلة العضلات\n• نوع الجسم\n• توصيات شخصية',
                'Analyze your body composition from one photo:\n• Body fat % estimate\n• Muscle mass\n• Body type\n• Personalized recommendations',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: muted, height: 1.7),
            ),
            const SizedBox(height: 28),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.barakahGold, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(t('🔓 ترقية للبريميوم', '🔓 Upgrade to Premium'),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
            )),
          ],
        ))),
      );
    }

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('⭐ تحليل الجسم بـ AI', '⭐ AI Body Analysis')),
          backgroundColor: AppColors.barakahGold,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Privacy consent (required once) ──────────
            if (!_privacyConsented) _privacyCard(isAr, isDark, bg, muted),

            if (_privacyConsented) ...[
              // ── Hero / Instructions ───────────────────
              if (_image == null) _instructionsCard(isAr, isDark, profile),

              // ── Image preview ─────────────────────────
              if (_image != null) _imagePreview(),
              const SizedBox(height: 14),

              // ── Pick buttons ──────────────────────────
              Row(children: [
                Expanded(child: _pickBtn('📷', t('الكاميرا', 'Camera'), AppColors.barakahGold, () => _pick(ImageSource.camera))),
                const SizedBox(width: 10),
                Expanded(child: _pickBtn('🖼️', t('المعرض', 'Gallery'), AppColors.waterBlue, () => _pick(ImageSource.gallery))),
              ]),
              const SizedBox(height: 12),

              // ── Analyze button ────────────────────────
              if (_image != null && _state != BodyAnalysisState.analyzing)
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: _analyze,
                  icon: const Text('🤖', style: TextStyle(fontSize: 18)),
                  label: Text(t('تحليل الجسم 🔍', 'Analyze Body 🔍'),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.barakahGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                )),

              // ── Loading ───────────────────────────────
              if (_state == BodyAnalysisState.analyzing) _loadingCard(isAr, isDark),

              // ── Error ─────────────────────────────────
              if (_state == BodyAnalysisState.error && _error != null)
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.haramRed.withOpacity(0.08),
                    border: Border.all(color: AppColors.haramRed.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_error!, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.haramRed, fontSize: 12)),
                ),

              // ── Results ───────────────────────────────
              if (_state == BodyAnalysisState.done && _result != null) ...[
                const SizedBox(height: 16),
                _resultCard(_result!, isAr, isDark, bg, muted, profile),
              ],
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _privacyCard(bool isAr, bool isDark, Color bg, Color muted) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14)]),
      child: Column(children: [
        const Text('🔒', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 12),
        Text(
          tLang(lang, 'قبل المتابعة — موافقة الخصوصية', 'Before continuing — Privacy Consent', 'Avant de continuer — Consentement confidentialité', 'Devam etmeden — Gizlilik Onayı', 'Sebelum teruskan — Persetujuan Privasi', 'Sebelum melanjutkan — Persetujuan Privasi'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          isAr
            ? '• صورتك تُرسل بأمان إلى Claude AI للتحليل فقط\n'
              '• لا يتم حفظها أو مشاركتها مع أي طرف ثالث\n'
              '• تُحذف الصورة فور انتهاء التحليل\n'
              '• هذه الميزة للاستخدام الشخصي فحسب'
            : '• Your photo is securely sent to Claude AI for analysis only\n'
              '• It is never saved or shared with any third party\n'
              '• Photo is deleted immediately after analysis\n'
              '• This feature is for personal use only',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted, height: 1.8),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.doubtOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            tLang(lang, '⚠️ تحذير: هذه النتائج تقديرية وليست بديلاً عن فحص طبي متخصص', '⚠️ Warning: Results are estimates and not a substitute for professional medical assessment', '⚠️ Warning: Results are estimates and not a substitute for professional medical assessment', '⚠️ Warning: Results are estimates and not a substitute for professional medical assessment', '⚠️ Warning: Results are estimates and not a substitute for professional medical assessment', '⚠️ Warning: Results are estimates and not a substitute for professional medical assessment'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.doubtOrange, height: 1.5),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => setState(() => _privacyConsented = true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.sunnahGreen, padding: const EdgeInsets.symmetric(vertical: 13)),
          child: Text(tLang(lang, '✓ أوافق وأكمل', '✓ I Agree & Continue', '✓ J\'accepte & continue', '✓ Kabul ediyorum & devam', '✓ Saya Setuju & Teruskan', '✓ Saya Setuju & Lanjutkan'),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
        )),
      ]),
    );
  }

  Widget _instructionsCard(bool isAr, bool isDark, UserProfile? profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.barakahGold, Color(0xFFB8860B)],
          begin: Alignment.topRight, end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        const Text('💪', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 8),
        Text(
          tLang(lang, 'كيف تحصل على نتائج دقيقة؟', 'How to get accurate results?', 'Comment obtenir des résultats précis ?', 'Doğru sonuçlar nasıl elde edilir?', 'Bagaimana mendapat hasil tepat?', 'Cara mendapat hasil akurat?'),
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 10),
        ...(isAr ? [
          '🧍 وقف أمام الكاميرا بوضع مستقيم',
          '💡 إضاءة جيدة ومتساوية من الأمام',
          '👕 ملابس محتشمة وغير فضفاضة',
          '📐 تأكد من ظهور جسمك كاملاً',
          '🤲 يديك على الجانبين',
        ] : [
          '🧍 Stand straight facing the camera',
          '💡 Good, even lighting from the front',
          '👕 Modest, fitted clothing',
          '📐 Make sure your full body is visible',
          '🤲 Arms at your sides',
        ]).map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Align(alignment: Alignment.centerRight,
            child: Text(s, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70, height: 1.4))),
        )),
        if (profile != null) ...[
          const Divider(color: Colors.white24, height: 16),
          Text(
            tLang(lang, 'يستخدم AI بياناتك: ${profile.weightKg}كجم / ${profile.heightCm.toInt()}سم / ${profile.age}سنة', 'AI uses your data: ${profile.weightKg}kg / ${profile.heightCm.toInt()}cm / ${profile.age}yrs', 'AI uses your data: ${profile.weightKg}kg / ${profile.heightCm.toInt()}cm / ${profile.age}yrs', 'AI uses your data: ${profile.weightKg}kg / ${profile.heightCm.toInt()}cm / ${profile.age}yrs', 'AI uses your data: ${profile.weightKg}kg / ${profile.heightCm.toInt()}cm / ${profile.age}yrs', 'AI uses your data: ${profile.weightKg}kg / ${profile.heightCm.toInt()}cm / ${profile.age}yrs'),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white60),
          ),
        ],
      ]),
    );
  }

  Widget _imagePreview() {
    return Container(
      height: 280,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          Image.file(_image!, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image, color: Colors.grey, size: 48)),
          if (_state == BodyAnalysisState.analyzing)
            Container(color: Colors.black54, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedBuilder(animation: _pulse, builder: (_, __) =>
                Opacity(opacity: _pulse.value, child: const Text('🤖', style: TextStyle(fontSize: 42)))),
              const SizedBox(height: 8),
              const CircularProgressIndicator(color: AppColors.barakahGold, strokeWidth: 3),
            ]))),
        ]),
      ),
    );
  }

  Widget _pickBtn(String emoji, String label, Color color, VoidCallback onTap) {
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
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  Widget _loadingCard(bool isAr, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(children: [
        AnimatedBuilder(animation: _pulse, builder: (_, __) =>
          Opacity(opacity: _pulse.value, child: const Text('🧬', style: TextStyle(fontSize: 42)))),
        const SizedBox(height: 10),
        Text(tLang(lang, 'يحلل Claude AI جسمك…', 'Claude AI is analyzing your body…', 'Claude AI is analyzing your body…', 'Claude AI is analyzing your body…', 'Claude AI is analyzing your body…', 'Claude AI is analyzing your body…'),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          tLang(lang, 'يُقدّر نسبة الدهون • نوع الجسم • التوصيات', 'Estimating body fat % • Body type • Recommendations', 'Estimating body fat % • Body type • Recommendations', 'Estimating body fat % • Body type • Recommendations', 'Estimating body fat % • Body type • Recommendations', 'Estimating body fat % • Body type • Recommendations'),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
            color: isDark ? AppColors.darkMuted : AppColors.lightMuted, height: 1.5),
        ),
        const SizedBox(height: 14),
        const LinearProgressIndicator(
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation(AppColors.barakahGold),
        ),
      ]),
    );
  }

  Widget _resultCard(BodyPhotoResult r, bool isAr, bool isDark, Color bg, Color muted, UserProfile? profile) {
    final confPct  = (r.confidence * 100).clamp(0, 100).toInt();
    final recs     = isAr ? r.recommendationsAr : r.recommendations;
    final postureN = isAr ? r.rawAnalysisAr : r.rawAnalysis;
    final btype    = isAr ? r.bodyType : r.bodyType;
    final bfColor  = r.bodyFatPercent < 20 ? AppColors.halalGreen
        : r.bodyFatPercent < 30 ? AppColors.doubtOrange : AppColors.haramRed;

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14)]),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tLang(lang, '🧬 نتائج التحليل', '🧬 Analysis Results', '🧬 Résultats d\'analyse', '🧬 Analiz Sonuçları', '🧬 Keputusan Analisis', '🧬 Hasil Analisis'),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: confPct > 50 ? AppColors.halalGreen.withOpacity(0.1) : AppColors.doubtOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tLang(lang, 'دقة: $confPct%', 'Conf: $confPct%', 'Conf: $confPct%', 'Conf: $confPct%', 'Conf: $confPct%', 'Conf: $confPct%'),
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700,
                  color: confPct > 50 ? AppColors.halalGreen : AppColors.doubtOrange),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Big metrics ──────────────────────────────────
          Row(children: [
            _bigMetric(
              '${r.bodyFatPercent.toStringAsFixed(1)}%',
              tLang(lang, 'نسبة الدهون', 'Body Fat %', '% Graisse corporelle', 'Vücut Yağ %', '% Lemak Badan', '% Lemak Tubuh'),
              bfColor,
            ),
            const SizedBox(width: 12),
            _bigMetric(
              '${r.muscleMassKg.toStringAsFixed(1)} kg',
              tLang(lang, 'كتلة العضلات', 'Muscle Mass', 'Masse musculaire', 'Kas Kitlesi', 'Jisim Otot', 'Massa Otot'),
              AppColors.halalGreen,
            ),
            const SizedBox(width: 12),
            _bigMetric(btype, tLang(lang, 'نوع الجسم', 'Body Type', 'Type de corps', 'Vücut Tipi', 'Jenis Badan', 'Tipe Tubuh'), AppColors.waterBlue, small: true),
          ]),
          const SizedBox(height: 16),

          // ── Body fat scale ───────────────────────────────
          _bfScale(r.bodyFatPercent, profile?.isMale ?? true, isAr, muted),
          const SizedBox(height: 16),

          // ── Posture note ─────────────────────────────────
          if (postureN.isNotEmpty) ...[
            Text(tLang(lang, '🦴 ملاحظات الوضعية:', '🦴 Posture Notes:', '🦴 Notes de posture :', '🦴 Duruş Notları:', '🦴 Nota Postur:', '🦴 Catatan Postur:'),
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.waterBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(postureN,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted, height: 1.5)),
            ),
            const SizedBox(height: 14),
          ],

          // ── Recommendations ───────────────────────────────
          if (recs.isNotEmpty) ...[
            Text(tLang(lang, '💡 توصيات مخصصة لك:', '💡 Personalized Recommendations:', '💡 Recommandations personnalisées :', '💡 Kişisel Tavsiyeler:', '💡 Cadangan Diperibadikan:', '💡 Rekomendasi Personal:'),
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            ...recs.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(color: AppColors.barakahGold.withOpacity(0.15), shape: BoxShape.circle),
                  child: Center(child: Text('${e.key + 1}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.barakahGold))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(e.value,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted, height: 1.5))),
              ]),
            )),
            const SizedBox(height: 14),
          ],

          // ── Compare with BMI-based ────────────────────────
          if (profile != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sunnahGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Text(tLang(lang, '📊 مقارنة مع حسابات ملفك', '📊 Comparison with Profile Calculations', '📊 Comparaison avec calculs du profil', '📊 Profil Hesaplamalarıyla Karşılaştırma', '📊 Perbandingan dengan Pengiraan Profil', '📊 Perbandingan dengan Perhitungan Profil'),
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.sunnahGreen)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _compareRow(tLang(lang, 'صورة', 'Photo', 'Photo', 'Fotoğraf', 'Foto', 'Foto'), '${r.bodyFatPercent.toStringAsFixed(1)}%', AppColors.barakahGold),
                  const Text('vs', style: TextStyle(fontFamily: 'Cairo', color: AppColors.lightMuted, fontSize: 12)),
                  _compareRow(tLang(lang, 'حساب', 'Calc.', 'Calc.', 'Hesapla.', 'Kira.', 'Hitung.'), '${profile.bodyFatPercent.toStringAsFixed(1)}%', AppColors.sunnahGreen),
                ]),
              ]),
            ),
          ],

          const SizedBox(height: 14),

          // ── Disclaimer ────────────────────────────────────
          Text(
            tLang(lang, '⚠️ تنبيه: هذه النتائج تقديرية بدقة ٦٠-٧٥٪. لا تستخدمها كبديل للقياسات الطبية أو الاستشارة المتخصصة.', '⚠️ Disclaimer: These results are estimates with 60-75% accuracy. Do not use as a substitute for medical measurements or professional consultation.', '⚠️ Disclaimer: These results are estimates with 60-75% accuracy. Do not use as a substitute for medical measurements or professional consultation.', '⚠️ Disclaimer: These results are estimates with 60-75% accuracy. Do not use as a substitute for medical measurements or professional consultation.', '⚠️ Disclaimer: These results are estimates with 60-75% accuracy. Do not use as a substitute for medical measurements or professional consultation.', '⚠️ Disclaimer: These results are estimates with 60-75% accuracy. Do not use as a substitute for medical measurements or professional consultation.'),
            style: TextStyle(fontFamily: 'Cairo', fontSize: 9.5, color: muted, height: 1.6),
          ),

          const SizedBox(height: 14),

          // ── Retry button ──────────────────────────────────
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () => setState(() { _image = null; _result = null; _state = BodyAnalysisState.idle; }),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(tLang(lang, 'تحليل صورة جديدة', 'Analyze New Photo', 'Analyser une nouvelle photo', 'Yeni Fotoğraf Analiz Et', 'Analisis Foto Baru', 'Analisis Foto Baru'),
                style: const TextStyle(fontFamily: 'Cairo')),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.barakahGold, side: const BorderSide(color: AppColors.barakahGold)),
          )),
        ]),
      ),
    );
  }

  Widget _bigMetric(String value, String label, Color color, {bool small = false}) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Text(value, textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontSize: small ? 14 : 18, fontWeight: FontWeight.w900, color: color, height: 1.1)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.lightMuted)),
      ]),
    ));
  }

  Widget _bfScale(double bf, bool isMale, bool isAr, Color muted) {
    // Male ranges: essential<6, athletic<14, fitness<18, average<25, obese>25
    // Female ranges: essential<14, athletic<21, fitness<25, average<32, obese>32
    final max   = isMale ? 40.0 : 50.0;
    final pct   = (bf / max).clamp(0.0, 1.0);
    final bfCol = bf < (isMale ? 14 : 21) ? AppColors.halalGreen
        : bf < (isMale ? 25 : 32) ? AppColors.doubtOrange
        : AppColors.haramRed;
    final catAr = isMale
      ? (bf < 6 ? 'أساسي' : bf < 14 ? 'رياضي' : bf < 18 ? 'لياقة' : bf < 25 ? 'متوسط' : 'مرتفع')
      : (bf < 14 ? 'أساسي' : bf < 21 ? 'رياضية' : bf < 25 ? 'لياقة' : bf < 32 ? 'متوسط' : 'مرتفع');
    final catEn = isMale
      ? (bf < 6 ? 'Essential' : bf < 14 ? 'Athletic' : bf < 18 ? 'Fitness' : bf < 25 ? 'Average' : 'Obese')
      : (bf < 14 ? 'Essential' : bf < 21 ? 'Athletic' : bf < 25 ? 'Fitness' : bf < 32 ? 'Average' : 'Obese');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(tLang(lang, 'مقياس الدهون:', 'Fat Scale:', 'Échelle de graisse :', 'Yağ Ölçeği:', 'Skala Lemak:', 'Skala Lemak:'),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
        Text(isAr ? catAr : catEn,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: bfCol)),
      ]),
      const SizedBox(height: 6),
      Stack(children: [
        Container(height: 12, decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            colors: [AppColors.halalGreen, AppColors.doubtOrange, AppColors.haramRed],
            stops: [0.0, 0.5, 1.0],
          ),
        )),
        LayoutBuilder(builder: (_, constraints) => Positioned(
          left: pct * (constraints.maxWidth - 4).clamp(0.0, constraints.maxWidth - 4),
          child: Container(width: 4, height: 18, margin: const EdgeInsets.only(top: -3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4)])),
        )),
      ]),
    ]);
  }

  Widget _compareRow(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.lightMuted)),
    ]);
  }
}
