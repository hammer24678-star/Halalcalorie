// settings_screen.dart — HalalCalorie v1.0
import 'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:go_router/go_router.dart'; import'package:shared_preferences/shared_preferences.dart'; import'../../core/theme.dart'; import'../../core/providers.dart';
import '../../core/l10n.dart'; import'../../core/notifications.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
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
    setState(() { _notifWater   = p.getBool('notif_water')   ?? true; _notifWorkout = p.getBool('notif_workout')  ?? true; _notifMeal    = p.getBool('notif_meal')     ?? true;
    });
  }

  Future<void> _saveNotifPref(String key, bool val) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, val);
  }

  @override
  Widget build(BuildContext context) { final isAr    = ref.watch(languageProvider) =='ar';
    final isDark  = ref.watch(themeProvider);
    final isPrem  = ref.watch(premiumProvider);
    final ramadan = ref.watch(ramadanModeProvider);
    final notifsOn = ref.watch(notificationsEnabledProvider);

    final bg     = isDark ? AppColors.darkBg    : AppColors.lightBg;
    final card   = isDark ? AppColors.darkCard  : Colors.white;
    final text   = isDark ? AppColors.darkText  : AppColors.lightText;
    final muted  = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final lang   = ref.watch(languageProvider);

    String t(String ar, String en) => tLang(lang, ar, en);

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.sunnahGreen, letterSpacing: 1.4)),
    );

    Widget tile({
      required String emoji, required String title, String? subtitle,
      Widget? trailing, VoidCallback? onTap, Color? titleColor,
    }) => Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(color: card,
          border: Border(bottom: BorderSide(color: border, width: 0.5))),
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 22)), title: Text(title, style: TextStyle(fontFamily:'Cairo',
            fontWeight: FontWeight.w600, fontSize: 14,
            color: titleColor ?? text)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontFamily:'Cairo', fontSize: 11, color: muted))
            : null,
        trailing: trailing,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );

    Widget tog({
      required String emoji, required String title, String? subtitle,
      required bool value, required void Function(bool) onChanged,
    }) => tile(
      emoji: emoji, title: title, subtitle: subtitle,
      trailing: Switch(
        value: value, onChanged: onChanged,
        activeColor: ramadan ? AppColors.barakahGold : AppColors.sunnahGreen,
      ),
      onTap: () => onChanged(!value),
    );

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar( title: Text(t('الإعدادات ⚙️', 'Settings ⚙️'), style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w800)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [

            // ── APPEARANCE ─────────────────────────────────── section(t('المظهر', 'APPEARANCE')),
            tog( emoji: isDark ?'☀️' : '🌙', title: isDark ? t('الوضع النهاري', 'Light Mode') : t('الوضع الليلي', 'Dark Mode'), subtitle: isDark ? t('تبديل للضوء', 'Switch to light') : t('تبديل للظلام', 'Switch to dark'),
              value: isDark,
              onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
            ),
            tile(
              emoji: '🔔',
              title: t('الإشعارات', 'Notifications'),
              subtitle: t('وجبات • ماء • رياضة', 'Meals • Water • Workout'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _showNotifSettings(context),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              title: Text(t('اللغة', 'Language'),
                  style: TextStyle(fontFamily: 'Cairo',
                      fontWeight: FontWeight.w600, fontSize: 14,
                      color: text)),
              subtitle: Text(_langLabel(ref.watch(languageProvider)),
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
                      color: muted)),
              trailing: const Icon(Icons.expand_more, size: 20),
              onTap: () => _showLangPicker(context),
            ),

            const Divider(height: 1, indent: 56),
            ListTile(
              leading: Text(
                ref.watch(macroPlanProvider).emoji(),
                style: const TextStyle(fontSize: 22)),
              title: Text(t('خطة الماكرو', 'Macro Plan'),
                  style: TextStyle(fontFamily: 'Cairo',
                      fontWeight: FontWeight.w600, fontSize: 14,
                      color: text)),
              subtitle: Text(
                isAr ? ref.watch(macroPlanProvider).nameAr()
                     : ref.watch(macroPlanProvider).nameEn(),
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
                    color: AppColors.sunnahGreen)),
              trailing: const Icon(Icons.expand_more, size: 20),
              onTap: () => _showMacroPicker(context),
            ),

            // ── RAMADAN ────────────────────────────────────── section(t('رمضان المبارك 🌙', 'RAMADAN 🌙')),
            tog( emoji:'🌙', title: t('وضع رمضان', 'Ramadan Mode'), subtitle: t('يُعدّل التمارين والتغذية للصائم', 'Adjusts workouts & nutrition for fasting'),
              value: ramadan,
              onChanged: (_) => ref.read(ramadanModeProvider.notifier).toggle(),
            ),
            if (ramadan)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.barakahGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.barakahGold.withOpacity(0.4)),
                ),
                child: Text( t('وضع رمضان فعّال — تمارين خفيفة أولاً • وصفات مناسبة للصائم • لافتة رمضان في الرئيسية', 'Ramadan mode active — light workouts first • fasting-friendly recipes • Ramadan banner on home'), style: const TextStyle(fontFamily:'Cairo', fontSize: 11,
                      color: AppColors.barakahGold, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── NOTIFICATIONS ──────────────────────────────── section(t('الإشعارات 🔔', 'NOTIFICATIONS 🔔')),
            tog( emoji:'🔔', title: t('تفعيل الإشعارات', 'Enable Notifications'), subtitle: t('ذكريات الماء والتمرين والوجبات', 'Water, workout & meal reminders'),
              value: notifsOn,
              onChanged: (v) {
                ref.watch(notificationsEnabledProvider.notifier).toggle();
                if (v) NotificationService.requestPermissions();
              },
            ),
            if (notifsOn) ...[
              tog( emoji:'💧', title: t('تذكير الماء', 'Water Reminder'), subtitle: t('كل ساعتين', 'Every 2 hours'),
                value: _notifWater,
                onChanged: (v) {
                  setState(() => _notifWater = v); _saveNotifPref('notif_water', v);
                },
              ),
              tog( emoji:'🏃', title: t('تذكير التمرين', 'Workout Reminder'), subtitle: t('يومياً في الصباح', 'Daily morning'),
                value: _notifWorkout,
                onChanged: (v) {
                  setState(() => _notifWorkout = v); _saveNotifPref('notif_workout', v);
                },
              ),
              tog( emoji:'🌿', title: t('تذكير الوجبة', 'Meal Reminder'), subtitle: t('ثلاث مرات يومياً', 'Three times daily'),
                value: _notifMeal,
                onChanged: (v) {
                  setState(() => _notifMeal = v); _saveNotifPref('notif_meal', v);
                },
              ),
            ],

            // ── HEALTH GOALS ────────────────────────────────── section(t('الأهداف الصحية 🎯', 'HEALTH GOALS 🎯')),
            tile( emoji:'💧', title: t('هدف الماء اليومي', 'Daily Water Goal'), subtitle:'${ref.watch(waterProvider).goal} ${t("كوب", "cups")}',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editWaterGoal(context, isAr),
            ),
            tile( emoji:'😴', title: t('هدف النوم', 'Sleep Goal'), subtitle:'${ref.watch(sleepProvider).goal.toStringAsFixed(1)} ${t("ساعة", "hrs")}',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editSleepGoal(context, isAr),
            ),

            // ── SUBSCRIPTION ────────────────────────────────── section(t('الاشتراك ⭐', 'SUBSCRIPTION ⭐')),
            if (!isPrem)
              tile( emoji:'🔓', title: t('ترقية للبريميوم', 'Upgrade to Premium'), subtitle: t('افتح 10+ تمارين متقدمة وتحليل AI بلا حدود', 'Unlock 10+ advanced workouts & unlimited AI analysis'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.barakahGold,
                    borderRadius: BorderRadius.circular(20),
                  ), child: Text(t('ترقية', 'Upgrade'), style: const TextStyle(fontFamily:'Cairo',
                          fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                ), onTap: () => context.push('/paywall'),
              )
            else
              tile( emoji:'⭐', title: t('عضو بريميوم', 'Premium Member'), subtitle: t('شكراً لدعمك! — كل الميزات مفتوحة', 'Thank you! — All features unlocked'),
                titleColor: AppColors.barakahGold,
                trailing: const Icon(Icons.check_circle, color: AppColors.halalGreen),
              ),

            // ── DATA ────────────────────────────────────────── section(t('البيانات 🗂️', 'DATA 🗂️')),
            tile( emoji:'✏️', title: t('تعديل ملفي الشخصي', 'Edit My Profile'), subtitle: t('الطول، الوزن، العمر، الهدف', 'Height, weight, age, goal'),
              trailing: const Icon(Icons.chevron_right), onTap: () { context.pop(); context.go('/body'); },
            ),
            tile( emoji:'🗑️', title: t('مسح سجل اليوم', 'Clear Todays Data'), subtitle: t('الوجبات والخطوات والماء', 'Meals, steps, water'),
              trailing: const Icon(Icons.chevron_right),
              titleColor: AppColors.haramRed,
              onTap: () => _confirmClearDay(context, isAr),
            ),

            // ── ABOUT ───────────────────────────────────────── section(t('حول التطبيق', 'ABOUT')),
            tile( emoji:'ℹ️', title: t('إصدار التطبيق', 'App Version'), subtitle:'HalalCalorie v1.0.0',
            ),
            tile( emoji:'🔒', title: t('سياسة الخصوصية', 'Privacy Policy'), subtitle: t('بياناتك خاصة — لا نبيعها أبداً', 'Your data is private — we never sell it'),
              trailing: const Icon(Icons.open_in_new, size: 16),
            ),
            tile( emoji:'⭐', title: t('تقييم التطبيق', 'Rate the App'), subtitle: t('يساعدنا تقييم 5 نجوم كثيراً ❤️', 'A 5-star review helps us a lot ❤️'),
              trailing: const Icon(Icons.open_in_new, size: 16),
            ),

            const SizedBox(height: 32),
            Center(child: Column(children: [ const Text('🕌', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text( t('بسم الله الرحمن الرحيم\nصُنع بحب للمسلمين ❤️', 'Bismillah Al-Rahman Al-Raheem\nMade with love for Muslims ❤️'),
                textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 12,
                    color: muted, height: 1.8),
              ),
            ])),
            const SizedBox(height: 30),
          ],
        ),
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
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
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
                    backgroundColor: AppColors.sunnahGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                  child: Text(tLang(lang, 'حفظ', 'Save', 'Enregistrer', 'Kaydet', 'Simpan', 'Simpan'),
                    style: const TextStyle(fontFamily: 'Cairo',
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
              style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
                fontWeight: FontWeight.w800, color: text)),
            const SizedBox(height: 8),
            ...MacroPlan.values.map((p) {
              final sel = p == current;
              return ListTile(
                leading: Text(p.emoji(), style: const TextStyle(fontSize: 24)),
                title: Text(isAr ? p.nameAr() : p.nameEn(),
                  style: TextStyle(fontFamily: 'Cairo',
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                    color: sel ? AppColors.sunnahGreen : text)),
                subtitle: Text(
                  'P:${p.proteinPct}%  C:${p.carbsPct}%  F:${p.fatPct}%',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11,
                      color: AppColors.lightMuted)),
                trailing: sel
                  ? const Icon(Icons.check_circle,
                      color: AppColors.sunnahGreen, size: 22)
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
            Text('🌐  Language / اللغة',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
                fontWeight: FontWeight.w800, color: text)),
            const SizedBox(height: 16),
            ..._kLangs.map((l) {
              final (code, flag, name, sub) = l;
              final sel = current == code;
              return ListTile(
                leading: Text(flag, style: const TextStyle(fontSize: 24)),
                title: Text(name, style: TextStyle(fontFamily: 'Cairo',
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                  color: sel ? AppColors.sunnahGreen : text)),
                subtitle: Text(sub, style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 11,
                  color: AppColors.lightMuted)),
                trailing: sel
                  ? const Icon(Icons.check_circle,
                      color: AppColors.sunnahGreen, size: 22)
                  : null,
                onTap: () {
                  ref.read(languageProvider.notifier).set(code);
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

  void _editWaterGoal(BuildContext context, bool isAr) {
    final ctrl = TextEditingController( text:'${ref.read(waterProvider).goal}');
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(tLang(lang, 'هدف الماء اليومي', 'Daily Water Goal', 'Objectif eau quotidien', 'Günlük Su Hedefi', 'Sasaran Air Harian', 'Target Air Harian'), style: const TextStyle(fontFamily:'Cairo')),
      content: TextField(
        controller: ctrl, keyboardType: TextInputType.number,
        decoration: InputDecoration( hintText: tLang(lang, 'عدد الأكواب', 'Number of cups', 'Number of cups', 'Number of cups', 'Number of cups', 'Number of cups'), suffixText: tLang(lang, 'كوب', 'cups', 'verres', 'bardak', 'cawan', 'gelas'),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () { if (context.mounted) Navigator.pop(context); }, child: Text(tLang(lang, 'إلغاء', 'Cancel', 'Annuler', 'İptal', 'Batal', 'Batal'), style: const TextStyle(fontFamily:'Cairo'))),
        ElevatedButton(
          onPressed: () {
            final n = int.tryParse(ctrl.text.trim()) ?? 8;
            ref.read(waterProvider.notifier).setGoal(n.clamp(4, 20));
            if (context.mounted) Navigator.pop(context);
          }, child: Text(tLang(lang, 'حفظ', 'Save', 'Enregistrer', 'Kaydet', 'Simpan', 'Simpan'), style: const TextStyle(fontFamily:'Cairo')),
        ),
      ],
    ));
  }

  void _editSleepGoal(BuildContext context, bool isAr) {
    final ctrl = TextEditingController(
        text: ref.read(sleepProvider).goal.toStringAsFixed(1));
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(tLang(lang, 'هدف النوم', 'Sleep Goal', 'Objectif sommeil', 'Uyku Hedefi', 'Sasaran Tidur', 'Target Tidur'), style: const TextStyle(fontFamily:'Cairo')),
      content: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration( hintText: tLang(lang, 'عدد الساعات', 'Number of hours', 'Number of hours', 'Number of hours', 'Number of hours', 'Number of hours'), suffixText: tLang(lang, 'ساعة', 'hrs', 'h', 'sa', 'jam', 'jam'),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () { if (context.mounted) Navigator.pop(context); }, child: Text(tLang(lang, 'إلغاء', 'Cancel', 'Annuler', 'İptal', 'Batal', 'Batal'), style: const TextStyle(fontFamily:'Cairo'))),
        ElevatedButton(
          onPressed: () { final h = double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 8.0;
            ref.read(sleepProvider.notifier).set(h.clamp(4.0, 12.0));
            if (context.mounted) Navigator.pop(context);
          }, child: Text(tLang(lang, 'حفظ', 'Save', 'Enregistrer', 'Kaydet', 'Simpan', 'Simpan'), style: const TextStyle(fontFamily:'Cairo')),
        ),
      ],
    ));
  }

  void _confirmClearDay(BuildContext context, bool isAr) {
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(tLang(lang, 'مسح سجل اليوم؟', 'Clear Today Log?', 'Effacer le journal?', 'Bugünkü Veriyi Sil?', 'Padam Log Hari Ini?', 'Hapus Log Hari Ini?'), style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700)),
      content: Text(
        tLang(lang, 'سيُمسح سجل الوجبات والخطوات والماء لليوم فقط. لا يمكن التراجع.', 'Today\'s meals, steps, and water will be cleared. Cannot be undone.', 'Les repas, étapes et eau d\'aujourd\'hui seront effacés. Irréversible.', 'Bugünün öğünleri, adımları ve suyu silinecek. Geri alınamaz.', 'Makanan, langkah dan air hari ini akan dipadam. Tidak boleh dibatalkan.', 'Makanan, langkah dan air hari ini akan dihapus. Tidak dapat dibatalkan.'), style: const TextStyle(fontFamily:'Cairo', fontSize: 13, height: 1.5)),
      actions: [
        TextButton(onPressed: () { if (context.mounted) Navigator.pop(context); }, child: Text(tLang(lang, 'إلغاء', 'Cancel', 'Annuler', 'İptal', 'Batal', 'Batal'), style: const TextStyle(fontFamily:'Cairo'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.haramRed),
          onPressed: () async {
            if (context.mounted) Navigator.pop(context);
            await ref.read(waterProvider.notifier).set(0);
            await ref.read(healthProvider.notifier).setSteps(0);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text(tLang(lang, '✅ تم مسح سجل اليوم', '✅ Today log cleared', '✅ Journal effacé', '✅ Bugün temizlendi', '✅ Log hari ini dipadam', '✅ Log hari ini dihapus'), style: const TextStyle(fontFamily:'Cairo')),
                backgroundColor: AppColors.sunnahGreen,
              ));
            }
          }, child: Text(tLang(lang, 'مسح', 'Clear', 'Effacer', 'Temizle', 'Padam', 'Hapus'), style: const TextStyle(fontFamily:'Cairo', color: Colors.white)),
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
      title: Text(widget.label, style: TextStyle(fontFamily: 'Cairo',
          fontWeight: FontWeight.w600, fontSize: 14, color: text)),
      subtitle: Text(widget.sub, style: TextStyle(fontFamily: 'Cairo',
          fontSize: 11, color: muted)),
      trailing: Switch(value: _value, onChanged: _toggle,
          activeColor: AppColors.sunnahGreen),
      onTap: () => _toggle(!_value),
    );
  }
}

