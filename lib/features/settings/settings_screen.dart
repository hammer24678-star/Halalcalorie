// settings_screen.dart — HalalCalorie v1.0
import 'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:go_router/go_router.dart'; import'package:shared_preferences/shared_preferences.dart'; import'../../core/theme.dart'; import'../../core/providers.dart'; import'../../core/notifications.dart';

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

    String t(String ar, String en) => isAr ? ar : en;

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.sunnahGreen, letterSpacing: 1.2)),
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
        value: value, onChanged: onChanged, activeColor: AppColors.sunnahGreen,
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
            tile( emoji:'🌐', title: t('اللغة', 'Language'), subtitle: isAr ?'العربية' : 'English',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [ _langBtn(context, isAr, true,'ع', 'ar'),
                const SizedBox(width: 6), _langBtn(context, isAr, false,'EN', 'en'),
              ]),
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
            tile( emoji:'🗑️', title: t('مسح سجل اليوم', 'Clear Today\'s Data'), subtitle: t('الوجبات والخطوات والماء', 'Meals, steps, water'),
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

  Widget _langBtn(BuildContext context, bool isAr, bool isActive, String label, String code) {
    return GestureDetector(
      onTap: () => ref.read(languageProvider.notifier).set(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.sunnahGreen : Colors.transparent,
          border: Border.all(
              color: isActive ? AppColors.sunnahGreen : AppColors.lightMuted),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle( fontFamily:'Cairo', fontSize: 12, fontWeight: FontWeight.w700,
          color: isActive ? Colors.white : AppColors.lightMuted,
        )),
      ),
    );
  }

  void _editWaterGoal(BuildContext context, bool isAr) {
    final ctrl = TextEditingController( text:'${ref.read(waterProvider).goal}');
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(isAr ?'هدف الماء اليومي' : 'Daily Water Goal', style: const TextStyle(fontFamily:'Cairo')),
      content: TextField(
        controller: ctrl, keyboardType: TextInputType.number,
        decoration: InputDecoration( hintText: isAr ?'عدد الأكواب' : 'Number of cups', suffixText: isAr ?'كوب' : 'cups',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () { if (context.mounted) Navigator.pop(context); }, child: Text(isAr ?'إلغاء' : 'Cancel', style: const TextStyle(fontFamily:'Cairo'))),
        ElevatedButton(
          onPressed: () {
            final n = int.tryParse(ctrl.text.trim()) ?? 8;
            ref.read(waterProvider.notifier).setGoal(n.clamp(4, 20));
            if (context.mounted) Navigator.pop(context);
          }, child: Text(isAr ?'حفظ' : 'Save', style: const TextStyle(fontFamily:'Cairo')),
        ),
      ],
    ));
  }

  void _editSleepGoal(BuildContext context, bool isAr) {
    final ctrl = TextEditingController(
        text: ref.read(sleepProvider).goal.toStringAsFixed(1));
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(isAr ?'هدف النوم' : 'Sleep Goal', style: const TextStyle(fontFamily:'Cairo')),
      content: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration( hintText: isAr ?'عدد الساعات' : 'Number of hours', suffixText: isAr ?'ساعة' : 'hrs',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () { if (context.mounted) Navigator.pop(context); }, child: Text(isAr ?'إلغاء' : 'Cancel', style: const TextStyle(fontFamily:'Cairo'))),
        ElevatedButton(
          onPressed: () { final h = double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 8.0;
            ref.read(sleepProvider.notifier).set(h.clamp(4.0, 12.0));
            if (context.mounted) Navigator.pop(context);
          }, child: Text(isAr ?'حفظ' : 'Save', style: const TextStyle(fontFamily:'Cairo')),
        ),
      ],
    ));
  }

  void _confirmClearDay(BuildContext context, bool isAr) {
    showDialog(context: context, builder: (_) => AlertDialog( title: Text(isAr ?'مسح سجل اليوم؟' : 'Clear Today\'s Data?', style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700)),
      content: Text(
        isAr ?'سيُمسح سجل الوجبات والخطوات والماء لليوم فقط. لا يمكن التراجع.' :'Today\'s meals, steps, and water will be cleared. Cannot be undone.', style: const TextStyle(fontFamily:'Cairo', fontSize: 13, height: 1.5)),
      actions: [
        TextButton(onPressed: () { if (context.mounted) Navigator.pop(context); }, child: Text(isAr ?'إلغاء' : 'Cancel', style: const TextStyle(fontFamily:'Cairo'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.haramRed),
          onPressed: () async {
            if (context.mounted) Navigator.pop(context);
            await ref.read(waterProvider.notifier).set(0);
            await ref.read(healthProvider.notifier).setSteps(0);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar( content: Text(isAr ?'✅ تم مسح سجل اليوم' : '✅ Today\'s log cleared', style: const TextStyle(fontFamily:'Cairo')),
                backgroundColor: AppColors.sunnahGreen,
              ));
            }
          }, child: Text(isAr ?'مسح' : 'Clear', style: const TextStyle(fontFamily:'Cairo', color: Colors.white)),
        ),
      ],
    ));
  }
}
