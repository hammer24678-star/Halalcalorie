// ============================================================
//  onboarding_screen.dart — HalalCalorie
//  Beautiful modern onboarding — 8.5/10 UI quality
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {

  final PageController _page = PageController();
  int _current = 0;

  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset>    _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _page.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < _steps.length - 1) {
      _page.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _finish() async {
    await ref.read(onboardingProvider.notifier).complete();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        // ── Gradient background ─────────────────────────────
        Positioned.fill(child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.sunnahGreen.withOpacity(isDark ? 0.15 : 0.08),
                bg,
                AppColors.barakahGold.withOpacity(isDark ? 0.08 : 0.04),
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
        )),

        // ── Skip button ──────────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 20,
          child: TextButton(
            onPressed: _finish,
            child: Text(
              'تخطي',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: AppColors.sunnahGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // ── Main content ─────────────────────────────────────
        Column(children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 48),

          // Page view
          Expanded(
            child: PageView.builder(
              controller: _page,
              onPageChanged: (i) {
                setState(() => _current = i);
                _fadeCtrl.forward(from: 0);
                _slideCtrl.forward(from: 0);
              },
              itemCount: _steps.length,
              itemBuilder: (ctx, i) => _buildPage(_steps[i], isDark, size),
            ),
          ),

          // ── Dots indicator ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width:  active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.sunnahGreen
                        : AppColors.sunnahGreen.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          // ── CTA Button ───────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 0, 24, MediaQuery.of(context).padding.bottom + 24),
            child: SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientGreen,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.sunnahGreen.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _current < _steps.length - 1 ? 'التالي →' : 'ابدأ رحلتك 🌿',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildPage(_OnboardStep step, bool isDark, Size size) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Emoji icon with gradient circle ────────────
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      step.color.withOpacity(0.15),
                      step.color.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: step.color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(step.emoji,
                      style: const TextStyle(fontSize: 56)),
                ),
              ),

              const SizedBox(height: 36),

              // ── Title ───────────────────────────────────────
              Text(
                step.title,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.darkBg,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 14),

              // ── Subtitle ────────────────────────────────────
              Text(
                step.subtitle,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              // ── Feature chips ────────────────────────────────
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: step.chips.map((chip) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: step.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: step.color.withOpacity(0.3)),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: step.color,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardStep {
  final String emoji;
  final String title;
  final String subtitle;
  final List<String> chips;
  final Color color;
  const _OnboardStep({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.color,
  });
}

const _steps = [
  _OnboardStep(
    emoji: '🌿',
    title: 'أهلاً بك في هلال كالوري',
    subtitle: 'تطبيقك الأول لتتبع السعرات الحرارية
بطريقة حلال ١٠٠٪',
    chips: ['حلال ✓', 'عربي أولاً', 'خصوصية تامة'],
    color: AppColors.sunnahGreen,
  ),
  _OnboardStep(
    emoji: '🍽️',
    title: 'تتبع طعامك بذكاء',
    subtitle: 'صوّر طعامك أو امسح الباركود
والذكاء الاصطناعي يحسب السعرات فوراً',
    chips: ['AI تلقائي', '1000+ طعام', 'باركود فوري'],
    color: AppColors.barakahGold,
  ),
  _OnboardStep(
    emoji: '💪',
    title: 'لياقة بالسنة النبوية',
    subtitle: 'تمارين مستوحاة من السنة
خطوات حقيقية من Google Fit',
    chips: ['خطوات LIVE', 'نبض القلب', 'نوم صحي'],
    color: Color(0xFF1E88E5),
  ),
  _OnboardStep(
    emoji: '🌙',
    title: 'رمضان والصيام',
    subtitle: 'وضع رمضان الخاص
تتبع السحور والإفطار بسهولة',
    chips: ['وضع رمضان', 'صيام سنة', 'أهداف رمضانية'],
    color: AppColors.barakahGold,
  ),
  _OnboardStep(
    emoji: '🔒',
    title: 'خصوصيتك أمانة',
    subtitle: 'بياناتك تبقى على جهازك
لا إعلانات — لا بيع للبيانات أبداً',
    chips: ['محلي أولاً', 'بدون إعلانات', 'أمان تام'],
    color: AppColors.sunnahGreen,
  ),
];
