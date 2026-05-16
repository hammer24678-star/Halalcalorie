// ============================================================
//  onboarding_screen.dart — HalalCalorie v3.0
//  Welcome slides + Profile setup questions
//  Animations: particle bg, spring transitions, counter anim
// ============================================================
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../data/models/user_profile.dart';

// ─── TOTAL PAGES: 3 welcome + 6 questions = 9 ──────────────
const int _kWelcomePages = 4; // lang(1) + 3 welcome before questions
const int _kTotalPages   = 11; // 4 welcome + 6 questions + 1 summary

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override ConsumerState<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {

  final _pageCtrl = PageController();
  int _page = 0;

  // ── Page transition animations ──────────────────────────
  late AnimationController _enterCtrl;
  late Animation<double>   _enterFade;
  late Animation<Offset>   _enterSlide;

  // ── Background orb animation ────────────────────────────
  late AnimationController _orbCtrl;

  // ── Profile answers ─────────────────────────────────────
  String _gender      = 'brothers';
  int    _age         = 25;
  double _height      = 170;
  double _weight      = 70;
  int    _goalIdx     = 0;   // FitnessGoal index
  int    _activityIdx = 1;   // ActivityLevel index

  // Number input controllers
  final _ageCtrl    = TextEditingController(text: '25');
  final _heightCtrl = TextEditingController(text: '170');
  final _weightCtrl = TextEditingController(text: '70');

  bool get _isQuestion => _page >= _kWelcomePages;
  int  get _questionIdx => _page - _kWelcomePages;
  bool get _isLast      => _page == _kTotalPages - 1;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550));
    _enterFade  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterSlide = Tween<Offset>(
      begin: const Offset(0.06, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    _orbCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);

    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _enterCtrl.dispose();
    _orbCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_isLast) { _finish(); return; }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  void _back() {
    HapticFeedback.lightImpact();
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _finish() async {
    // Save profile from answers
    final goals = FitnessGoal.values;
    final acts  = ActivityLevel.values;
    final profile = UserProfile(
      id: 'user_1',
      gender: _gender,
      age: _age.clamp(10, 100),
      heightCm: _height.clamp(100, 250),
      weightKg: _weight.clamp(20, 300),
      activityLevel: acts[_activityIdx.clamp(0, acts.length - 1)],
      primaryGoal: goals[_goalIdx.clamp(0, goals.length - 1)],
      dietPreference: DietPreference.halalOnly,
      healthConditions: [HealthCondition.none],
      mealsPerDay: 3,
      sleepHours: 7,
      bodyFrame: BodyFrame.medium,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.read(userProfileProvider.notifier).save(profile);
    await ref.read(onboardingDoneProvider.notifier).complete();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final lang   = ref.watch(languageProvider);
    final size   = MediaQuery.of(context).size;
    final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4F8);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [

        // ── Animated orb background ───────────────────────
        AnimatedBuilder(animation: _orbCtrl, builder: (_, __) {
          return CustomPaint(
            size: size,
            painter: _OrbPainter(
              progress: _orbCtrl.value,
              pageProgress: _page / (_kTotalPages - 1),
              isDark: isDark,
            ),
          );
        }),

        // ── Page content ──────────────────────────────────
        SafeArea(
          child: Column(children: [

            // Top bar: back + progress + skip
            _TopBar(
              page: _page,
              total: _kTotalPages,
              isDark: isDark,
              showBack: _page > 0,
              onBack: _back,
              onSkip: _isQuestion ? null : _finish,
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _page = i);
                  _enterCtrl.forward(from: 0);
                },
                itemCount: _kTotalPages,
                itemBuilder: (ctx, i) {
                  return FadeTransition(
                    opacity: _enterFade,
                    child: SlideTransition(
                      position: _enterSlide,
                      child: _buildPage(i, isDark, lang),
                    ),
                  );
                },
              ),
            ),

            // Bottom CTA
            _BottomBar(
              page: _page,
              isLast: _isLast,
              isQuestion: _isQuestion,
              isDark: isDark,
              onNext: _next,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPage(int i, bool isDark, String lang) {
    if (i == 0) return _WelcomePage(step: _welcomeSteps[0], isDark: isDark, lang: lang);
    if (i == 1) return _buildLanguagePage(isDark); // language screen 2
    if (i == 2) return _WelcomePage(step: _welcomeSteps[1], isDark: isDark, lang: lang);
    if (i == 3) return _WelcomePage(step: _welcomeSteps[2], isDark: isDark, lang: lang);
    return _buildQuestion(_questionIdx, isDark, lang);
  }

  Widget _buildQuestion(int q, bool isDark, String lang) {
    final isAr  = lang == 'ar' || lang == 'ur';
    final muted = isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D);
    final text  = isDark ? Colors.white : const Color(0xFF1F2A1F);

    switch (q) {

      // ── Q0: Gender ──────────────────────────────────────
      case 0: return _QuestionShell(
        emoji: '🧑',
        title: 'من أنت؟',
        titleEn: 'Who are you?',
        isDark: isDark,
        child: Row(children: [
          _GenderCard(
            emoji: '🧔', labelAr: 'رجل', labelEn: 'Man',
            selected: _gender == 'brothers',
            color: AppColors.sunnahGreen,
            isDark: isDark,
            onTap: () => setState(() => _gender = 'brothers'),
          ),
          const SizedBox(width: 14),
          _GenderCard(
            emoji: '🧕', labelAr: 'أخت', labelEn: 'Sister',
            selected: _gender == 'sisters',
            color: AppColors.barakahGold,
            isDark: isDark,
            onTap: () => setState(() => _gender = 'sisters'),
          ),
        ]),
      );

      // ── Q1: Goal ────────────────────────────────────────
      case 1: return _QuestionShell(
        emoji: '🎯',
        title: 'ما هدفك؟',
        titleEn: 'What is your goal?',
        isDark: isDark,
        child: Column(children: [
          ...FitnessGoal.values.asMap().entries.map((e) {
            final selected = _goalIdx == e.key;
            final goal = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SelectTile(
                emoji: goal.emoji(),
                title: goal.nameAr(),
                titleEn: goal.nameEn(),
                selected: selected,
                isDark: isDark,
                onTap: () => setState(() => _goalIdx = e.key),
              ),
            );
          }),
        ]),
      );

      // ── Q2: Activity ────────────────────────────────────
      case 2: return _QuestionShell(
        emoji: '⚡',
        title: 'مستوى نشاطك؟',
        titleEn: 'Activity level?',
        isDark: isDark,
        child: Column(children: [
          ...ActivityLevel.values.asMap().entries.map((e) {
            final selected = _activityIdx == e.key;
            final act = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SelectTile(
                emoji: act.emoji(),
                title: act.nameAr(),
                titleEn: act.nameEn(),
                selected: selected,
                isDark: isDark,
                onTap: () => setState(() => _activityIdx = e.key),
              ),
            );
          }),
        ]),
      );

      // ── Q3: Age ─────────────────────────────────────────
      case 3: return _QuestionShell(
        emoji: '🎂',
        title: 'كم عمرك؟',
        titleEn: 'How old are you?',
        isDark: isDark,
        child: _NumberSlider(
          value: _age.toDouble(),
          min: 10, max: 80,
          unit: 'سنة',
          unitEn: 'years',
          isAr: isAr,
          color: AppColors.barakahGold,
          isDark: isDark,
          onChanged: (v) => setState(() => _age = v.round()),
        ),
      );

      // ── Q4: Height ──────────────────────────────────────
      case 4: return _QuestionShell(
        emoji: '📏',
        title: 'كم طولك؟',
        titleEn: 'Your height?',
        isDark: isDark,
        child: _NumberSlider(
          value: _height,
          min: 140, max: 210,
          unit: 'سم',
          unitEn: 'cm',
          isAr: isAr,
          color: AppColors.waterBlue,
          isDark: isDark,
          onChanged: (v) => setState(() => _height = (v * 10).round() / 10),
        ),
      );

      // ── Q5: Weight ──────────────────────────────────────
      case 5: return _QuestionShell(
        emoji: '⚖️',
        title: 'كم وزنك؟',
        titleEn: 'Your weight?',
        isDark: isDark,
        child: _NumberSlider(
          value: _weight,
          min: 30, max: 180,
          unit: 'كجم',
          unitEn: 'kg',
          isAr: isAr,
          color: AppColors.halalGreen,
          isDark: isDark,
          onChanged: (v) => setState(() => _weight = (v * 10).round() / 10),
        ),
      );

      // ── Summary ─────────────────────────────────────────
      default: return _SummaryPage(
        gender: _gender,
        age: _age,
        height: _height,
        weight: _weight,
        goalIdx: _goalIdx,
        activityIdx: _activityIdx,
        isDark: isDark,
      );
    }
  }

  // ── Language selector (onboarding screen 2) ──────────────
  Widget _buildLanguagePage(bool isDark) {
    final lang  = ref.watch(languageProvider);
    final textC = isDark ? Colors.white : const Color(0xFF1F2A1F);
    final muted = isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D);

    // 7 supported languages
    const langs = [
      ('ar', '🇸🇦', 'العربية',   'Arabic',     AppColors.sunnahGreen),
      ('en', '🇬🇧', 'English',   'الإنجليزية', AppColors.barakahGold),
      ('fr', '🇫🇷', 'Français',  'الفرنسية',   Color(0xFF4A90D9)),
      ('tr', '🇹🇷', 'Türkçe',    'التركية',    Color(0xFFE53935)),
      ('ur', '🇵🇰', 'اردو',      'الأردية',    Color(0xFF00897B)),
      ('ms', '🇲🇾', 'Melayu',    'الملايو',    Color(0xFF8E24AA)),
      ('id', '🇮🇩', 'Bahasa',    'الإندونيسية',Color(0xFFEF6C00)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: const Text('🌐', style: TextStyle(fontSize: 72)),
          ),
          const SizedBox(height: 20),
          Text('اختر لغتك', style: TextStyle(
            fontFamily: 'Cairo', fontSize: 28,
            fontWeight: FontWeight.w900, color: textC)),
          const SizedBox(height: 4),
          Text('Choose your language', style: TextStyle(
            fontFamily: 'Cairo', fontSize: 15, color: muted)),
          const SizedBox(height: 28),

          // 2-column grid of language cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: langs.map((l) {
              final (code, flag, name, sub, color) = l;
              final selected = lang == code;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(languageProvider.notifier).set(code);
                  setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? color.withOpacity(0.15) :
                      (isDark ? const Color(0xFF1E2D1E) : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? color : (isDark ? const Color(0xFF2D3D2D) : const Color(0xFFE0E0E0)),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Text(flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name, style: TextStyle(
                          fontFamily: 'Cairo', fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? color : textC)),
                        Text(sub, style: TextStyle(
                          fontFamily: 'Cairo', fontSize: 10,
                          color: muted)),
                      ],
                    )),
                    if (selected) Icon(Icons.check_circle, color: color, size: 18),
                  ]),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          Text(
            lang == 'ar' ? '✨ يمكنك تغييرها لاحقاً من الإعدادات'
                         : '✨ You can change this later in settings',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  WELCOME STEPS
// ═══════════════════════════════════════════════════════════
class _WelcomeStep {
  final String emoji, title, titleEn, subtitle, subtitleEn;
  final List<String> chips, chipsEn;
  final Color color;
  const _WelcomeStep(this.emoji, this.title, this.titleEn,
    this.subtitle, this.subtitleEn, this.chips, this.chipsEn, this.color);
}

const _welcomeSteps = [
  _WelcomeStep('🌿', 'هلال كالوري', 'HalalCalorie',
    'تطبيقك الأول لتتبع السعرات\nبطريقة حلال ١٠٠٪',
    'Your #1 app to track calories\nthe 100% Halal way',
    ['حلال ✓', 'عربي أولاً', 'خصوصية تامة'],
    ['Halal ✓', 'Privacy first', 'No ads'],
    AppColors.sunnahGreen),
  _WelcomeStep('🤖', 'ذكاء اصطناعي', 'AI-Powered',
    'صوّر طعامك أو امسح الباركود\nواحصل على السعرات فوراً',
    'Photo your food or scan a barcode\nget calories instantly',
    ['Claude AI', '١٠٠٠+ طعام', 'تعرف الطعام'],
    ['Claude AI', '1000+ foods', 'Smart detect'],
    AppColors.barakahGold),
  _WelcomeStep('🕌', 'إسلامي ١٠٠٪', '100% Islamic',
    'أوقات الصلاة • وضع رمضان\nأحاديث يومية • وصفات سنة',
    'Prayer times • Ramadan mode\nDaily hadith • Sunnah recipes',
    ['أوقات الصلاة', 'وضع رمضان', 'سنة نبوية'],
    ['Prayer times', 'Ramadan mode', 'Sunnah foods'],
    AppColors.waterBlue),
];

class _WelcomePage extends StatelessWidget {
  final _WelcomeStep step;
  final bool isDark;
  final String lang;
  const _WelcomePage({required this.step, required this.isDark, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Big icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  step.color.withOpacity(0.2),
                  step.color.withOpacity(0.05),
                ]),
                border: Border.all(color: step.color.withOpacity(0.35), width: 2),
              ),
              child: Center(child: Text(step.emoji,
                style: const TextStyle(fontSize: 64))),
            ),
          ),

          const SizedBox(height: 36),

          Text(lang == 'ar' ? step.title : step.titleEn, textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: 30, fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1F2A1F),
            )),

          const SizedBox(height: 12),

          Text(lang == 'ar' ? step.subtitle : step.subtitleEn, textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: 16, height: 1.7,
              color: isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D),
            )),

          const SizedBox(height: 28),

          Wrap(spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: (lang == 'ar' ? step.chips : step.chipsEn).map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: step.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: step.color.withOpacity(0.3)),
              ),
              child: Text(c, style: TextStyle(
                fontFamily: 'Cairo', fontSize: 13,
                fontWeight: FontWeight.w700, color: step.color,
              )),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  QUESTION SHELL
// ═══════════════════════════════════════════════════════════
class _QuestionShell extends ConsumerWidget {
  final String emoji, title, titleEn;
  final bool isDark;
  final Widget child;
  const _QuestionShell({
    required this.emoji, required this.title,
    required this.titleEn, required this.isDark, required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(languageProvider) == 'ar' || ref.watch(languageProvider) == 'ur';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(isAr ? title : titleEn, style: TextStyle(
            fontFamily: 'Cairo', fontSize: 28, fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1F2A1F),
          )),
          Text(isAr ? titleEn : title, style: TextStyle(
            fontFamily: 'Cairo', fontSize: 13,
            color: isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D),
          )),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  GENDER CARD
// ═══════════════════════════════════════════════════════════
class _GenderCard extends ConsumerWidget {
  final String emoji, labelAr, labelEn;
  final bool selected, isDark;
  final Color color;
  final VoidCallback onTap;
  const _GenderCard({
    required this.emoji, required this.labelAr, required this.labelEn,
    required this.selected, required this.isDark, required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(languageProvider) == 'ar' || ref.watch(languageProvider) == 'ur';
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        height: 150,
        decoration: BoxDecoration(
          color: selected
            ? color.withOpacity(0.12)
            : (isDark ? const Color(0xFF161B22) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : (isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF)),
            width: selected ? 2 : 0.5,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: TextStyle(
            fontSize: selected ? 52 : 44)),
          const SizedBox(height: 10),
          Text(isAr ? labelAr : labelEn, style: TextStyle(
            fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800,
            color: selected ? color : (isDark ? Colors.white : const Color(0xFF1F2A1F)),
          )),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
            ),
        ]),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
//  LANGUAGE CHOICE CARD
// ═══════════════════════════════════════════════════════════
class _LangChoice extends StatelessWidget {
  final String flag, label, sub;
  final bool selected, isDark;
  final Color color;
  final VoidCallback onTap;
  const _LangChoice({
    required this.flag, required this.label, required this.sub,
    required this.selected, required this.isDark,
    required this.color, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        height: 160,
        decoration: BoxDecoration(
          color: selected
            ? color.withOpacity(0.12)
            : (isDark ? const Color(0xFF161B22) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color
              : (isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF)),
            width: selected ? 2.5 : 0.5,
          ),
          boxShadow: selected
            ? [BoxShadow(color: color.withOpacity(0.2),
                blurRadius: 16, offset: const Offset(0, 4))]
            : [],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(flag, style: TextStyle(fontSize: selected ? 52 : 44)),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(
            fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w800,
            color: selected ? color
              : (isDark ? Colors.white : const Color(0xFF1F2A1F)),
          )),
          Text(sub, style: TextStyle(
            fontFamily: 'Cairo', fontSize: 11,
            color: selected ? color.withOpacity(0.8)
              : const Color(0xFF7D8590),
          )),
          if (selected) ...[
            const SizedBox(height: 8),
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 15),
            ),
          ],
        ]),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
//  SELECT TILE
// ═══════════════════════════════════════════════════════════
class _SelectTile extends ConsumerWidget {
  final String emoji, title;
  final String? titleEn;
  final bool selected, isDark;
  final VoidCallback onTap;
  const _SelectTile({
    required this.emoji, required this.title,
    this.titleEn,
    required this.selected, required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(languageProvider) == 'ar' || ref.watch(languageProvider) == 'ur';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected
            ? AppColors.halalGreen.withOpacity(0.1)
            : (isDark ? const Color(0xFF161B22) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
              ? AppColors.halalGreen
              : (isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF)),
            width: selected ? 2 : 0.5,
          ),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Text((!isAr && titleEn != null) ? titleEn! : title, style: TextStyle(
            fontFamily: 'Cairo', fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected
              ? AppColors.halalGreen
              : (isDark ? Colors.white : const Color(0xFF1F2A1F)),
          ))),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: selected ? AppColors.halalGreen : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                  ? AppColors.halalGreen
                  : (isDark ? const Color(0xFF7D8590) : const Color(0xFFCCCCCC)),
                width: 2,
              ),
            ),
            child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
              : null,
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  NUMBER SLIDER
// ═══════════════════════════════════════════════════════════
class _NumberSlider extends StatelessWidget {
  final double value, min, max;
  final String unit, unitEn;
  final Color color;
  final bool isDark;
  final bool isAr;
  final void Function(double) onChanged;
  const _NumberSlider({
    required this.value, required this.min, required this.max,
    required this.unit, required this.unitEn,
    required this.color, required this.isDark,
    this.isAr = true, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Column(children: [
      // Big number display
      TweenAnimationBuilder<double>(
        tween: Tween(begin: value - 5, end: value),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (_, v, __) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(v.toStringAsFixed(v % 1 == 0 ? 0 : 1),
              style: TextStyle(
                fontFamily: 'Cairo', fontSize: 72, fontWeight: FontWeight.w900,
                color: color, height: 1,
              )),
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 8),
              child: Text(isAr ? unit : unitEn, style: TextStyle(
                fontFamily: 'Cairo', fontSize: 18,
                fontWeight: FontWeight.w700, color: color.withOpacity(0.7),
              )),
            ),
          ],
        ),
      ),

      const SizedBox(height: 32),

      // Custom slider
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 6,
          activeTrackColor: color,
          inactiveTrackColor: color.withOpacity(0.15),
          thumbColor: color,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 28),
          overlayColor: color.withOpacity(0.15),
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min, max: max,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
        ),
      ),

      const SizedBox(height: 8),

      // Min / Max labels
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${min.toInt()} ${isAr ? unit : unitEn}',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
            color: isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D))),
        Text('${max.toInt()} ${isAr ? unit : unitEn}',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
            color: isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D))),
      ]),

      const SizedBox(height: 24),

      // Quick tap buttons
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _AdjustBtn(label: '−5', onTap: () => onChanged((value - 5).clamp(min, max)), color: color),
        const SizedBox(width: 10),
        _AdjustBtn(label: '−1', onTap: () => onChanged((value - 1).clamp(min, max)), color: color),
        const SizedBox(width: 10),
        _AdjustBtn(label: '+1', onTap: () => onChanged((value + 1).clamp(min, max)), color: color),
        const SizedBox(width: 10),
        _AdjustBtn(label: '+5', onTap: () => onChanged((value + 5).clamp(min, max)), color: color),
      ]),
    ]);
  }
}

class _AdjustBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _AdjustBtn({required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'Cairo', fontSize: 14,
          fontWeight: FontWeight.w800, color: color,
        )),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SUMMARY PAGE
// ═══════════════════════════════════════════════════════════
class _SummaryPage extends ConsumerWidget {
  final String gender;
  final int age, goalIdx, activityIdx;
  final double height, weight;
  final bool isDark;
  const _SummaryPage({
    required this.gender, required this.age,
    required this.height, required this.weight,
    required this.goalIdx, required this.activityIdx,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang   = ref.watch(languageProvider);
    final isAr   = lang == 'ar' || lang == 'ur';
    String t(String ar, String en) => isAr ? ar : en;
    final isMale = gender == 'brothers';
    final card   = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF);
    final muted  = isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D);

    // Quick BMI calculation
    final hM  = height / 100;
    final bmi = weight / (hM * hM);
    final bmiColor = bmi < 18.5 ? AppColors.waterBlue
      : bmi < 25 ? AppColors.halalGreen
      : bmi < 30 ? AppColors.doubtOrange
      : AppColors.haramRed;

    // Calorie estimate
    final bmr = isMale
      ? 10 * weight + 6.25 * height - 5 * age + 5
      : 10 * weight + 6.25 * height - 5 * age - 161;
    final acts = ActivityLevel.values;
    final mult = acts[activityIdx.clamp(0, acts.length - 1)].multiplier;
    final kcal = (bmr * mult).round();
    final goal = FitnessGoal.values[goalIdx.clamp(0, FitnessGoal.values.length - 1)];

    // Bilingual value strings
    final weightStr = '${weight.toStringAsFixed(1)} ${isAr ? 'كجم' : 'kg'}';
    final heightStr = '${height.toStringAsFixed(0)} ${isAr ? 'سم' : 'cm'}';
    final ageStr    = '$age ${isAr ? 'سنة' : 'yrs'}';
    final kcalStr   = '$kcal ${isAr ? 'سعرة' : 'kcal'}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(opacity: v,
            child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: child)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🎉', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(t('كل شيء جاهز!', 'All Set!'), style: TextStyle(
              fontFamily: 'Cairo', fontSize: 28, fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1F2A1F),
            )),
            Text(t('ملفك الشخصي محسوب',
                   'Your profile has been calculated'),
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: muted)),
          ]),
        ),

        const SizedBox(height: 24),

        // Stats grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            _SummaryTile('⚖️', t('الوزن', 'Weight'), weightStr,
              AppColors.halalGreen, card, border, isDark),
            _SummaryTile('📏', t('الطول', 'Height'), heightStr,
              AppColors.waterBlue, card, border, isDark),
            _SummaryTile('🎂', t('العمر', 'Age'), ageStr,
              AppColors.barakahGold, card, border, isDark),
            _SummaryTile('📊', 'BMI', bmi.toStringAsFixed(1),
              bmiColor, card, border, isDark),
          ],
        ),

        const SizedBox(height: 14),

        // Calorie target
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A6B4A), Color(0xFF00A86B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
              color: AppColors.sunnahGreen.withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 6),
            )],
          ),
          child: Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('هدف السعرات اليومي',
                     'Daily Calorie Goal'),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70)),
              Text(kcalStr, style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 24,
                fontWeight: FontWeight.w900, color: Colors.white,
              )),
              Text(t('محسوب لجسمك وهدفك',
                     'Calculated for your body & goal'),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white60)),
            ])),
          ]),
        ),

        const SizedBox(height: 14),

        // Goal summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Row(children: [
            Text(goal.emoji(), style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('هدفك', 'Your Goal'), style: TextStyle(
                fontFamily: 'Cairo', fontSize: 11, color: muted)),
              Text(isAr ? goal.nameAr() : goal.nameEn(),
                style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1F2A1F),
                )),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String emoji, label, value;
  final Color color, card, border;
  final bool isDark;
  const _SummaryTile(this.emoji, this.label, this.value,
    this.color, this.card, this.border, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const Spacer(),
        Text(value, style: TextStyle(
          fontFamily: 'Cairo', fontSize: 18,
          fontWeight: FontWeight.w900, color: color,
        )),
        Text(label, style: TextStyle(
          fontFamily: 'Cairo', fontSize: 10,
          color: isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  TOP BAR
// ═══════════════════════════════════════════════════════════
class _TopBar extends ConsumerWidget {
  final int page, total;
  final bool isDark, showBack;
  final VoidCallback onBack;
  final VoidCallback? onSkip;
  const _TopBar({
    required this.page, required this.total, required this.isDark,
    required this.showBack, required this.onBack, this.onSkip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar' || lang == 'ur';
    final pct = (page + 1) / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(children: [
        Row(children: [
          AnimatedOpacity(
            opacity: showBack ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: showBack ? onBack : null,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.arrow_back_ios_rounded, size: 14,
                  color: isDark ? Colors.white : const Color(0xFF1F2A1F)),
              ),
            ),
          ),
          const Spacer(),
          Text('${page + 1} / $total', style: TextStyle(
            fontFamily: 'Cairo', fontSize: 12,
            color: isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D))),
          const Spacer(),
          if (onSkip != null)
            GestureDetector(
              onTap: onSkip,
              child: Text(isAr ? 'تخطي' : 'Skip',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.halalGreen)),
            )
          else
            const SizedBox(width: 36),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 4,
            backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF),
            valueColor: const AlwaysStoppedAnimation(AppColors.halalGreen),
          ),
        ),
      ]),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  final int page;
  final bool isLast, isQuestion, isDark;
  final VoidCallback onNext;
  const _BottomBar({
    required this.page, required this.isLast,
    required this.isQuestion, required this.isDark, required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang  = ref.watch(languageProvider);
    final isAr  = lang == 'ar' || lang == 'ur';
    final label = isLast
      ? (isAr ? 'ابدأ رحلتك 🌿' : 'Start your journey 🌿')
      : (isAr ? 'التالي →' : 'Next →');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
      child: SizedBox(
        width: double.infinity, height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isLast
              ? const LinearGradient(
                  colors: [Color(0xFFD4A017), Color(0xFFFFB300)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)
              : const LinearGradient(
                  colors: [Color(0xFF0A6B4A), Color(0xFF00A86B)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: (isLast ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.35),
              blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: Text(label, style: const TextStyle(
              fontFamily: 'Cairo', fontSize: 17,
              fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double progress, pageProgress;
  final bool isDark;
  const _OrbPainter({
    required this.progress, required this.pageProgress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final orb1 = Paint()..color = const Color(0xFF0A6B4A)
      .withOpacity(isDark ? 0.08 : 0.06);
    final orb2 = Paint()..color = const Color(0xFFD4A017)
      .withOpacity(isDark ? 0.06 : 0.04);

    final x1 = size.width * (0.15 + 0.1 * sin(progress * pi));
    final y1 = size.height * (0.2 + 0.05 * cos(progress * pi));
    canvas.drawCircle(Offset(x1, y1), 200, orb1);

    final x2 = size.width * (0.85 - 0.1 * cos(progress * pi));
    final y2 = size.height * (0.75 + 0.05 * sin(progress * pi));
    canvas.drawCircle(Offset(x2, y2), 160, orb2);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
    old.progress != progress || old.pageProgress != pageProgress;
}
