// settings_screen.dart — HalalCalorie settings
import 'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:go_router/go_router.dart'; import'package:shared_preferences/shared_preferences.dart'; import'../../core/theme.dart'; import'../../core/providers.dart';
import '../../core/l10n.dart'; import'../../core/notifications.dart';
import '../../core/num_input.dart';
import '../../core/motion.dart';
import '../../core/fx.dart';
import '../../core/fx6.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  String get lang => ref.read(languageProvider);
  bool _notifWater   = true;
  bool _notifWorkout = true;
  bool _notifMeal    = true;

  @override
  void initState() {
    super.initState();
    _loadNotifPrefs();
  }

  Future<void> _loadNotifPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() { _notifWater   = p.getBool('notif_water')   ?? true; _notifWorkout = p.getBool('notif_workout')  ?? false; _notifMeal    = p.getBool('notif_meals') ?? p.getBool('notif_meal') ?? true;
    });
  }

  Future<void> _saveNotifPref(String key, bool val) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, val);
  }

  @override
  Widget build(BuildContext context) {
    final lang    = ref.watch(languageProvider);
    final isAr    = lang == 'ar';
    final isDark  = ref.watch(themeProvider);
    final isPrem  = ref.watch(premiumProvider);
    final ramadan = ref.watch(ramadanModeProvider);
    final notifsOn = ref.watch(notificationsEnabledProvider);

    final bg     = isDark ? AppColors.darkBg    : AppColors.lightBg;
    final card   = isDark ? const Color(0xFF0F1E18) : Colors.white;
    final text   = isDark ? AppColors.darkText  : AppColors.lightText;
    final muted  = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accent = ramadan ? AppColors.accentGold : AppColors.brandGreen;

    String t(String ar, String en) => tLang(lang, ar, en);

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Row(children: [
        Container(
          width: 4, height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.halalGreen, accent]),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            fontFamily: 'Aligarh', fontSize: 12, fontWeight: FontWeight.w800,
            letterSpacing: 1.3, color: muted)),
      ]),
    );

    Widget row({
      required IconData icon, required Color color, required String title,
      String? subtitle, Widget? trailing, VoidCallback? onTap,
      Color? titleColor, bool last = false,
    }) => Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            IconBadge(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(
                  fontFamily: 'Aligarh', fontWeight: FontWeight.w700,
                  fontSize: 14, color: titleColor ?? text)),
              if (subtitle != null && subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle, style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 11.5, color: muted)),
                ),
            ])),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ]),
        ),
      ),
      if (!last)
        Divider(height: 1, indent: 64, endIndent: 14, color: border),
    ]);

    Widget tog({
      required IconData icon, required Color color, required String title,
      String? subtitle, required bool value,
      required void Function(bool) onChanged, bool last = false,
    }) => row(
      icon: icon, color: color, title: title, subtitle: subtitle, last: last,
      trailing: PillSwitch(value: value, onChanged: onChanged, color: accent),
      onTap: () => onChanged(!value),
    );

    Widget chev() => Icon(Icons.chevron_right_rounded, size: 22, color: muted);
    Widget ext()  => Icon(Icons.open_in_new_rounded, size: 16, color: muted);

    int gi = 2;
    Widget group(List<Widget> rows) => Reveal(
      index: gi++,
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: 0.6),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
            blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: rows),
          ),
        ),
      ),
    );

    final macro = ref.watch(macroPlanProvider);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(children: [
          Positioned.fill(
            child: AuroraBackground(
              base: bg,
              colors: [accent, AppColors.accentGold, const Color(0xFF0E6B6B)],
              intensity: isDark ? 0.55 : 0.32,
              seconds: 22,
            ),
          ),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Reveal(
                  index: 0,
                  child: Row(children: [
                    GlassIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      isDark: isDark,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 14),
                    Text(t('الإعدادات', 'Settings'), style: TextStyle(
                        fontFamily: 'Aligarh', fontSize: 26,
                        fontWeight: FontWeight.w900, color: text)),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Premium banner ─────────────────────────────
                Reveal(
                  index: 1,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: isPrem
                            ? const [Color(0xFF3A2A0A), Color(0xFF1B1405)]
                            : const [Color(0xFF0E3B26), Color(0xFF07160F)],
                      ),
                      border: Border.all(
                          color: AppColors.accentGold.withOpacity(0.45),
                          width: 0.9),
                      boxShadow: [BoxShadow(
                          color: AppColors.accentGold.withOpacity(0.18),
                          blurRadius: 26, offset: const Offset(0, 10))],
                    ),
                    child: Column(children: [
                      Row(children: [
                        const BrandMark(size: 46),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text(
                            isPrem
                                ? t('عضو بريميوم', 'Premium member')
                                : t('افتح كل شيء', 'Unlock everything'),
                            style: const TextStyle(
                                fontFamily: 'Aligarh', fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF0CF98))),
                          const SizedBox(height: 3),
                          Text(
                            isPrem
                                ? t('شكراً لدعمك — كل الميزات مفتوحة',
                                    'Thank you — every feature is unlocked')
                                : t('مدرّب AI • مخطط وجبات • رؤى • ماسحات بلا حدود',
                                    'AI coach • meal planner • insights • unlimited scans'),
                            style: const TextStyle(
                                fontFamily: 'Aligarh', fontSize: 12,
                                height: 1.4, color: Colors.white70)),
                        ])),
                        if (isPrem)
                          const Icon(Icons.verified_rounded,
                              color: AppColors.halalGreen, size: 26),
                      ]),
                      if (!isPrem) ...[
                        const SizedBox(height: 14),
                        ShineButton(
                          label: t('ترقية الآن', 'Upgrade now'),
                          icon: Icons.workspace_premium_rounded,
                          height: 50,
                          onPressed: () => context.push('/paywall'),
                        ),
                      ],
                    ]),
                  ),
                ),

                // ── APPEARANCE ─────────────────────────────────
// PATCH_V58_STUDIO_LINK
                GestureDetector(
                  onTap: () => context.push('/premium'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.accentGold.withOpacity(0.45), width: 0.8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.workspace_premium_rounded, color: AppColors.accentGold, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t('استوديو بريميوم — مدرّب • مخطط وجبات • رؤى • صيام', 'Premium Studio — coach • meal planner • insights • fasting'),
                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 13.5,
                              fontWeight: FontWeight.w800, color: text))),
                      Icon(Icons.chevron_right_rounded, color: muted),
                    ]),
                  ),
                ),
                section(t('المظهر', 'APPEARANCE')),
                group([
                  tog(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: isDark ? const Color(0xFF7F8CFF) : AppColors.accentGold,
                    title: isDark ? t('الوضع الليلي', 'Dark mode')
                                  : t('الوضع النهاري', 'Light mode'),
                    subtitle: isDark ? t('تبديل للضوء', 'Switch to light')
                                     : t('تبديل للظلام', 'Switch to dark'),
                    value: isDark,
                    onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                  ),
                  row(
                    icon: Icons.translate_rounded, color: AppColors.waterBlue,
                    title: t('اللغة', 'Language'),
                    subtitle: _langLabel(lang),
                    trailing: Icon(Icons.expand_more_rounded, size: 22, color: muted),
                    onTap: () => _showLangPicker(context),
                  ),
                  row(
                    icon: Icons.donut_large_rounded, color: AppColors.halalGreen,
                    title: t('خطة الماكرو', 'Macro plan'),
                    subtitle: isAr ? macro.nameAr() : macro.nameEn(),
                    trailing: Icon(Icons.expand_more_rounded, size: 22, color: muted),
                    onTap: () => _showMacroPicker(context),
                    last: true,
                  ),
                ]),

                // ── RAMADAN ────────────────────────────────────
                section(t('رمضان المبارك', 'RAMADAN')),
                group([
                  tog(
                    icon: Icons.nights_stay_rounded, color: AppColors.accentGold,
                    title: t('وضع رمضان', 'Ramadan mode'),
                    subtitle: t('يُعدّل التمارين والتغذية للصائم',
                                'Adjusts workouts & nutrition for fasting'),
                    value: ramadan, last: !ramadan,
                    onChanged: (_) => ref.read(ramadanModeProvider.notifier).toggle(),
                  ),
                  if (ramadan)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.accentGold.withOpacity(0.4)),
                        ),
                        child: Text(
                          t('وضع رمضان فعّال — تمارين خفيفة أولاً • وصفات مناسبة للصائم • لافتة رمضان في الرئيسية',
                            'Ramadan mode active — light workouts first • fasting-friendly recipes • Ramadan banner on home'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11.5,
                              color: AppColors.accentGold, height: 1.5),
                        ),
                      ),
                    ),
                ]),

                // ── NOTIFICATIONS ──────────────────────────────
                section(t('الإشعارات', 'NOTIFICATIONS')),
// PATCH_V58_NOTIF_LINK
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.accentGold.withOpacity(0.45), width: 0.8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.notifications_active_rounded, color: AppColors.accentGold, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t('مركز الإشعارات — اختبار وإصلاح وتذكيرات ذكية', 'Notification Center — test, fix & smart reminders'),
                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 13.5,
                              fontWeight: FontWeight.w800, color: text))),
                      Icon(Icons.chevron_right_rounded, color: muted),
                    ]),
                  ),
                ),
                group([
                  tog(
                    icon: Icons.notifications_rounded, color: AppColors.doubtOrange,
                    title: t('تفعيل الإشعارات', 'Enable notifications'),
                    subtitle: t('ذكريات الماء والتمرين والوجبات',
                                'Water, workout & meal reminders'),
                    value: notifsOn, last: !notifsOn,
                    onChanged: (v) async {
                      await ref.read(notificationsEnabledProvider.notifier).toggle();
                      try {
                        if (v) {
                          await NotificationService.requestPermissions();
                          await NotificationService.rescheduleAll(isAr: isAr);
                        } else {
                          await NotificationService.cancelAll();
                        }
                      } catch (_) {}
                    },
                  ),
                  if (notifsOn) ...[
                    tog(
                      icon: Icons.water_drop_rounded, color: AppColors.waterBlue,
                      title: t('تذكير الماء', 'Water reminder'),
                      subtitle: t('كل ساعتين', 'Every 2 hours'),
                      value: _notifWater,
                      onChanged: (v) async {
                        setState(() => _notifWater = v);
                        await _saveNotifPref('notif_water', v);
                        try { await NotificationService.scheduleWaterReminder(isAr: isAr); } catch (_) {}
                      },
                    ),
                    tog(
                      icon: Icons.fitness_center_rounded, color: AppColors.halalGreen,
                      title: t('تذكير التمرين', 'Workout reminder'),
                      subtitle: t('يومياً ٥:٣٠ م', 'Daily at 5:30 PM'),
                      value: _notifWorkout,
                      onChanged: (v) async {
                        setState(() => _notifWorkout = v);
                        await _saveNotifPref('notif_workout', v);
                        try { await NotificationService.scheduleWorkoutReminder(isAr: isAr); } catch (_) {}
                      },
                    ),
                    tog(
                      icon: Icons.restaurant_rounded, color: AppColors.accentGold,
                      title: t('تذكير الوجبة', 'Meal reminder'),
                      subtitle: t('ثلاث مرات يومياً', 'Three times daily'),
                      value: _notifMeal, last: false,
                      onChanged: (v) async {
                        setState(() => _notifMeal = v);
                        await _saveNotifPref('notif_meals', v);
                        try { await NotificationService.scheduleMealReminder(isAr: isAr); } catch (_) {}
                      },
                    ),
                    row(
                      icon: Icons.tune_rounded, color: muted,
                      title: t('إعدادات متقدمة', 'More options'),
                      trailing: chev(), last: true,
                      onTap: () => _showNotifSettings(context),
                    ),
                  ],
                ]),

                // ── HEALTH GOALS ───────────────────────────────
                section(t('الأهداف الصحية', 'HEALTH GOALS')),
                group([
                  row(
                    icon: Icons.water_drop_rounded, color: AppColors.waterBlue,
                    title: t('هدف الماء اليومي', 'Daily water goal'),
                    subtitle: '${ref.watch(waterProvider).goal} ${t("كوب", "cups")}',
                    trailing: chev(),
                    onTap: () => _editWaterGoal(context, isAr),
                  ),
                  row(
                    icon: Icons.bedtime_rounded, color: AppColors.sleepPurple,
                    title: t('هدف النوم', 'Sleep goal'),
                    subtitle: '${ref.watch(sleepProvider).goal.toStringAsFixed(1)} ${t("ساعة", "hrs")}',
                    trailing: chev(), last: true,
                    onTap: () => _editSleepGoal(context, isAr),
                  ),
                ]),

                // ── DATA ───────────────────────────────────────
                section(t('البيانات', 'DATA')),
                group([
                  row(
                    icon: Icons.edit_rounded, color: AppColors.halalGreen,
                    title: t('تعديل ملفي الشخصي', 'Edit my profile'),
                    subtitle: t('الطول، الوزن، العمر، الهدف', 'Height, weight, age, goal'),
                    trailing: chev(),
                    onTap: () { context.pop(); context.go('/body'); },
                  ),
                  row(
                    icon: Icons.delete_outline_rounded, color: AppColors.haramRed,
                    title: t('مسح سجل اليوم', "Clear today's data"),
                    subtitle: t('الوجبات والخطوات والماء', 'Meals, steps, water'),
                    titleColor: AppColors.haramRed, trailing: chev(), last: true,
                    onTap: () => _confirmClearDay(context, isAr),
                  ),
                ]),

                // ── ABOUT ──────────────────────────────────────
                section(t('حول التطبيق', 'ABOUT')),
                group([
                  row(
                    icon: Icons.info_outline_rounded, color: AppColors.waterBlue,
                    title: t('إصدار التطبيق', 'App version'),
                    subtitle: 'HalalCalorie ${ref.watch(appVersionProvider).maybeWhen(
                        data: (v) => v, orElse: () => '')}'.trim(),
                  ),
                  row(
                    icon: Icons.lock_outline_rounded, color: AppColors.halalGreen,
                    title: t('سياسة الخصوصية', 'Privacy policy'),
                    subtitle: t('بياناتك خاصة — لا نبيعها أبداً',
                                'Your data is private — we never sell it'),
                    trailing: ext(),
                  ),
                  row(
                    icon: Icons.star_rounded, color: AppColors.accentGold,
                    title: t('تقييم التطبيق', 'Rate the app'),
                    subtitle: t('يساعدنا تقييم 5 نجوم كثيراً', 'A 5-star review helps us a lot'),
                    trailing: ext(), last: true,
                  ),
                ]),

                const SizedBox(height: 30),
                Center(child: Column(children: [
                  BrandMark(size: 36, color: muted.withOpacity(0.7)),
                  const SizedBox(height: 10),
                  Text(
                    t('صُنع بعناية — بياناتك تبقى على جهازك',
                      'Made with care — your data stays on your device'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                        color: muted, height: 1.8),
                  ),
                ])),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Language helpers ──────────────────────────────────
  static const _kLangs = [
    ('ar', '🇸🇦', 'العربية',  'Arabic'),
    ('en', '🇬🇧', 'English',  'English'),
    ('fr', '🇫🇷', 'Français', 'French'),
    ('tr', '🇹🇷', 'Türkçe',   'Turkish'),
    ('ur', '🇵🇰', 'اردو',     'Urdu'),
    ('ms', '🇲🇾', 'Bahasa Melayu',    'Malay'),
    ('id', '🇮🇩', 'Bahasa Indonesia', 'Indonesian'),
  ];

  String _langLabel(String code) {
    for (final (c, flag, name, _) in _kLangs) {
      if (c == code) return '$flag  $name';
    }
    return '🌐  English';
  }

  // ── Notification settings ──────────────────────────────
  void _showNotifSettings(BuildContext context) {
    final isDark = ref.read(themeProvider);
    final isAr   = ref.read(languageProvider) == 'ar';
    final bg   = isDark ? AppColors.darkCard  : Colors.white;
    final text = isDark ? AppColors.darkText  : AppColors.lightText;
    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightMuted.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(tLang(lang, '🔔 إعدادات الإشعارات', '🔔 Notification Settings', '🔔 Paramètres de notification', '🔔 Bildirim Ayarları', '🔔 Tetapan Pemberitahuan', '🔔 Pengaturan Notifikasi'),
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 16,
                    fontWeight: FontWeight.w800, color: text)),
                const SizedBox(height: 16),
                _NotifToggle(
                  label: tLang(lang, '💧 تذكير الماء', '💧 Water reminder', '💧 Rappel eau', '💧 Su hatırlatıcısı', '💧 Peringatan air', '💧 Pengingat air'),
                  sub:   tLang(lang, 'كل ساعتين 8ص–10م', 'Every 2h 8am–10pm', 'Toutes les 2h 8h–22h', 'Her 2 saatte 8:00–22:00', 'Setiap 2j 8pg–10mlm', 'Setiap 2j pukul 8–22'),
                  prefKey: 'notif_water',
                  isDark: isDark,
                  onChange: (v) async {
                    setS(() {});
                    await NotificationService.scheduleWaterReminder(isAr: isAr);
                  },
                ),
                _NotifToggle(
                  label: tLang(lang, '🍽️ تذكير الوجبات', '🍽️ Meal reminders', '🍽️ Rappels de repas', '🍽️ Öğün hatırlatıcıları', '🍽️ Peringatan makanan', '🍽️ Pengingat makan'),
                  sub:   tLang(lang, 'الإفطار 7:30 • الغداء 1:00 • العشاء 7:30م', 'Breakfast 7:30 • Lunch 1:00 • Dinner 7:30pm', 'Breakfast 7:30 • Lunch 1:00 • Dinner 7:30pm', 'Breakfast 7:30 • Lunch 1:00 • Dinner 7:30pm', 'Breakfast 7:30 • Lunch 1:00 • Dinner 7:30pm', 'Breakfast 7:30 • Lunch 1:00 • Dinner 7:30pm'),
                  prefKey: 'notif_meals',
                  isDark: isDark,
                  onChange: (v) async {
                    setS(() {});
                    await NotificationService.scheduleMealReminder(isAr: isAr);
                  },
                ),
                _NotifToggle(
                  label: tLang(lang, '💪 تذكير الرياضة', '💪 Workout reminder', '💪 Rappel entraînement', '💪 Antrenman hatırlatıcısı', '💪 Peringatan senaman', '💪 Pengingat olahraga'),
                  sub:   tLang(lang, 'كل يوم 5:30م', 'Daily at 5:30pm', 'Quotidien à 17h30', 'Her gün 17:30\'da', 'Harian pada 5:30ptg', 'Harian pukul 17:30'),
                  prefKey: 'notif_workout',
                  isDark: isDark,
                  onChange: (v) async {
                    setS(() {});
                    await NotificationService.scheduleWorkoutReminder(isAr: isAr);
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                  child: Text(tLang(lang, 'حفظ', 'Save', 'Enregistrer', 'Kaydet', 'Simpan', 'Simpan'),
                    style: const TextStyle(fontFamily: 'Aligarh',
                        color: Colors.white, fontWeight: FontWeight.w700)),
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _showMacroPicker(BuildContext context) {
    final isDark  = ref.read(themeProvider);
    final isAr    = ref.read(languageProvider) == 'ar';
    final current = ref.read(macroPlanProvider);
    final bg   = isDark ? AppColors.darkCard : Colors.white;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(tLang(lang, 'خطط الماكرو', 'Macro Plans', 'Plans macro', 'Makro Planlar', 'Pelan Makro', 'Rencana Makro'),
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 16,
                fontWeight: FontWeight.w800, color: text)),
            const SizedBox(height: 8),
            ...MacroPlan.values.map((p) {
              final sel = p == current;
              return ListTile(
                leading: EmojiIcon(p.emoji(), size: 24),
                title: Text(isAr ? p.nameAr() : p.nameEn(),
                  style: TextStyle(fontFamily: 'Aligarh',
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                    color: sel ? AppColors.brandGreen : text)),
                subtitle: Text(
                  'P:${p.proteinPct}%  C:${p.carbsPct}%  F:${p.fatPct}%',
                  style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                      color: AppColors.lightMuted)),
                trailing: sel
                  ? const Icon(Icons.check_circle,
                      color: AppColors.brandGreen, size: 22)
                  : null,
                onTap: () {
                  ref.read(macroPlanProvider.notifier).set(p);
                  Navigator.pop(context);
                  setState(() {});
                },
              );
            }),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  void _showLangPicker(BuildContext context) {
    final isDark = ref.read(themeProvider);
    final current = ref.read(languageProvider);
    final bg   = isDark ? AppColors.darkCard  : Colors.white;
    final text = isDark ? AppColors.darkText  : AppColors.lightText;
    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollCtrl) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('🌐  Language / اللغة',
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 16,
                fontWeight: FontWeight.w800, color: text)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                children: _kLangs.map((l) {
              final (code, flag, name, sub) = l;
              final sel = current == code;
              return ListTile(
                leading: Text(flag, style: const TextStyle(fontSize: 24)),
                title: Text(name, style: TextStyle(fontFamily: 'Aligarh',
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                  color: sel ? AppColors.brandGreen : text)),
                subtitle: Text(sub, style: TextStyle(
                  fontFamily: 'Aligarh', fontSize: 11,
                  color: AppColors.lightMuted)),
                trailing: sel
                  ? const Icon(Icons.check_circle,
                      color: AppColors.brandGreen, size: 22)
                  : null,
                onTap: () {
                  ref.read(languageProvider.notifier).set(code);
                  Navigator.pop(context);
                  setState(() {});
                },
              );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    ));
  }

  void _editWaterGoal(BuildContext context, bool isAr) {
    final ctrl = TextEditingController( text:'${ref.read(waterProvider).goal}');
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(tLang(lang, 'هدف الماء اليومي', 'Daily Water Goal', 'Objectif eau quotidien', 'Günlük Su Hedefi', 'Sasaran Air Harian', 'Target Air Harian'), style: const TextStyle(fontFamily:'Aligarh')),
      content: TextField(
        controller: ctrl, keyboardType: TextInputType.number,
        decoration: InputDecoration( hintText: tLang(lang, 'عدد الأكواب', 'Number of cups', 'Number of cups', 'Number of cups', 'Number of cups', 'Number of cups'), suffixText: tLang(lang, 'كوب', 'cups', 'verres', 'bardak', 'cawan', 'gelas'),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () { if (context.mounted) Navigator.pop(context); }, child: Text(tLang(lang, 'إلغاء', 'Cancel', 'Annuler', 'İptal', 'Batal', 'Batal'), style: const TextStyle(fontFamily:'Aligarh'))),
        ElevatedButton(
          onPressed: () {
            final n = parseInt(ctrl.text.trim()) ?? 8;
            ref.read(waterProvider.notifier).setGoal(n.clamp(4, 20));
            if (context.mounted) Navigator.pop(context);
          }, child: Text(tLang(lang, 'حفظ', 'Save', 'Enregistrer', 'Kaydet', 'Simpan', 'Simpan'), style: const TextStyle(fontFamily:'Aligarh')),
        ),
      ],
    ));
  }

  void _editSleepGoal(BuildContext context, bool isAr) {
    final ctrl = TextEditingController(
        text: ref.read(sleepProvider).goal.toStringAsFixed(1));
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(tLang(lang, 'هدف النوم', 'Sleep Goal', 'Objectif sommeil', 'Uyku Hedefi', 'Sasaran Tidur', 'Target Tidur'), style: const TextStyle(fontFamily:'Aligarh')),
      content: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration( hintText: tLang(lang, 'عدد الساعات', 'Number of hours', 'Number of hours', 'Number of hours', 'Number of hours', 'Number of hours'), suffixText: tLang(lang, 'ساعة', 'hrs', 'h', 'sa', 'jam', 'jam'),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () { if (context.mounted) Navigator.pop(context); }, child: Text(tLang(lang, 'إلغاء', 'Cancel', 'Annuler', 'İptal', 'Batal', 'Batal'), style: const TextStyle(fontFamily:'Aligarh'))),
        ElevatedButton(
          onPressed: () { final h = parseDouble(ctrl.text.trim().replaceAll(',', '.')) ?? 8.0;
            ref.read(sleepProvider.notifier).setGoal(h.clamp(4.0, 12.0));
            if (context.mounted) Navigator.pop(context);
          }, child: Text(tLang(lang, 'حفظ', 'Save', 'Enregistrer', 'Kaydet', 'Simpan', 'Simpan'), style: const TextStyle(fontFamily:'Aligarh')),
        ),
      ],
    ));
  }

  void _confirmClearDay(BuildContext context, bool isAr) {
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(tLang(lang, 'مسح سجل اليوم؟', 'Clear Today Log?', 'Effacer le journal?', 'Bugünkü Veriyi Sil?', 'Padam Log Hari Ini?', 'Hapus Log Hari Ini?'), style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w700)),
      content: Text(
        tLang(lang, 'سيُمسح سجل الوجبات والخطوات والماء لليوم فقط. لا يمكن التراجع.', 'Today\'s meals, steps, and water will be cleared. Cannot be undone.', 'Les repas, étapes et eau d\'aujourd\'hui seront effacés. Irréversible.', 'Bugünün öğünleri, adımları ve suyu silinecek. Geri alınamaz.', 'Makanan, langkah dan air hari ini akan dipadam. Tidak boleh dibatalkan.', 'Makanan, langkah dan air hari ini akan dihapus. Tidak dapat dibatalkan.'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 13, height: 1.5)),
      actions: [
        TextButton(onPressed: () { if (context.mounted) Navigator.pop(context); }, child: Text(tLang(lang, 'إلغاء', 'Cancel', 'Annuler', 'İptal', 'Batal', 'Batal'), style: const TextStyle(fontFamily:'Aligarh'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.haramRed),
          onPressed: () async {
            if (context.mounted) Navigator.pop(context);
            await ref.read(waterProvider.notifier).set(0);
            await ref.read(healthProvider.notifier).setSteps(0);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text(tLang(lang, '✅ تم مسح سجل اليوم', '✅ Today log cleared', '✅ Journal effacé', '✅ Bugün temizlendi', '✅ Log hari ini dipadam', '✅ Log hari ini dihapus'), style: const TextStyle(fontFamily:'Aligarh')),
                backgroundColor: AppColors.brandGreen,
              ));
            }
          }, child: Text(tLang(lang, 'مسح', 'Clear', 'Effacer', 'Temizle', 'Padam', 'Hapus'), style: const TextStyle(fontFamily:'Aligarh', color: Colors.white)),
        ),
      ],
    ));
  }
}

class _NotifToggle extends StatefulWidget {
  final String label;
  final String sub;
  final String prefKey;
  final bool isDark;
  final Future<void> Function(bool) onChange;
  const _NotifToggle({required this.label, required this.sub,
    required this.prefKey, required this.isDark, required this.onChange});
  @override
  State<_NotifToggle> createState() => _NotifToggleState();
}

class _NotifToggleState extends State<_NotifToggle> {
  bool _value = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _value = p.getBool(widget.prefKey) ?? true);
  }
  Future<void> _toggle(bool v) async {
    setState(() => _value = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(widget.prefKey, v);
    await widget.onChange(v);
  }
  @override
  Widget build(BuildContext context) {
    final text  = widget.isDark ? AppColors.darkText  : AppColors.lightText;
    final muted = widget.isDark ? AppColors.darkMuted : AppColors.lightMuted;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.label, style: TextStyle(fontFamily: 'Aligarh',
          fontWeight: FontWeight.w600, fontSize: 14, color: text)),
      subtitle: Text(widget.sub, style: TextStyle(fontFamily: 'Aligarh',
          fontSize: 11, color: muted)),
      trailing: Switch(value: _value, onChanged: _toggle,
          activeColor: AppColors.brandGreen),
      onTap: () => _toggle(!_value),
    );
  }
}

