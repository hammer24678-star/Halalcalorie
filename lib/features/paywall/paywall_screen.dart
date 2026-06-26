// ============================================================
//  paywall_screen.dart — HalalCalorie v1.0
//  Full RevenueCat paywall with real Apple Pay / Google Pay
// ============================================================
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../core/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/regional_pricing.dart';
import '../../core/revenuecat_service.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override ConsumerState<PaywallScreen> createState() => _PaywallState();
}

class _PaywallState extends ConsumerState<PaywallScreen>
    with SingleTickerProviderStateMixin {
  String get lang => ref.watch(languageProvider);
  int     _selected  = 1;
  bool    _loading   = false;
  bool    _restoring = false;
  String? _errorMsg;
  late AnimationController _pulse;
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
  }
  @override void dispose() { _pulse.dispose(); _confetti.dispose(); super.dispose(); }

  bool get _isAr => ref.read(languageProvider) == 'ar';

  Future<void> _purchase(List<RCOffering> offerings) async {
    if (_loading || offerings.isEmpty) return;
    if (mounted) setState(() { _loading = true; _errorMsg = null; });
    final offering = offerings[_selected.clamp(0, offerings.length - 1)];
    final result   = await RevenueCatService.purchase(offering);
    if (!mounted) return;
    if (mounted) setState(() => _loading = false);
    if (result.success) {
      await ref.read(premiumProvider.notifier).onPurchaseSuccess();
      _showSuccess();
    } else if (!result.cancelled) {
      if (mounted) setState(() => _errorMsg = result.error ?? 'Purchase failed. Please try again.');
    }
  }

  Future<void> _restore() async {
    if (mounted) setState(() { _restoring = true; _errorMsg = null; });
    final result = await RevenueCatService.restore();
    if (!mounted) return;
    if (mounted) setState(() => _restoring = false);
    if (result.success) {
      await ref.read(premiumProvider.notifier).onPurchaseSuccess();
      _showSuccess();
    } else {
      if (mounted) setState(() => _errorMsg = 'No previous purchases found for this account.');
    }
  }

  void _showSuccess() {
    final isAr = _isAr;
    _confetti.play();
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => Stack(
        alignment: Alignment.topCenter,
        children: [
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.3,
            colors: const [
              AppColors.sunnahGreen, AppColors.barakahGold,
              AppColors.halalGreen, Colors.white,
              Color(0xFF4CAF50), Color(0xFFFFD700),
            ],
          ),
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: const Color(0xFF1A2A1A),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: const Text('🏆', style: TextStyle(fontSize: 72)),
              ),
              const SizedBox(height: 12),
              Text(isAr ? 'تهانيّ! أصبحت عضواً بريميوم 🌟' : 'Congratulations! You are Premium 🌟',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 18,
                  fontWeight: FontWeight.w900, color: AppColors.barakahGold)),
              const SizedBox(height: 8),
              Text(isAr
                ? 'تم فتح جميع الميزات المميزة! بارك الله فيك 🌙'
                : 'All premium features unlocked! May Allah bless you 🌙',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                  color: Colors.white70, height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () {
                  _confetti.stop();
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.barakahGold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(isAr ? '🌟 رائع! لنبدأ' : '🌟 Let\'s go!',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 16,
                    color: Colors.white, fontWeight: FontWeight.w800)),
              )),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang      = ref.watch(languageProvider);
    final isAr      = lang == 'ar' || lang == 'ur';
    final isDark    = ref.watch(themeProvider);
    final offerings = ref.watch(rcOfferingsProvider);
    final bg        = isDark ? AppColors.darkCard : Colors.white;
    String t(String ar, String en) => isAr ? ar : en;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: isDark ? AppColors.darkText : AppColors.lightText),
            onPressed: () { if (context.mounted) Navigator.pop(context); },
          ),
          actions: [
            TextButton(
              onPressed: _restoring ? null : _restore,
              child: _restoring
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lightMuted))
                : Text(t('استعادة', 'Restore'), style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.lightMuted)),
            ),
          ],
        ),
        body: offerings.when(
          loading: () => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const CircularProgressIndicator(color: AppColors.sunnahGreen, strokeWidth: 3),
            const SizedBox(height: 12),
            Text(t('جاري تحميل العروض...', 'Loading offers...'), style: const TextStyle(fontFamily: 'Cairo', color: AppColors.lightMuted)),
          ])),
          error: (_, __) => _buildContent([], isAr, isDark, bg, t),
          data:  (list) => _buildContent(list, isAr, isDark, bg, t),
        ),
      ),
    );
  }

  Widget _buildContent(List<RCOffering> offerings, bool isAr, bool isDark, Color bg, String Function(String,String) t) {
    return ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 32), children: [
      // Hero
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.sunnahGreen, AppColors.darkGreen]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: AppColors.sunnahGreen.withOpacity(0.3), blurRadius: 20, offset: const Offset(0,8))],
        ),
        child: Column(children: [
          const Text('🌟', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 10),
          Text(t('HalalCalorie بريميوم', 'HalalCalorie Premium'),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 6),
          Text(t('حلال في كل لقمة • سنة في كل خطوة', 'Halal in every bite • Sunnah in every step'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70)),
        ]),
      ),
      const SizedBox(height: 22),
      // Features
      Text(t('ما ستحصل عليه:', 'What you get:'),
        style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkText : AppColors.lightText)),
      const SizedBox(height: 12),
      ...(isAr ? [
        ['💪', 'نسبة الدهون الدقيقة ٪ + كتلة العضلات + LBM'],
        ['📸', 'تحليل الجسم والطعام بالصورة — AI بلا حدود'],
        ['📷', 'ماسحات حلال غير محدودة (مقابل ٣ مجانية/يوم)'],
        ['🏃', '١٨٠ خطة تمرين + رمضان + ما بعد الولادة'],
        ['🌿', 'مخطط وجبات AI مخصص لجسمك'],
        ['🧬', 'تحليل تركيبة الجسم الكامل'],
        ['📥', 'يعمل بدون إنترنت + تاريخ كامل'],
      ] : [
        ['💪', 'Exact body fat % + Muscle mass + Lean Body Mass'],
        ['📸', 'Unlimited AI food & body photo analysis (vs 3 free/day)'],
        ['📷', 'Unlimited halal scans (vs 3 free/day)'],
        ['🏃', '180 workouts + Ramadan + Postnatal plans'],
        ['🌿', 'AI meal planner personalized to your body'],
        ['🧬', 'Full body composition analysis'],
        ['✨', 'Barakah advanced insights + weekly reports'],
      ]).map((f) => Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.sunnahGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(f[0], style: const TextStyle(fontSize: 18)))),
          const SizedBox(width: 12),
          Expanded(child: Text(f[1], style: TextStyle(fontFamily: 'Cairo', fontSize: 13,
            color: isDark ? AppColors.darkText : AppColors.lightText))),
          const Icon(Icons.check_circle, color: AppColors.halalGreen, size: 18),
        ]))),
      const SizedBox(height: 22),
      // Plans
      Text(t('اختر خطتك:', 'Choose your plan:'),
        style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkText : AppColors.lightText)),
      const SizedBox(height: 12),
      _plansList(offerings, isAr, isDark, bg),
      const SizedBox(height: 18),
      if (_errorMsg != null) Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.haramRed.withOpacity(0.08),
          border: Border.all(color: AppColors.haramRed.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10)),
        child: Text(_errorMsg!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.haramRed))),
      // CTA
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _loading ? null : () => _purchase(offerings),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.barakahGold,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 4, shadowColor: AppColors.barakahGold.withOpacity(0.4),
        ),
        child: _loading
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
              const SizedBox(width: 12),
              Text(tLang(lang, 'جاري المعالجة...', 'Processing...', 'Traitement...', 'İşleniyor...', 'Memproses...', 'Memproses...'), style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Colors.white)),
            ])
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('⭐', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(t('اشترك الآن', 'Subscribe Now'),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
      )),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _badge('✅', t('١٠٠٪ حلال', '100% Halal')),
        const SizedBox(width: 16),
        _badge('🔒', t('خصوصية', 'Private')),
        const SizedBox(width: 16),
        _badge('🚫', t('بلا ربا', 'No Riba')),
      ]),
      const SizedBox(height: 8),
      Text(t('Apple Pay وGoogle Pay متاحان تلقائياً عند الاشتراك', 'Apple Pay & Google Pay available automatically at checkout'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.sunnahGreen, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(t('مدفوعات آمنة • يمكن الإلغاء في أي وقت • لا رسوم خفية',
              'Secure payment • Cancel anytime • No hidden fees'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.lightMuted)),
    ]);
  }

  Widget _plansList(List<RCOffering> offerings, bool isAr, bool isDark, Color bg) {
    // Use RC offerings if available, otherwise fallback
    final plans = offerings.isNotEmpty ? offerings : _fallback(isAr, lang);
    return Column(
      children: plans.asMap().entries.map((e) {
        final idx   = e.key;
        final isSel = _selected == idx;
        final rcOff = offerings.isNotEmpty ? offerings[idx] : null;
        final title = rcOff != null ? (isAr ? rcOff.titleAr : rcOff.titleEn) : (e.value as _FP).title;
        final price = rcOff?.priceString ?? (e.value as _FP).price;
        final per   = rcOff != null ? (isAr ? rcOff.periodAr : rcOff.periodEn) : (e.value as _FP).per;
        final pop   = rcOff?.isPopular ?? (e.value as _FP).popular;
        final save  = rcOff != null ? (isAr ? rcOff.savingsBadgeAr : rcOff.savingsBadgeEn) : (e.value as _FP).save;
        return GestureDetector(
          onTap: () => setState(() { _selected = idx; _errorMsg = null; }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isSel ? AppColors.sunnahGreen.withOpacity(0.08) : bg,
              border: Border.all(color: isSel ? AppColors.sunnahGreen : Colors.grey.withOpacity(0.25), width: isSel ? 2.5 : 0.8),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSel ? [BoxShadow(color: AppColors.sunnahGreen.withOpacity(0.12), blurRadius: 12)] : null,
            ),
            child: Row(children: [
              AnimatedContainer(duration: const Duration(milliseconds: 200), width: 22, height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: isSel ? AppColors.sunnahGreen : Colors.transparent,
                  border: Border.all(color: isSel ? AppColors.sunnahGreen : Colors.grey.shade400)),
                child: isSel ? const Icon(Icons.check, size: 14, color: Colors.white) : null),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15, color: isSel ? AppColors.sunnahGreen : null)),
                  if (pop) ...[
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.barakahGold, borderRadius: BorderRadius.circular(20)),
                      child: Text(tLang(lang, 'الأكثر شعبية', 'Most Popular', 'Le plus populaire', 'En Popüler', 'Paling Popular', 'Paling Populer'),
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))),
                  ],
                ]),
                if (save != null && save.isNotEmpty)
                  Text(save, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.halalGreen, fontWeight: FontWeight.w600)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(price, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 15)),
                Text(per, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.lightMuted)),
              ]),
            ]),
          ),
        );
      }).toList(),
    );
  }

  List<_FP> _fallback(bool isAr, String lang) => [
    _FP(tLang(lang, 'شهري', 'Monthly', 'Mensuel', 'Aylık', 'Bulanan', 'Bulanan'),        tLang(lang, '٢.٩٩ \$', '\$2.99', '\$2.99', '\$2.99', '\$2.99', '\$2.99'),  tLang(lang, '/ شهر', '/ month', '/ mois', '/ ay', '/ bulan', '/ bulan'),   false, null),
    _FP(tLang(lang, 'سنوي', 'Yearly', 'Annuel', 'Yıllık', 'Tahunan', 'Tahunan'),         tLang(lang, '١٩.٩٩ \$', '\$19.99', '\$19.99', '\$19.99', '\$19.99', '\$19.99'), tLang(lang, '/ سنة', '/ year', '/ an', '/ yıl', '/ tahun', '/ tahun'),    true,  tLang(lang, 'وفّر ٤٤٪', 'Save 44%', 'Save 44%', 'Save 44%', 'Save 44%', 'Save 44%')),
  ];

  Widget _badge(String emoji, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(emoji, style: const TextStyle(fontSize: 14)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.lightMuted)),
  ]);
}

class _FP {
  final String title, price, per;
  final bool   popular;
  final String? save;
  const _FP(this.title, this.price, this.per, this.popular, this.save);
}
