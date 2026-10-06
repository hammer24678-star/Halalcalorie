// notification_center_screen.dart — HalalCalorie v56 (PATCH_V56_NOTIF_CENTER)
// One place to see whether notifications really work, fix them, test them and
// tune every reminder. Basic reminders are free; the smart ones are Premium.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/l10n.dart';
import '../../core/notification_service.dart';
import '../../core/prayer_provider.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'premium_ui.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});
  @override
  ConsumerState<NotificationCenterScreen> createState() => _NCState();
}

class _NCState extends ConsumerState<NotificationCenterScreen>
    with WidgetsBindingObserver {
  NotifStatus? _status;
  final Map<String, bool> _on = {};
  final Map<String, int> _times = {};
  String? _note;

  static const Map<String, bool> _boolDefaults = {
    'notif_water': true,
    'notif_meals': true,
    'notif_workout': false,
    'notif_ascent': true,
    'notif_streak': true,
    'notif_weekly': true,
    'notif_sunnah': true,
    'notif_suhoor': true,
    'notif_iftar': true,
  };
  static const Map<String, int> _timeDefaults = {
    'time_breakfast': 450,
    'time_lunch': 780,
    'time_dinner': 1170,
    'time_workout': 1050,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system settings page: re-read the real state.
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final s = await NotificationService.status();
    if (!mounted) return;
    setState(() {
      _status = s;
      for (final e in _boolDefaults.entries) {
        _on[e.key] = p.getBool(e.key) ?? e.value;
      }
      for (final e in _timeDefaults.entries) {
        _times[e.key] = p.getInt(e.key) ?? e.value;
      }
    });
  }

  Future<void> _refreshStatus() async {
    final s = await NotificationService.status();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _apply() async {
    try {
      await NotificationService.rescheduleAll();
      final times = await ref
          .read(prayerTimesProvider.future)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      await NotificationService.refreshSmart(
          times: times, ramadan: ref.read(ramadanModeProvider));
    } catch (_) {}
    await _refreshStatus();
  }

  Future<void> _setBool(String key, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
    if (mounted) setState(() => _on[key] = v);
    await _apply();
  }

  Future<void> _pickTime(String key) async {
    final cur = _times[key] ?? _timeDefaults[key] ?? 480;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (picked == null) return;
    final p = await SharedPreferences.getInstance();
    final m = picked.hour * 60 + picked.minute;
    await p.setInt(key, m);
    if (mounted) setState(() => _times[key] = m);
    await _apply();
  }

  Future<void> _toggleMaster(bool v) async {
    final cur = ref.read(notificationsEnabledProvider);
    if (cur != v) await ref.read(notificationsEnabledProvider.notifier).toggle();
    try {
      if (v) {
        await NotificationService.requestPermissions();
        await _apply();
      } else {
        await NotificationService.cancelAll();
        await _refreshStatus();
      }
    } catch (_) {}
  }

  Future<void> _allow() async {
    final ok = await NotificationService.requestPermissions();
    if (!ok) {
      // Android stops showing the prompt after a refusal; only the system
      // settings page can turn notifications back on.
      await NotificationService.openSystemSettings();
    } else {
      await _apply();
    }
    await _refreshStatus();
  }

  String _fmt(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final master = ref.watch(notificationsEnabledProvider);
    final th = PTheme(isDark);
    String t(String ar, String en) => tLang(lang, ar, en);
    final st = _status;
    final blocked = st != null && !st.enabled;

    Widget toggleRow({
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required String key,
      bool premiumOnly = false,
      bool last = false,
    }) {
      final locked = premiumOnly && !premium;
      final value = (_on[key] ?? _boolDefaults[key] ?? false) && !locked;
      return InkWell(
        onTap: locked ? () => openPaywall(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            PBadge(icon, size: 40, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                        child: Text(title,
                            style: pText(th.text, 14, w: FontWeight.w800))),
                    if (premiumOnly) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.workspace_premium_rounded,
                          size: 14, color: kGold),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.35)),
                ],
              ),
            ),
            if (locked)
              const Icon(Icons.lock_rounded, size: 18, color: kGold)
            else
              Switch(
                value: value && master,
                activeColor: AppColors.halalGreen,
                onChanged: master ? (v) => _setBool(key, v) : null,
              ),
          ]),
        ),
      );
    }

    Widget timeRow(String ar, String en, String key) {
      final m = _times[key] ?? _timeDefaults[key] ?? 480;
      return InkWell(
        onTap: () => premium ? _pickTime(key) : openPaywall(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            const Icon(Icons.schedule_rounded, size: 18, color: kGold),
            const SizedBox(width: 12),
            Expanded(
                child: Text(t(ar, en),
                    style: pText(th.text, 13.5, w: FontWeight.w700))),
            Text(premium ? _fmt(m) : _fmt(_timeDefaults[key] ?? m),
                style: pText(premium ? kGold : th.muted, 14, w: FontWeight.w800)),
            const SizedBox(width: 8),
            Icon(premium ? Icons.edit_rounded : Icons.lock_rounded,
                size: 16, color: premium ? th.muted : kGold),
          ]),
        ),
      );
    }

    Widget divider() => Divider(height: 1, color: th.border);

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('مركز الإشعارات', 'Notification Center'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // ── Status ─────────────────────────────────────────
          PCard(
            th: th,
            gold: !blocked,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                PBadge(
                  blocked
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_active_rounded,
                  size: 48,
                  color: blocked ? AppColors.haramRed : AppColors.halalGreen,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        st == null
                            ? t('جارٍ الفحص…', 'Checking…')
                            : blocked
                                ? t('الإشعارات محظورة من النظام',
                                    'Blocked by the system')
                                : !master
                                    ? t('التذكيرات متوقفة', 'Reminders paused')
                                    : t('الإشعارات تعمل', 'Notifications are on'),
                        style: pText(th.text, 17, w: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        st == null
                            ? ''
                            : blocked
                                ? t('اسمح بالإشعارات حتى تصلك التذكيرات',
                                    'Allow notifications so reminders can reach you')
                                : t('${st.pending} تذكير مجدول',
                                    '${st.pending} reminders scheduled'),
                        style: pText(th.muted, 12.5, w: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              if (blocked)
                PGoldButton(
                  label: t('السماح بالإشعارات', 'Allow notifications'),
                  icon: Icons.notifications_active_rounded,
                  onTap: _allow,
                )
              else
                Row(children: [
                  Expanded(
                    child: PGoldButton(
                      label: t('جرّب الآن', 'Test now'),
                      icon: Icons.bolt_rounded,
                      onTap: () async {
                        await NotificationService.sendTest();
                        if (mounted) {
                          setState(() => _note = t(
                              'أُرسل إشعار تجريبي. إن لم يظهر، افتح إعدادات النظام.',
                              'Test sent. If you did not see it, open system settings.'));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PGoldButton(
                      outlined: true,
                      label: t('بعد دقيقة', 'In 1 minute'),
                      icon: Icons.timer_rounded,
                      onTap: () async {
                        try {
                          await NotificationService.scheduleTestInOneMinute();
                          if (mounted) {
                            setState(() => _note = t(
                                'جُدول إشعار بعد دقيقة (قد يتأخر قليلًا في وضع توفير البطارية).',
                                'Scheduled for about a minute from now (battery saver may delay it a little).'));
                          }
                        } catch (e) {
                          if (mounted) setState(() => _note = '$e');
                        }
                        await _refreshStatus();
                      },
                    ),
                  ),
                ]),
              if (_note != null) ...[
                const SizedBox(height: 10),
                Text(_note!, style: pText(th.muted, 12, w: FontWeight.w500, h: 1.4)),
              ],
            ]),
          ),

          // ── Basic reminders ────────────────────────────────
          PSection(t('التذكيرات الأساسية', 'BASIC REMINDERS'), th),
          PCard(
            th: th,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                const PBadge(Icons.notifications_rounded,
                    size: 40, color: AppColors.doubtOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('تفعيل الإشعارات', 'Enable notifications'),
                          style: pText(th.text, 14, w: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                          t('المفتاح الرئيسي لكل التذكيرات',
                              'Master switch for every reminder'),
                          style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.35)),
                    ],
                  ),
                ),
                Switch(
                  value: master,
                  activeColor: AppColors.halalGreen,
                  onChanged: _toggleMaster,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          PCard(
            th: th,
            padding: EdgeInsets.zero,
            child: Column(children: [
              toggleRow(
                icon: Icons.water_drop_rounded,
                color: AppColors.waterBlue,
                title: t('تذكير الماء', 'Water'),
                subtitle: t('كل ساعتين من ٨ ص إلى ١٠ م', 'Every 2 hours, 8 am – 10 pm'),
                key: 'notif_water',
              ),
              divider(),
              toggleRow(
                icon: Icons.restaurant_rounded,
                color: AppColors.halalGreen,
                title: t('الوجبات', 'Meals'),
                subtitle: t('الفطور والغداء والعشاء', 'Breakfast, lunch and dinner'),
                key: 'notif_meals',
              ),
              divider(),
              toggleRow(
                icon: Icons.fitness_center_rounded,
                color: AppColors.sleepPurple,
                title: t('التمرين', 'Workout'),
                subtitle: t('تذكير يومي بالحركة', 'A daily nudge to move'),
                key: 'notif_workout',
              ),
              divider(),
              toggleRow(
                icon: Icons.terrain_rounded,
                color: kGold,
                title: t('مهام Ascent', 'Ascent quests'),
                subtitle: t('بعد العصر', 'Mid-afternoon'),
                key: 'notif_ascent',
                last: true,
              ),
            ]),
          ),

          // ── Premium smart reminders ────────────────────────
          PSection(t('تذكيرات ذكية — بريميوم', 'SMART REMINDERS — PREMIUM'), th),
          PCard(
            th: th,
            gold: true,
            padding: EdgeInsets.zero,
            child: Column(children: [
              toggleRow(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.haramRed,
                title: t('حارس السلسلة', 'Streak guard'),
                subtitle: t('٨:٣٠ م — فقط إن لم تسجّل وجبة اليوم',
                    '8:30 pm — only if you have not logged a meal today'),
                key: 'notif_streak',
                premiumOnly: true,
              ),
              divider(),
              toggleRow(
                icon: Icons.insights_rounded,
                color: AppColors.waterBlue,
                title: t('المراجعة الأسبوعية', 'Weekly review'),
                subtitle: t('الجمعة ٨ م — تقدّمك وتوقّع وزنك',
                    'Friday 8 pm — your trends and weight forecast'),
                key: 'notif_weekly',
                premiumOnly: true,
              ),
              divider(),
              toggleRow(
                icon: Icons.calendar_month_rounded,
                color: AppColors.sleepPurple,
                title: t('ليلة صيام السنّة', 'Sunnah-fast eve'),
                subtitle: t('الاثنين والخميس والأيام البيض وعرفة وعاشوراء',
                    'Mondays, Thursdays, White Days, Arafah, Ashura'),
                key: 'notif_sunnah',
                premiumOnly: true,
              ),
              divider(),
              toggleRow(
                icon: Icons.free_breakfast_rounded,
                color: kGold,
                title: t('السحور', 'Suhoor'),
                subtitle: t('قبل الفجر بـ ٤٥ دقيقة، بحسب مواقيت مدينتك',
                    '45 minutes before Fajr, using your city\u2019s prayer times'),
                key: 'notif_suhoor',
                premiumOnly: true,
              ),
              divider(),
              toggleRow(
                icon: Icons.nightlight_round,
                color: AppColors.halalGreen,
                title: t('الإفطار', 'Iftar'),
                subtitle: t('قبل المغرب بـ ١٠ دقائق', '10 minutes before Maghrib'),
                key: 'notif_iftar',
                premiumOnly: true,
                last: true,
              ),
            ]),
          ),

          // ── Custom times ───────────────────────────────────
          PSection(t('أوقات مخصصة — بريميوم', 'CUSTOM TIMES — PREMIUM'), th),
          PCard(
            th: th,
            padding: EdgeInsets.zero,
            child: Column(children: [
              timeRow('الفطور', 'Breakfast', 'time_breakfast'),
              divider(),
              timeRow('الغداء', 'Lunch', 'time_lunch'),
              divider(),
              timeRow('العشاء', 'Dinner', 'time_dinner'),
              divider(),
              timeRow('التمرين', 'Workout', 'time_workout'),
            ]),
          ),

          // ── Reliability tips ───────────────────────────────
          PSection(t('إن تأخرت التذكيرات', 'IF REMINDERS ARRIVE LATE'), th),
          PCard(
            th: th,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                t('بعض الهواتف توقف التطبيقات في الخلفية لتوفير البطارية. افتح: الإعدادات ← التطبيقات ← HalalCalorie ← البطارية، واختر «غير مقيّد».',
                    'Some phones put apps to sleep to save battery. Open Settings → Apps → HalalCalorie → Battery and choose “Unrestricted”.'),
                style: pText(th.muted, 12.5, w: FontWeight.w500, h: 1.55),
              ),
              const SizedBox(height: 12),
              PGoldButton(
                outlined: true,
                label: t('فتح إعدادات التطبيق', 'Open app settings'),
                icon: Icons.settings_rounded,
                onTap: NotificationService.openSystemSettings,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
