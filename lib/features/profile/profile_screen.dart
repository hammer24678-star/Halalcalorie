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
import 'package:go_router/go_router.dart';
import '../../core/revenuecat_service.dart';
import '../../data/models/user_profile.dart';

// ══════════════════════════════════════════════════
//  ProfileScreen
// ══════════════════════════════════════════════════
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

    final bg    = isDark ? AppColors.darkCard  : Colors.white;
    final textC = isDark ? AppColors.darkText  : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    final plan = ref.watch(macroPlanProvider);
    final lang   = ref.watch(languageProvider);
    String t(String ar, String en) => tLang(lang, ar, en);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('ملفي الشخصي', 'My Profile')),
        actions: [
          // Language toggle
          GestureDetector(
            onTap: () => ref.read(languageProvider.notifier).set(isAr ? 'en' : 'ar'),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Text(isAr ? 'EN' : 'ع', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          // Dark toggle
          GestureDetector(
            onTap: () => ref.read(themeProvider.notifier).toggle(),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round, color: Colors.white)),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        // ── Avatar hero card ─────────────────────────────
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
          child: Column(children: [
            Container(width: 96, height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: isSis ? AppColors.barakahGold.withOpacity(0.15) : AppColors.sunnahGreen.withOpacity(0.12)),
              child: Center(child: Text(isSis ? '🧕' : '🧔', style: const TextStyle(fontSize: 44)))),
            const SizedBox(height: 11),
            Text(isSis ? t('امرأة', 'Woman') : t('رجل', 'Man'),
                style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w800, color: textC)),
            const SizedBox(height: 3),
            Text(isSis ? t('وضع النساء', "Women Mode") : t('وضع الرجال', "Men Mode"),
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted)),
            if (profile != null) ...[
              const SizedBox(height: 6),
              Text('${profile.age} ${t("سنة","yrs")} • ${profile.heightCm.toInt()} cm • ${profile.weightKg.toStringAsFixed(1)} kg',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted)),
              Text(isAr ? profile.primaryGoal.nameAr() : profile.primaryGoal.nameEn(),
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.sunnahGreen, fontWeight: FontWeight.w700)),
            ],
            if (isPremium) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => ref.read(premiumProvider.notifier).refresh(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.barakahGold.withOpacity(0.15),
                    border: Border.all(color: AppColors.barakahGold),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('⭐', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      isAr
                        ? (planName == 'lifetime' ? 'بريميوم مدى الحياة'
                           : planName == 'yearly'  ? 'بريميوم سنوي'
                           : planName == 'monthly' ? 'بريميوم شهري'
                           : 'بريميوم')
                        : (planName == 'lifetime' ? 'Lifetime Premium'
                           : planName == 'yearly'  ? 'Yearly Premium'
                           : planName == 'monthly' ? 'Monthly Premium'
                           : 'Premium'),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12,
                          fontWeight: FontWeight.w700, color: AppColors.barakahGold),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 13),

        // ── Stats row ─────────────────────────────────────
        Row(children: [
          _statCard('🔥', '$streak', t('تتابع', 'Streak'), bg),
          const SizedBox(width: 9),
          _statCard('💧', '${water.cups}/${water.goal}', t('الماء', 'Water'), bg),
          const SizedBox(width: 9),
          _statCard('😴', '${sleep.hours.toInt()}h', t('النوم', 'Sleep'), bg),
        ]),
        const SizedBox(height: 13),

        // ── Lifetime stats ────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
          child: Column(children: [
            Text(t('🏆 إحصائياتك الكلية', '🏆 Lifetime Stats'),
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _lifeStat('🔥', '$streak', t('أيام تتابع', 'Streak'), AppColors.haramRed),
              _lifeStat('🏃', workoutMin > 0 ? '${workoutMin}m' : '—',
                  t('اليوم', 'Today'), AppColors.sunnahGreen),
              _lifeStat('💧', '${water.cups}/${water.goal}',
                  t('ماء اليوم', 'Today Water'), AppColors.waterBlue),
              _lifeStat('😴', '${sleep.hours.toInt()}h',
                  t('نوم اليوم', 'Tonight'), AppColors.sleepPurple),
            ]),
          ]),
        ),
        const SizedBox(height: 13),

        // ── Body quick metrics ────────────────────────────
        if (profile != null) ...[
          GestureDetector(
            onTap: () => context.go('/body'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(t('💪 مقاييس جسمك', '💪 Body Metrics'),
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(t('مشاهدة الكل ←', '→ View All'),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.sunnahGreen)),
                ]),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _bodyMini('BMI', profile.bmi.toStringAsFixed(1), _bmiColor(profile.bmi)),
                  _bodyMini(t('السعرات','Cals'), '${profile.calorieGoalKcal.toInt()}', AppColors.haramRed),
                  _bodyMini(
                    '${plan.emoji()} ${isAr ? plan.nameAr() : plan.nameEn()}',
                    'P:${(profile.calorieGoalKcal * plan.proteinPct / 400).toInt()}g',
                    AppColors.halalGreen),
                  _bodyMini(t('الماء','Water'), '${profile.waterLiters}L', AppColors.waterBlue),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 13),
        ],

        // ── Achievement Badges ───────────────────────────────
        _achievementsCard(isPremium, isAr, isDark, ref, context),
        const SizedBox(height: 12),
                // ── Premium upsell ────────────────────────────────
        if (!isPremium) ...[
          GestureDetector(
            onTap: () => context.push('/paywall'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sunnahGreen.withOpacity(0.06),
                border: Border.all(color: AppColors.sunnahGreen.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Text('⭐', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t('ترقية إلى بريميوم', 'Upgrade to Premium'),
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.sunnahGreen)),
                  Text(t('ماسحات غير محدودة + ١٨٠ تمرين + مخطط AI + مقاييس دقيقة',
                         'Unlimited scans + 180 workouts + AI planner + precise body metrics'),
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.lightMuted)),
                ])),
                const Icon(Icons.arrow_back_ios, size: 14, color: AppColors.sunnahGreen),
              ]),
            ),
          ),
          const SizedBox(height: 13),
        ],

        // ── Settings list ─────────────────────────────────
        Container(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
          child: Column(children: [
            _settingTile('📍', t('المدينة', 'City'), city, () => _showCityPicker(context, ref, isAr)),
            _settingTile('🌐', t('اللغة', 'Language'), isAr ? 'العربية' : 'English',
              () => ref.read(languageProvider.notifier).set(isAr ? 'en' : 'ar')),
            _settingTile(isDark ? '☀️' : '🌙',
              isDark ? t('الوضع النهاري','Day Mode') : t('الوضع الليلي','Night Mode'),
              isDark ? t('مفعّل','Active') : t('معطّل','Off'),
              () => ref.read(themeProvider.notifier).toggle()),
            if (profile != null)
              _settingTile('✏️', t('تعديل معلوماتي', 'Edit My Info'), '', () => context.go('/body')),
            if (isPremium)
              _settingTile('⭐', t('إدارة الاشتراك','Manage Subscription'),
                isAr
                  ? (planName == 'lifetime' ? 'مدى الحياة' : planName == 'yearly' ? 'سنوي نشط' : 'شهري نشط')
                  : (planName == 'lifetime' ? 'Lifetime' : planName == 'yearly' ? 'Yearly active' : 'Monthly active'),
                () async {
                  // Refresh from RC then show management options
                  await ref.watch(premiumProvider.notifier).refresh();
                  if (context.mounted) _showManageSubSheet(context, isAr, planName);
                }),
            if (!isPremium)
              _settingTile('🔓', t('ترقية إلى بريميوم','Upgrade to Premium'), t('افتح كل الميزات','Unlock all features'),
                () { if (context.mounted) context.push('/paywall'); }),
            _settingTile('🔒', t('سياسة الخصوصية','Privacy Policy'), '', () {}),
            _settingTile('ℹ️', t('حول التطبيق','About App'), 'v1.0', () => showAboutDialog(
              context: context, applicationName: 'HalalCalorie / HalalCalorie',
              applicationVersion: '0.6.0',
              children: [const Text('© 2026 HalalCalorie — Halal • Sunnah • Privacy',
                  style: TextStyle(fontFamily: 'Cairo'))])),
            ListTile(
              leading: const Text('🚪', style: TextStyle(fontSize: 20)),
              title: Text(t('تسجيل الخروج','Sign Out'),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.haramRed)),
              onTap: () => _signOut(context, ref, isAr),
            ),
          ]),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ── ACHIEVEMENT BADGES ─────────────────────────────────────
  Widget _achievementsCard(bool isPremium, bool isAr, bool isDark, WidgetRef ref, BuildContext context) {
    final ach  = ref.watch(achievementProvider);
    final fast = ref.watch(sunnahFastProvider);
    final bg   = isDark ? AppColors.darkCard : Colors.white;
    final muted= isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String t(String ar, String en) => tLang(lang, ar, en);

    final badges = <(String, String, bool)>[
      ('🌱', t('البداية','First Step'),          ach.totalDaysLogged >= 1),
      ('📅', t('أسبوع كامل','Week Warrior'),      ach.totalDaysLogged >= 7),
      ('🌙', t('صائم السنة','Sunnah Faster'),     fast.lifetimeCount >= 1),
      ('🏆', t('محارب السنة','Sunnah Warrior'),   fast.lifetimeCount >= 7),
      ('🍯', t('طعام نبوي','Sunnah Chef'),        ach.sunnahFoodsLogged >= 3),
      ('✨', t('الإخلاص','Mukhlis'),               ach.totalDaysLogged >= 30),
      ('💎', t('المجاهد','Al-Mujahid'),            ach.totalDaysLogged >= 100),
      ('🕌', t('النية','Niyyah Master'),
        ach.totalDaysLogged >= 28 && fast.lifetimeCount >= 4),
    ];
    final earned = badges.where((b) => b.$3).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🏅', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(t('إنجازاتك','Your Achievements'),
            style: TextStyle(fontFamily: 'Cairo',
              fontWeight: FontWeight.w800, fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF1F2A1F)))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.barakahGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$earned/${badges.length}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11,
                fontWeight: FontWeight.w700, color: AppColors.barakahGold)),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8,
          children: badges.map((b) => _badge(b.$1, b.$2, b.$3, muted)).toList()),
        if (!isPremium) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.push('/paywall'),
            child: Center(child: Text(
              t('⭐ ترقّ لفتح كل الإنجازات','⭐ Upgrade to unlock all badges'),
              style: const TextStyle(fontFamily: 'Cairo',
                fontSize: 11, color: AppColors.barakahGold))),
          ),
        ],
      ]),
    );
  }

  Widget _badge(String emoji, String label, bool earned, Color muted) =>
    AnimatedOpacity(
      opacity: earned ? 1.0 : 0.3,
      duration: const Duration(milliseconds: 400),
      child: Container(
        width: 74, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: earned
            ? AppColors.barakahGold.withOpacity(0.1)
            : const Color(0xFF1A1F26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: earned
              ? AppColors.barakahGold.withOpacity(0.45)
              : Colors.transparent)),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 3),
          Text(label,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 8,
              fontWeight: FontWeight.w600,
              color: earned ? AppColors.barakahGold : muted),
            textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis),
          if (earned) const Icon(Icons.check_circle_rounded,
            color: AppColors.barakahGold, size: 11),
        ]),
      ),
    );

  Widget _lifeStat(String emoji, String val, String label, Color col) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 3),
      Text(val, style: TextStyle(fontFamily: 'Cairo', fontSize: 14,
          fontWeight: FontWeight.w900, color: col)),
      Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 9,
          color: AppColors.lightMuted)),
    ]);
  }

  Widget _statCard(String emoji, String val, String label, Color bg) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.lightMuted)),
      ]),
    ));
  }

  Widget _bodyMini(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.lightMuted)),
    ]);
  }

  Widget _settingTile(String emoji, String title, String sub, VoidCallback onTap) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 20)),
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
      subtitle: sub.isNotEmpty ? Text(sub, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.lightMuted)) : null,
      trailing: const Icon(Icons.arrow_back_ios, size: 14, color: AppColors.lightMuted),
      onTap: onTap,
    );
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.waterBlue;
    if (bmi < 25)   return AppColors.halalGreen;
    if (bmi < 30)   return AppColors.doubtOrange;
    return AppColors.haramRed;
  }

  void _showCityPicker(BuildContext context, WidgetRef ref, bool isAr) {
    const cities = ['Cairo', 'Alexandria', 'Giza', 'Riyadh', 'Jeddah', 'Dubai', 'Abu Dhabi', 'Jakarta', 'Kuala Lumpur', 'Istanbul', 'London'];
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(16), children: [
      Text(isAr ? 'اختر مدينتك' : 'Choose Your City',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      ...cities.map((c) => ListTile(
        title: Text(c, style: TextStyle(fontFamily: 'Cairo',
          color: ref.read(cityProvider) == c ? AppColors.sunnahGreen : null,
          fontWeight: ref.read(cityProvider) == c ? FontWeight.w700 : FontWeight.w400)),
        trailing: ref.read(cityProvider) == c ? const Icon(Icons.check, color: AppColors.sunnahGreen) : null,
        onTap: () { ref.read(cityProvider.notifier).set(c); if (context.mounted) Navigator.pop(context); },
      )),
    ]));
  }

  void _showManageSubSheet(BuildContext context, bool isAr, String planName) {
    // planName: monthly | yearly | lifetime
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Padding(padding: const EdgeInsets.all(22), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('⭐', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(isAr ? 'إدارة اشتراكك' : 'Manage Your Subscription',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w800)),
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
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.lightMuted),
          ),
          const SizedBox(height: 20),
          if (planName != 'lifetime') ListTile(
            leading: const Text('📱', style: TextStyle(fontSize: 22)),
            title: Text(isAr ? 'إلغاء الاشتراك' : 'Cancel Subscription',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: AppColors.haramRed)),
            subtitle: Text(isAr ? 'من خلال App Store أو Google Play' : 'Via App Store or Google Play',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.lightMuted)),
            onTap: () {
              if (context.mounted) Navigator.pop(context);
              // Deep link to subscription management
              // iOS: 'https://apps.apple.com/account/subscriptions'
              // Android: 'https://play.google.com/store/account/subscriptions'
            },
          ),
          ListTile(
            leading: const Text('🔄', style: TextStyle(fontSize: 22)),
            title: Text(isAr ? 'استعادة المشتريات' : 'Restore Purchases',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
            onTap: () async {
              if (context.mounted) Navigator.pop(context);
              final result = await RevenueCatService.restore();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result.success
                  ? (isAr ? '✅ تم استعادة الاشتراك' : '✅ Subscription restored')
                  : (isAr ? 'لم يتم العثور على مشتريات' : 'No purchases found'),
                style: const TextStyle(fontFamily: 'Cairo')),
                backgroundColor: result.success ? AppColors.sunnahGreen : AppColors.haramRed,
              ));
            },
          ),
          const SizedBox(height: 8),
        ],
      )),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref, bool isAr) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(isAr ? 'تسجيل الخروج' : 'Sign Out', style: const TextStyle(fontFamily: 'Cairo')),
      content: Text(isAr ? 'هل أنت متأكد؟' : 'Are you sure?', style: const TextStyle(fontFamily: 'Cairo')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(fontFamily: 'Cairo'))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: Text(isAr ? 'خروج' : 'Sign Out',
            style: const TextStyle(fontFamily: 'Cairo', color: AppColors.haramRed))),
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

