// ============================================================
//  profile_screen.dart — HalalCalorie v1.0
//  Premium plan display, RevenueCat refresh, manage sub
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';
import '../../core/revenuecat_service.dart';
import '../../data/models/user_profile.dart';
import 'package:halalcalorie/data/icon_assets.dart';
import '../../core/motion.dart';
import '../../core/fx.dart';
import '../../core/fx4.dart';
import '../../core/fx6.dart';

// ══════════════════════════════════════════════════
//  ProfileScreen
// ══════════════════════════════════════════════════

// Cycle to next language in the supported list
String _nextLang(String current) {
  const langs = ['ar', 'en', 'fr', 'tr', 'ur', 'ms', 'id'];
  final idx = langs.indexOf(current);
  return langs[(idx + 1) % langs.length];
}

// Short display label for current lang
String _langLabel(String lang) {
  switch (lang) {
    case 'ar': return 'ع';
    case 'en': return 'EN';
    case 'fr': return 'FR';
    case 'tr': return 'TR';
    case 'ur': return 'اردو';
    case 'ms': return 'MY';
    case 'id': return 'ID';
    default:   return 'EN';
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang      = ref.watch(languageProvider);
    final isAr      = lang == 'ar' || lang == 'ur';
    final gender    = ref.watch(genderProvider);
    final streak    = ref.watch(streakProvider);
    final water     = ref.watch(waterProvider);
    final sleep     = ref.watch(sleepProvider);
    final isPremium = ref.watch(premiumProvider);
    final planAsync = ref.watch(planNameProvider);
    final planName  = planAsync.valueOrNull ?? 'free';
    final city      = ref.watch(cityProvider);
    final isDark    = ref.watch(themeProvider);
    final profile   = ref.watch(userProfileProvider);
    final isSis     = gender == 'sisters' || profile?.gender == 'sisters';
    final workoutMin = ref.watch(workoutMinutesProvider);

    final bg     = isDark ? AppColors.darkBg : AppColors.lightBg;
    final card   = isDark ? const Color(0xFF0F1E18) : Colors.white;
    final textC  = isDark ? AppColors.darkText  : AppColors.lightText;
    final muted  = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accent = isSis ? AppColors.accentGold : AppColors.halalGreen;

    final plan = ref.watch(macroPlanProvider);
    final l = L.fromLang(lang);
    String t(String ar, String en) => l.t(ar, en);

    BoxDecoration cardDeco([Color? edge]) => BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: edge ?? border, width: edge == null ? 0.6 : 0.9),
      boxShadow: [BoxShadow(
        color: (edge ?? Colors.black).withOpacity(isDark ? 0.30 : 0.07),
        blurRadius: 24, offset: const Offset(0, 8))],
    );

    final planLabel = isAr
        ? (planName == 'lifetime' ? 'بريميوم مدى الحياة'
           : planName == 'yearly'  ? 'بريميوم سنوي'
           : planName == 'monthly' ? 'بريميوم شهري' : 'بريميوم')
        : (planName == 'lifetime' ? 'Lifetime Premium'
           : planName == 'yearly'  ? 'Yearly Premium'
           : planName == 'monthly' ? 'Monthly Premium' : 'Premium');

    Widget infoChip(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withOpacity(0.10),
        border: Border.all(color: accent.withOpacity(0.30), width: 0.7),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
            fontWeight: FontWeight.w700, color: textC)),
      ]),
    );

    Widget vital(VitalKind kind, double pct, Color color, String value, String label) =>
      Expanded(child: Container(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [card, Color.lerp(card, color, isDark ? 0.10 : 0.07)!]),
          border: Border.all(color: Color.lerp(border, color, 0.35)!, width: 0.8),
          boxShadow: [BoxShadow(color: color.withOpacity(isDark ? 0.14 : 0.10),
              blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          VitalGlyph(kind: kind, pct: pct, color: color, size: 48),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontFamily: 'Aligarh', fontSize: 17,
              fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10.5,
              color: muted)),
        ]),
      ));

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        Positioned.fill(
          child: AuroraBackground(
            base: bg,
            colors: [accent, AppColors.accentGold, const Color(0xFF0E6B6B)],
            intensity: isDark ? 0.55 : 0.30,
            seconds: 22,
          ),
        ),
        SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // ── Top bar ───────────────────────────────────
              Reveal(index: 0, child: Row(children: [
                Expanded(child: Text(l.myProfile, style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 26,
                    fontWeight: FontWeight.w900, color: textC))),
                GlassIconBtn(
                  isDark: isDark,
                  onTap: () => ref.read(languageProvider.notifier).set(_nextLang(lang)),
                  child: Text(_langLabel(lang), style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 13,
                      fontWeight: FontWeight.w800, color: textC)),
                ),
                const SizedBox(width: 8),
                GlassIconBtn(
                  isDark: isDark,
                  icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  onTap: () => ref.read(themeProvider.notifier).toggle(),
                ),
              ])),
              const SizedBox(height: 18),

              // ── Hero ──────────────────────────────────────
              Reveal(index: 1, child: Column(children: [
                AvatarRing(
                  size: 124,
                  gap: bg,
                  colors: [accent, AppColors.accentGold, AppColors.waterBlue],
                  child: Container(
                    color: accent.withOpacity(0.14),
                    child: Image.asset(
                      isSis ? kAvatarSisters : kAvatarBrothers,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person_rounded, size: 56, color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(isSis ? l.womanLabel : l.manLabel, style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 22,
                    fontWeight: FontWeight.w900, color: textC)),
                const SizedBox(height: 2),
                Text(isSis ? l.sistersMode : l.menMode, style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 12.5, color: muted)),
                if (profile != null) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    infoChip(Icons.cake_rounded, '${profile.age} ${l.yrsLabel}'),
                    infoChip(Icons.height_rounded, '${profile.heightCm.toInt()} cm'),
                    infoChip(Icons.monitor_weight_rounded,
                        '${profile.weightKg.toStringAsFixed(1)} kg'),
                  ]),
                  const SizedBox(height: 10),
                  Text(isAr ? profile.primaryGoal.nameAr() : profile.primaryGoal.nameEn(),
                      style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
                          color: accent, fontWeight: FontWeight.w800)),
                ],
                if (isPremium) ...[
                  const SizedBox(height: 12),
                  PressFx(
                    onTap: () => ref.read(premiumProvider.notifier).refresh(),
                    scale: 0.95,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                            colors: [Color(0xFFF0CF98), Color(0xFFDBA75D)]),
                        boxShadow: [BoxShadow(
                            color: AppColors.accentGold.withOpacity(0.4),
                            blurRadius: 18)],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.workspace_premium_rounded,
                            size: 16, color: Color(0xFF1A0F00)),
                        const SizedBox(width: 6),
                        Text(planLabel, style: const TextStyle(
                            fontFamily: 'Aligarh', fontSize: 12.5,
                            fontWeight: FontWeight.w900, color: Color(0xFF1A0F00))),
                      ]),
                    ),
                  ),
                ],
              ])),
              const SizedBox(height: 20),

              // ── Vitals ────────────────────────────────────
              Reveal(index: 2, child: Row(children: [
                vital(VitalKind.flame, (streak / 30).clamp(0.0, 1.0),
                    AppColors.haramRed, '$streak', t('تتابع', 'Streak')),
                const SizedBox(width: 10),
                vital(VitalKind.water, water.percent, AppColors.waterBlue,
                    '${water.cups}/${water.goal}', t('الماء', 'Water')),
                const SizedBox(width: 10),
                vital(VitalKind.sleep, sleep.percent, AppColors.sleepPurple,
                    '${sleep.hours.toInt()}h', t('النوم', 'Sleep')),
              ])),
              const SizedBox(height: 14),

              // ── Lifetime stats ────────────────────────────
              Reveal(index: 3, child: Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: Column(children: [
                  Row(children: [
                    const IconBadge(icon: Icons.emoji_events_rounded,
                        color: AppColors.accentGold, size: 34),
                    const SizedBox(width: 10),
                    Text(t('إحصائياتك الكلية', 'Lifetime stats'), style: TextStyle(
                        fontFamily: 'Aligarh', fontWeight: FontWeight.w800,
                        fontSize: 14.5, color: textC)),
                  ]),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _lifeStat(Icons.local_fire_department_rounded, '$streak',
                        t('أيام تتابع', 'Streak'), AppColors.haramRed, muted),
                    _lifeStat(Icons.directions_run_rounded,
                        workoutMin > 0 ? '${workoutMin}m' : '—',
                        t('اليوم', 'Today'), AppColors.halalGreen, muted),
                    _lifeStat(Icons.water_drop_rounded, '${water.cups}/${water.goal}',
                        t('ماء اليوم', 'Water'), AppColors.waterBlue, muted),
                    _lifeStat(Icons.bedtime_rounded, '${sleep.hours.toInt()}h',
                        t('نوم اليوم', 'Sleep'), AppColors.sleepPurple, muted),
                  ]),
                ]),
              )),
              const SizedBox(height: 14),

              // ── Body metrics ──────────────────────────────
              if (profile != null) ...[
                Reveal(index: 4, child: PressFx(
                  onTap: () => context.go('/body'),
                  scale: 0.985,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: cardDeco(),
                    child: Column(children: [
                      Row(children: [
                        const IconBadge(icon: Icons.accessibility_new_rounded,
                            color: AppColors.halalGreen, size: 34),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t('مقاييس جسمك', 'Body metrics'),
                            style: TextStyle(fontFamily: 'Aligarh',
                                fontWeight: FontWeight.w800, fontSize: 14.5,
                                color: textC))),
                        Text(t('عرض الكل', 'View all'), style: const TextStyle(
                            fontFamily: 'Aligarh', fontSize: 12,
                            fontWeight: FontWeight.w700, color: AppColors.halalGreen)),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.halalGreen),
                      ]),
                      const SizedBox(height: 14),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _bodyMini('BMI', profile.bmi.toStringAsFixed(1),
                            _bmiColor(profile.bmi), muted),
                        _bodyMini(t('السعرات', 'Cals'),
                            '${profile.calorieGoalKcal.toInt()}', AppColors.haramRed, muted),
                        _bodyMini(isAr ? plan.nameAr() : plan.nameEn(),
                            'P:${(profile.calorieGoalKcal * plan.proteinPct / 400).toInt()}g',
                            AppColors.halalGreen, muted),
                        _bodyMini(t('الماء', 'Water'), '${profile.waterLiters}L',
                            AppColors.waterBlue, muted),
                      ]),
                    ]),
                  ),
                )),
                const SizedBox(height: 14),
              ],

              // ── Achievements ──────────────────────────────
              Reveal(index: 5,
                child: _achievementsCard(isPremium, isAr, isDark, ref, context)),
              const SizedBox(height: 14),

              // ── Premium upsell ────────────────────────────
              if (!isPremium) ...[
                Reveal(index: 6, child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF0E3B26), Color(0xFF07160F)]),
                    border: Border.all(
                        color: AppColors.accentGold.withOpacity(0.45), width: 0.9),
                    boxShadow: [BoxShadow(
                        color: AppColors.accentGold.withOpacity(0.18),
                        blurRadius: 26, offset: const Offset(0, 10))],
                  ),
                  child: Column(children: [
                    Row(children: [
                      const BrandMark(size: 42),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t('ترقية إلى بريميوم', 'Upgrade to Premium'),
                            style: const TextStyle(fontFamily: 'Aligarh',
                                fontWeight: FontWeight.w900, fontSize: 15.5,
                                color: Color(0xFFF0CF98))),
                        const SizedBox(height: 3),
                        Text(t('ماسحات غير محدودة + ١٨٠ تمرين + مخطط AI + مقاييس دقيقة',
                               'Unlimited scans + 180 workouts + AI planner + precise body metrics'),
                            style: const TextStyle(fontFamily: 'Aligarh',
                                fontSize: 11.5, height: 1.4, color: Colors.white70)),
                      ])),
                    ]),
                    const SizedBox(height: 14),
                    ShineButton(
                      label: t('افتح بريميوم', 'Unlock Premium'),
                      icon: Icons.workspace_premium_rounded,
                      height: 50,
                      onPressed: () => context.push('/paywall'),
                    ),
                  ]),
                )),
                const SizedBox(height: 14),
              ],

              // ── Account list ──────────────────────────────
              Reveal(index: 7, child: Container(
                decoration: cardDeco(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(children: [
                      _tileRow(Icons.location_on_rounded, AppColors.haramRed,
                          t('المدينة', 'City'), city, textC, muted, border,
                          () => _showCityPicker(context, ref, isAr)),
                      _tileRow(Icons.translate_rounded, AppColors.waterBlue,
                          t('اللغة', 'Language'),
                          tLang(lang, 'العربية', 'English', 'Français', 'Türkçe', 'Melayu', 'Indonesia'),
                          textC, muted, border,
                          () => ref.read(languageProvider.notifier).set(_nextLang(lang))),
                      _tileRow(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          isDark ? AppColors.accentGold : const Color(0xFF7F8CFF),
                          isDark ? t('الوضع النهاري', 'Day mode') : t('الوضع الليلي', 'Night mode'),
                          isDark ? t('مفعّل', 'Active') : t('معطّل', 'Off'),
                          textC, muted, border,
                          () => ref.read(themeProvider.notifier).toggle()),
                      if (profile != null)
                        _tileRow(Icons.edit_rounded, AppColors.halalGreen,
                            t('تعديل معلوماتي', 'Edit my info'), '',
                            textC, muted, border, () => context.go('/body')),
                      if (isPremium)
                        _tileRow(Icons.workspace_premium_rounded, AppColors.accentGold,
                            t('إدارة الاشتراك', 'Manage subscription'),
                            isAr
                              ? (planName == 'lifetime' ? 'مدى الحياة' : planName == 'yearly' ? 'سنوي نشط' : 'شهري نشط')
                              : (planName == 'lifetime' ? 'Lifetime' : planName == 'yearly' ? 'Yearly active' : 'Monthly active'),
                            textC, muted, border,
                            () async {
                              await ref.read(premiumProvider.notifier).refresh();
                              if (context.mounted) _showManageSubSheet(context, ref, isAr, planName);
                            }),
                      if (!isPremium)
                        _tileRow(Icons.lock_open_rounded, AppColors.accentGold,
                            t('ترقية إلى بريميوم', 'Upgrade to Premium'),
                            t('افتح كل الميزات', 'Unlock all features'),
                            textC, muted, border,
                            () { if (context.mounted) context.push('/paywall'); }),
                      _tileRow(Icons.lock_outline_rounded, AppColors.halalGreen,
                          t('سياسة الخصوصية', 'Privacy policy'), '',
                          textC, muted, border, () {}),
                      _tileRow(Icons.info_outline_rounded, AppColors.waterBlue,
                          t('حول التطبيق', 'About app'), 'v1.6',
                          textC, muted, border,
                          () => showAboutDialog(
                            context: context, applicationName: 'HalalCalorie',
                            applicationVersion: '1.6.0',
                            children: [const Text('© 2026 HalalCalorie — Halal • Private • Ad-free',
                                style: TextStyle(fontFamily: 'Aligarh'))])),
                      _tileRow(Icons.logout_rounded, AppColors.haramRed,
                          t('تسجيل الخروج', 'Sign out'), '',
                          textC, muted, border,
                          () => _signOut(context, ref, isAr),
                          danger: true, last: true),
                    ]),
                  ),
                ),
              )),
            ],
          ),
        ),
      ]),
    );
  }

  // ── ACHIEVEMENT BADGES ─────────────────────────────────────
  Widget _achievementsCard(bool isPremium, bool isAr, bool isDark, WidgetRef ref, BuildContext context) {
    final ach  = ref.watch(achievementProvider);
    final fast = ref.watch(fastingProvider);
    final card = isDark ? const Color(0xFF0F1E18) : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final textC = isDark ? AppColors.darkText : AppColors.lightText;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    String t(String ar, String en) => isAr ? ar : en;

    final badges = <(IconData, String, bool)>[
      (Icons.eco_rounded,           t('البداية','Awakened'),         ach.totalDaysLogged >= 1),
      (Icons.link_rounded,          t('أسبوع كامل','Chain of Seven'), ach.totalDaysLogged >= 7),
      (Icons.nights_stay_rounded,   t('أول إمساك','First Restraint'), fast.lifetimeCount >= 1),
      (Icons.terrain_rounded,       t('الثابت','Unmoved'),           fast.lifetimeCount >= 7),
      (Icons.spa_rounded,           t('الطيّب','Wholesome'),         ach.wholeFoodsLogged >= 3),
      (Icons.auto_awesome_rounded,  t('المتقن','Refined'),           ach.totalDaysLogged >= 30),
      (Icons.emoji_events_rounded,  t('المئة','Centurion'),          ach.totalDaysLogged >= 100),
      (Icons.menu_book_rounded,     t('العزم','Resolve'),
        ach.totalDaysLogged >= 28 && fast.lifetimeCount >= 4),
    ];
    final earned = badges.where((b) => b.$3).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 0.6),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.30 : 0.07),
          blurRadius: 24, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(icon: Icons.military_tech_rounded,
              color: AppColors.accentGold, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Text(t('إنجازاتك','Your achievements'),
            style: TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w800,
              fontSize: 14.5, color: textC))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$earned/${badges.length}',
              style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11.5,
                fontWeight: FontWeight.w800, color: AppColors.accentGold)),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
          children: badges.map((b) => _badge(b.$1, b.$2, b.$3, muted, isDark)).toList()),
        if (!isPremium) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/paywall'),
            child: Center(child: Text(
              t('ترقّ لفتح كل الإنجازات','Upgrade to unlock all badges'),
              style: const TextStyle(fontFamily: 'Aligarh',
                fontSize: 11.5, color: AppColors.accentGold))),
          ),
        ],
      ]),
    );
  }

  Widget _badge(IconData icon, String label, bool earned, Color muted, bool isDark) =>
    AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: earned
            ? LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppColors.accentGold.withOpacity(0.20),
                         AppColors.accentGold.withOpacity(0.05)])
            : null,
        color: earned ? null : (isDark ? const Color(0xFF16231C) : const Color(0xFFF1F3F2)),
        border: Border.all(
          color: earned ? AppColors.accentGold.withOpacity(0.5) : Colors.transparent),
        boxShadow: earned
            ? [BoxShadow(color: AppColors.accentGold.withOpacity(0.22), blurRadius: 14)]
            : const [],
      ),
      child: Column(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: earned
                ? const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFFF0CF98), Color(0xFFDBA75D)])
                : null,
            color: earned ? null : muted.withOpacity(0.14),
          ),
          child: Icon(earned ? icon : Icons.lock_rounded,
              size: earned ? 21 : 17,
              color: earned ? const Color(0xFF1A0F00) : muted.withOpacity(0.7)),
        ),
        const SizedBox(height: 6),
        Text(label,
          style: TextStyle(fontFamily: 'Aligarh', fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: earned ? AppColors.accentGold : muted),
          textAlign: TextAlign.center, maxLines: 2,
          overflow: TextOverflow.ellipsis),
      ]),
    );

  Widget _lifeStat(IconData icon, String val, String label, Color col, Color muted) {
    return Column(children: [
      Icon(icon, size: 22, color: col),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontFamily: 'Aligarh', fontSize: 15,
          fontWeight: FontWeight.w900, color: col)),
      Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
    ]);
  }

  Widget _bodyMini(String label, String value, Color color, Color muted) {
    return Column(children: [
      Text(value, style: TextStyle(fontFamily: 'Aligarh', fontSize: 16,
          fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
    ]);
  }

  Widget _tileRow(IconData icon, Color color, String title, String sub,
      Color textC, Color muted, Color border, VoidCallback onTap,
      {bool danger = false, bool last = false}) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            IconBadge(icon: icon, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontFamily: 'Aligarh', fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: danger ? AppColors.haramRed : textC)),
              if (sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(sub, style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 11.5, color: muted)),
                ),
            ])),
            Icon(Icons.chevron_right_rounded, size: 21, color: muted),
          ]),
        ),
      ),
      if (!last)
        Divider(height: 1, indent: 62, endIndent: 14, color: border),
    ]);
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.waterBlue;
    if (bmi < 25)   return AppColors.halalGreen;
    if (bmi < 30)   return AppColors.doubtOrange;
    return AppColors.haramRed;
  }

  // The default city is stored in Arabic while the picker lists English names.
  static bool _sameCity(String stored, String c) {
    if (stored.trim().toLowerCase() == c.toLowerCase()) return true;
    return c == 'Cairo' && stored.trim() == '\u0627\u0644\u0642\u0627\u0647\u0631\u0629';
  }

  void _showCityPicker(BuildContext context, WidgetRef ref, bool isAr) {
    final lang = ref.read(languageProvider);
    // Every entry resolves in prayer_provider's city table.
    const cities = [
      'Cairo', 'Alexandria', 'Giza', 'Riyadh', 'Jeddah', 'Mecca', 'Medina',
      'Dubai', 'Abu Dhabi', 'Doha', 'Kuwait City', 'Manama', 'Muscat', 'Amman',
      'Beirut', 'Damascus', 'Baghdad', 'Istanbul', 'Ankara', 'Karachi', 'Lahore',
      'Islamabad', 'Jakarta', 'Kuala Lumpur', 'Casablanca', 'Tunis', 'Algiers',
      'Khartoum', 'London', 'Paris', 'Berlin', 'New York', 'Toronto', 'Sydney',
    ];
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(16), children: [
      Text(tLang(lang, 'اختر مدينتك', 'Choose Your City', 'Choisissez votre ville', 'Şehrinizi Seçin', 'Pilih Bandar Anda', 'Pilih Kota Anda'),
          style: const TextStyle(fontFamily: 'Aligarh', fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      ...cities.map((c) => ListTile(
        title: Text(c, style: TextStyle(fontFamily: 'Aligarh',
          color: _sameCity(ref.read(cityProvider), c) ? AppColors.brandGreen : null,
          fontWeight: _sameCity(ref.read(cityProvider), c) ? FontWeight.w700 : FontWeight.w400)),
        trailing: _sameCity(ref.read(cityProvider), c) ? const Icon(Icons.check, color: AppColors.brandGreen) : null,
        onTap: () { ref.read(cityProvider.notifier).set(c); if (context.mounted) Navigator.pop(context); },
      )),
    ]));
  }

  void _showManageSubSheet(BuildContext context, WidgetRef ref, bool isAr, String planName) {
    final lang = ref.read(languageProvider);
    // planName: monthly | yearly | lifetime
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(padding: const EdgeInsets.all(22), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const EmojiIcon('⭐', size: 40),
          const SizedBox(height: 8),
          Text(tLang(lang, 'إدارة اشتراكك', 'Manage Your Subscription', 'Gérer votre abonnement', 'Aboneliğinizi Yönetin', 'Urus Langganan Anda', 'Kelola Langganan Anda'),
            style: const TextStyle(fontFamily: 'Aligarh', fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            isAr
              ? (planName == 'lifetime' ? 'خطة مدى الحياة — لا يوجد تجديد تلقائي'
                 : planName == 'yearly'  ? 'خطة سنوية — تتجدد تلقائياً كل سنة'
                 : 'خطة شهرية — تتجدد تلقائياً كل شهر')
              : (planName == 'lifetime' ? 'Lifetime plan — no auto-renewal'
                 : planName == 'yearly'  ? 'Yearly plan — auto-renews annually'
                 : 'Monthly plan — auto-renews monthly'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: AppColors.lightMuted),
          ),
          const SizedBox(height: 20),
          if (planName != 'lifetime') ListTile(
            leading: const EmojiIcon('📱', size: 22),
            title: Text(tLang(lang, 'إلغاء الاشتراك', 'Cancel Subscription', 'Annuler l\'abonnement', 'Aboneliği İptal Et', 'Batalkan Langganan', 'Batalkan Langganan'),
              style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w600, color: AppColors.haramRed)),
            subtitle: Text(tLang(lang, 'من خلال App Store أو Google Play', 'Via App Store or Google Play', 'Via App Store ou Google Play', 'App Store veya Google Play üzerinden', 'Melalui App Store atau Google Play', 'Melalui App Store atau Google Play'),
              style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: AppColors.lightMuted)),
            onTap: () {
              if (context.mounted) Navigator.pop(context);
              // Deep link to subscription management
              // iOS: 'https://apps.apple.com/account/subscriptions'
              // Android: 'https://play.google.com/store/account/subscriptions'
            },
          ),
          ListTile(
            leading: const EmojiIcon('🔄', size: 22),
            title: Text(tLang(lang, 'استعادة المشتريات', 'Restore Purchases', 'Restaurer les achats', 'Satın Almaları Geri Yükle', 'Pulihkan Pembelian', 'Pulihkan Pembelian'),
              style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w600)),
            onTap: () async {
              if (context.mounted) Navigator.pop(context);
              final result = await RevenueCatService.restore();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result.success
                  ? (tLang(lang, '✅ تم استعادة الاشتراك', '✅ Subscription restored', '✅ Abonnement restauré', '✅ Abonelik geri yüklendi', '✅ Langganan dipulihkan', '✅ Langganan dipulihkan'))
                  : (tLang(lang, 'لم يتم العثور على مشتريات', 'No purchases found', 'Aucun achat trouvé', 'Satın alma bulunamadı', 'Tiada pembelian dijumpai', 'Tidak ada pembelian ditemukan')),
                style: const TextStyle(fontFamily: 'Aligarh')),
                backgroundColor: result.success ? AppColors.brandGreen : AppColors.haramRed,
              ));
            },
          ),
          const SizedBox(height: 8),
        ],
      )),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref, bool isAr) async {
    final lang = ref.read(languageProvider);
    final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      title: Text(tLang(lang, 'تسجيل الخروج', 'Sign Out', 'Se déconnecter', 'Çıkış Yap', 'Log Keluar', 'Keluar'), style: const TextStyle(fontFamily: 'Aligarh')),
      content: Text(tLang(lang, 'هل أنت متأكد؟', 'Are you sure?', 'Êtes-vous sûr ?', 'Emin misiniz?', 'Adakah anda pasti?', 'Anda yakin?'), style: const TextStyle(fontFamily: 'Aligarh')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx, false),
          child: Text(tLang(lang, 'إلغاء', 'Cancel', 'Annuler', 'İptal', 'Batal', 'Batal'), style: const TextStyle(fontFamily: 'Aligarh'))),
        TextButton(onPressed: () => Navigator.pop(dialogCtx, true),
          child: Text(tLang(lang, 'خروج', 'Sign Out', 'Se déconnecter', 'Çıkış Yap', 'Log Keluar', 'Keluar'),
            style: const TextStyle(fontFamily: 'Aligarh', color: AppColors.haramRed))),
      ],
    ));
    if (ok == true && context.mounted) {
      await ref.read(onboardingDoneProvider.notifier).reset();
      await ref.read(userProfileProvider.notifier).clear();
      await ref.read(premiumProvider.notifier).revoke();
      await RevenueCatService.logOut();
      if (context.mounted) context.go('/onboarding');
    }
  }
}

