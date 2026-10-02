// ============================================================
//  paywall_screen.dart — HalalCalorie v44 premium redesign
//  Purchase / restore logic is unchanged from v43; this file only
//  replaces the presentation: aurora hero, staggered benefits,
//  animated plan cards and a pinned call-to-action.
// ============================================================
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';
import '../../core/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/motion.dart';
import '../../core/fx.dart';
import '../../core/providers.dart';
import '../../core/regional_pricing.dart';
import '../../core/revenuecat_service.dart';

const _gold = Color(0xFFDBA75D);
const _goldLight = Color(0xFFF0CF98);

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallState();
}

class _PaywallState extends ConsumerState<PaywallScreen> {
  int _selected = 1;
  bool _loading = false;
  bool _restoring = false;
  String? _errorMsg;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  bool get _isAr => ref.read(languageProvider) == 'ar';

  Future<void> _purchase(List<RCOffering> offerings) async {
    if (_loading || offerings.isEmpty) return;
    if (mounted) setState(() { _loading = true; _errorMsg = null; });
    final offering = offerings[_selected.clamp(0, offerings.length - 1)];
    final result = await RevenueCatService.purchase(offering);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      await ref.read(premiumProvider.notifier).onPurchaseSuccess();
      _showSuccess();
    } else if (!result.cancelled) {
      if (mounted) {
        setState(() => _errorMsg =
            result.error ?? 'Purchase failed. Please try again.');
      }
    }
  }

  Future<void> _restore() async {
    if (mounted) setState(() { _restoring = true; _errorMsg = null; });
    final result = await RevenueCatService.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (result.success) {
      await ref.read(premiumProvider.notifier).onPurchaseSuccess();
      _showSuccess();
    } else {
      if (mounted) {
        setState(() =>
            _errorMsg = 'No previous purchases found for this account.');
      }
    }
  }

  void _showSuccess() {
    final isAr = _isAr;
    HapticFeedback.heavyImpact();
    _confetti.play();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Stack(
        alignment: Alignment.topCenter,
        children: [
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.3,
            colors: const [
              AppColors.brandGreen, AppColors.accentGold,
              AppColors.halalGreen, Colors.white,
              Color(0xFF4CAF50), Color(0xFFFFD700),
            ],
          ),
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28)),
            backgroundColor: const Color(0xFF0F1E18),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [_goldLight, _gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                          color: _gold.withOpacity(0.5), blurRadius: 30),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      size: 56, color: Color(0xFF1A0F00)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isAr ? 'تهانينا! أصبحت عضواً بريميوم'
                     : 'Welcome to Premium',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 20,
                    fontWeight: FontWeight.w900, color: _goldLight),
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'تم فتح جميع الميزات المميزة — شكراً لدعمك'
                    : 'Every premium feature is unlocked — thank you for your support',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 13,
                    color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 22),
              ShineButton(
                label: isAr ? 'لنبدأ' : "Let's go",
                height: 52,
                onPressed: () {
                  _confetti.stop();
                  Navigator.of(dialogCtx).pop();
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar' || lang == 'ur';
    final offerings = ref.watch(rcOfferingsProvider);
    String t(String ar, String en) => isAr ? ar : en;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF050E0A),
        body: Stack(children: [
          const Positioned.fill(
            child: AuroraBackground(
              base: Color(0xFF050E0A),
              colors: [Color(0xFF1E9E52), _gold, Color(0xFF0E6B6B)],
              intensity: 0.9,
            ),
          ),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _restoring ? null : _restore,
                    child: _restoring
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white54))
                        : Text(t('استعادة', 'Restore'),
                            style: const TextStyle(
                                fontFamily: 'Aligarh', fontSize: 13,
                                color: Colors.white60)),
                  ),
                ]),
              ),
              Expanded(
                child: offerings.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: _gold, strokeWidth: 3),
                  ),
                  error: (_, __) => _page(const [], lang, isAr, t),
                  data: (list) => _page(list, lang, isAr, t),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _page(List<RCOffering> offerings, String lang, bool isAr,
      String Function(String, String) t) {
    final feats = _features(isAr);
    return Column(children: [
      Expanded(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          children: [
            Reveal(index: 0, child: _hero(t)),
            const SizedBox(height: 26),
            for (var i = 0; i < feats.length; i++)
              Reveal(index: 2 + i, child: _featureRow(feats[i])),
            const SizedBox(height: 22),
            Reveal(
              index: 2 + feats.length,
              child: Text(
                t('اختر خطتك', 'Choose your plan'),
                style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 16,
                    fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            Reveal(
              index: 3 + feats.length,
              child: _plansList(offerings, isAr, lang),
            ),
          ],
        ),
      ),
      // Pinned: the price and the button never scroll out of reach.
      Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF050E0A).withOpacity(0),
              const Color(0xFF050E0A),
            ],
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSize(
            duration: Motion.quick,
            curve: Motion.curve,
            child: _errorMsg == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.haramRed.withOpacity(0.10),
                      border: Border.all(
                          color: AppColors.haramRed.withOpacity(0.35)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(_errorMsg!,
                        style: const TextStyle(
                            fontFamily: 'Aligarh', fontSize: 12,
                            color: AppColors.haramRed)),
                  ),
          ),
          PulseGlow(
            color: _gold,
            minOpacity: 0.10,
            maxOpacity: 0.34,
            blur: 26,
            borderRadius: BorderRadius.circular(22),
            child: ShineButton(
              label: t('ابدأ بريميوم', 'Unlock Premium'),
              icon: Icons.workspace_premium_rounded,
              loading: _loading,
              onPressed: () => _purchase(offerings),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _badge(Icons.verified_rounded, t('١٠٠٪ حلال', '100% Halal')),
            const SizedBox(width: 18),
            _badge(Icons.lock_rounded, t('خصوصية', 'Private')),
            const SizedBox(width: 18),
            _badge(Icons.block_rounded, t('بلا ربا', 'No Riba')),
          ]),
          const SizedBox(height: 6),
          Text(
            t('مدفوعات آمنة • يمكن الإلغاء في أي وقت • لا رسوم خفية',
              'Secure payment • Cancel anytime • No hidden fees'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Aligarh', fontSize: 10.5,
                color: Colors.white38),
          ),
        ]),
      ),
    ]);
  }

  Widget _hero(String Function(String, String) t) {
    return Column(children: [
      const SizedBox(height: 4),
      PulseGlow(
        color: _gold,
        minOpacity: 0.16,
        maxOpacity: 0.46,
        blur: 40,
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.02),
            ]),
            border: Border.all(color: _gold.withOpacity(0.5), width: 1),
          ),
          child: const Center(child: BrandMark(size: 70)),
        ),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withOpacity(0.55), width: 0.8),
          color: _gold.withOpacity(0.12),
        ),
        child: Text('PREMIUM',
            style: TextStyle(
                fontFamily: 'Aligarh', fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 2.4,
                color: _goldLight.withOpacity(0.95))),
      ),
      const SizedBox(height: 12),
      Text(t('كل ما تحتاجه لصحتك، حلالاً',
             'Everything for your health, halal'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Bravoon', fontSize: 26, height: 1.2,
              fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 8),
      Text(t('حلال في كل لقمة • خطوة كل يوم',
             'Halal in every bite • a step every day'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Aligarh', fontSize: 13,
              color: Colors.white60)),
    ]);
  }

  List<_Feat> _features(bool isAr) => isAr
      ? const [
          _Feat(Icons.monitor_weight_rounded,
              'نسبة الدهون الدقيقة ٪ + كتلة العضلات + LBM'),
          _Feat(Icons.photo_camera_rounded,
              'تحليل الجسم والطعام بالصورة — AI بلا حدود'),
          _Feat(Icons.qr_code_scanner_rounded,
              'ماسحات حلال غير محدودة (مقابل ٣ مجانية/يوم)'),
          _Feat(Icons.fitness_center_rounded,
              '١٨٠ خطة تمرين + رمضان + ما بعد الولادة'),
          _Feat(Icons.restaurant_menu_rounded,
              'مخطط وجبات AI مخصص لجسمك'),
          _Feat(Icons.biotech_rounded, 'تحليل تركيبة الجسم الكامل'),
          _Feat(Icons.cloud_off_rounded, 'يعمل بدون إنترنت + تاريخ كامل'),
        ]
      : const [
          _Feat(Icons.monitor_weight_rounded,
              'Exact body fat % + muscle mass + lean body mass'),
          _Feat(Icons.photo_camera_rounded,
              'Unlimited AI food & body photo analysis (vs 3 free/day)'),
          _Feat(Icons.qr_code_scanner_rounded,
              'Unlimited halal scans (vs 3 free/day)'),
          _Feat(Icons.fitness_center_rounded,
              '180 workouts + Ramadan + postnatal plans'),
          _Feat(Icons.restaurant_menu_rounded,
              'AI meal planner personalised to your body'),
          _Feat(Icons.biotech_rounded, 'Full body composition analysis'),
          _Feat(Icons.terrain_rounded,
              'Ascent progression, quests + weekly review'),
        ];

  Widget _featureRow(_Feat f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _gold.withOpacity(0.28),
                  _gold.withOpacity(0.08),
                ],
              ),
              border: Border.all(color: _gold.withOpacity(0.35), width: 0.6),
            ),
            child: Icon(f.icon, size: 21, color: _goldLight),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(f.text,
                style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 13.5, height: 1.35,
                    color: Colors.white)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.check_circle_rounded,
              color: AppColors.halalGreen, size: 19),
        ]),
      );

  Widget _plansList(List<RCOffering> offerings, bool isAr, String lang) {
    final fallback = _fallback(isAr, lang);
    final count = offerings.isNotEmpty ? offerings.length : fallback.length;
    return Column(children: [
      for (var idx = 0; idx < count; idx++)
        Builder(builder: (_) {
          final rc = offerings.isNotEmpty ? offerings[idx] : null;
          final fp = rc == null ? fallback[idx] : null;
          final title = rc != null ? (isAr ? rc.titleAr : rc.titleEn) : fp!.title;
          final price = rc?.priceString ?? fp!.price;
          final per = rc != null ? (isAr ? rc.periodAr : rc.periodEn) : fp!.per;
          final pop = rc?.isPopular ?? fp!.popular;
          final save = rc != null
              ? (isAr ? rc.savingsBadgeAr : rc.savingsBadgeEn)
              : fp!.save;
          return _planCard(
            idx: idx,
            title: title,
            price: price,
            per: per,
            popular: pop,
            save: save,
            lang: lang,
          );
        }),
    ]);
  }

  Widget _planCard({
    required int idx,
    required String title,
    required String price,
    required String per,
    required bool popular,
    required String? save,
    required String lang,
  }) {
    final sel = _selected == idx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressFx(
        scale: 0.985,
        onTap: () => setState(() { _selected = idx; _errorMsg = null; }),
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: Motion.base,
            curve: Motion.curve,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: sel
                    ? [_gold.withOpacity(0.22), _gold.withOpacity(0.06)]
                    : [Colors.white.withOpacity(0.06),
                       Colors.white.withOpacity(0.02)],
              ),
              border: Border.all(
                color: sel ? _gold : Colors.white.withOpacity(0.12),
                width: sel ? 1.8 : 0.8,
              ),
              boxShadow: sel
                  ? [BoxShadow(color: _gold.withOpacity(0.25), blurRadius: 22)]
                  : const [],
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: Motion.quick,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? _gold : Colors.transparent,
                  border: Border.all(
                      color: sel ? _gold : Colors.white38, width: 1.5),
                ),
                child: AnimatedScale(
                  duration: Motion.quick,
                  curve: Curves.easeOutBack,
                  scale: sel ? 1 : 0,
                  child: const Icon(Icons.check_rounded,
                      size: 16, color: Color(0xFF1A0F00)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontFamily: 'Aligarh', fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: sel ? _goldLight : Colors.white)),
                  if (save != null && save.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(save,
                          style: const TextStyle(
                              fontFamily: 'Aligarh', fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentBright)),
                    ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(price,
                    style: const TextStyle(
                        fontFamily: 'Aligarh', fontSize: 17,
                        fontWeight: FontWeight.w900, color: Colors.white)),
                Text(per,
                    style: const TextStyle(
                        fontFamily: 'Aligarh', fontSize: 11,
                        color: Colors.white54)),
              ]),
            ]),
          ),
          if (popular)
            PositionedDirectional(
              top: -10,
              end: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                      colors: [_goldLight, _gold]),
                ),
                child: Text(
                  tLang(lang, 'الأكثر شعبية', 'Most Popular',
                      'Le plus populaire', 'En Popüler',
                      'Paling Popular', 'Paling Populer'),
                  style: const TextStyle(
                      fontFamily: 'Aligarh', fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A0F00)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  List<_FP> _fallback(bool isAr, String lang) => [
        _FP(
          tLang(lang, 'شهري', 'Monthly', 'Mensuel', 'Aylık', 'Bulanan', 'Bulanan'),
          tLang(lang, '٢.٩٩ \$', '\$2.99', '\$2.99', '\$2.99', '\$2.99', '\$2.99'),
          tLang(lang, '/ شهر', '/ month', '/ mois', '/ ay', '/ bulan', '/ bulan'),
          false, null),
        _FP(
          tLang(lang, 'سنوي', 'Yearly', 'Annuel', 'Yıllık', 'Tahunan', 'Tahunan'),
          tLang(lang, '١٩.٩٩ \$', '\$19.99', '\$19.99', '\$19.99', '\$19.99', '\$19.99'),
          tLang(lang, '/ سنة', '/ year', '/ an', '/ yıl', '/ tahun', '/ tahun'),
          true,
          tLang(lang, 'وفّر ٤٤٪', 'Save 44%', 'Save 44%', 'Save 44%', 'Save 44%', 'Save 44%')),
      ];

  Widget _badge(IconData icon, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.accentBright),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Aligarh', fontSize: 11.5,
                color: Colors.white60)),
      ]);
}

class _Feat {
  final IconData icon;
  final String text;
  const _Feat(this.icon, this.text);
}

class _FP {
  final String title, price, per;
  final bool popular;
  final String? save;
  const _FP(this.title, this.price, this.per, this.popular, this.save);
}
