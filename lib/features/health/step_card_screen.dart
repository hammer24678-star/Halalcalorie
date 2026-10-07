// step_card_screen.dart — HalalCalorie v59 (PATCH_V59_STEPCARD)
// Settings for the live step card. The preview at the top is rendered by the
// same native code that draws the real notification, so what you tune here is
// exactly what appears in the shade.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import '../../core/l10n.dart';
import '../../core/notification_service.dart';
import '../../core/providers.dart';
import '../../core/step_card_service.dart';
import '../../core/theme.dart';
import '../premium/premium_ui.dart';

class StepCardScreen extends ConsumerStatefulWidget {
  const StepCardScreen({super.key});
  @override
  ConsumerState<StepCardScreen> createState() => _StepCardScreenState();
}

class _StepCardScreenState extends ConsumerState<StepCardScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> _status = <String, dynamic>{};
  final Stopwatch _clock = Stopwatch()..start();
  double _demo = -1; // preview progress 0..1.2, negative = live steps
  int _walkAt = 0;
  int _celebAt = 0;
  double _stride = 76;
  double _kcal = 0.04;
  String? _note;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    StepCardService.init().then((_) {
      if (!mounted) return;
      final c = StepCardService.config.value;
      setState(() {
        _stride = c.d('strideCm');
        _kcal = c.d('kcalPerStep');
      });
      _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await StepCardService.status();
    if (mounted) setState(() => _status = s);
  }

  int get _now => _clock.elapsedMilliseconds;

  Future<void> _toggleMaster(bool v, String Function(String, String) t) async {
    if (!v) {
      await StepCardService.disable();
      await _refresh();
      return;
    }
    final r = await StepCardService.enable();
    if (!mounted) return;
    switch (r) {
      case StepCardEnable.ok:
        setState(() => _note = null);
        break;
      case StepCardEnable.needActivity:
        setState(() => _note = t(
            'يلزم إذن «النشاط البدني» لعدّ الخطوات.',
            'The Physical activity permission is needed to count steps.'));
        break;
      case StepCardEnable.needActivityForever:
        setState(() => _note = t(
            'الإذن مرفوض نهائيًا. فعّله من إعدادات التطبيق.',
            'Permission was refused for good. Turn it on in app settings.'));
        await openAppSettings();
        break;
      case StepCardEnable.failed:
        setState(() => _note = t('تعذّر التشغيل. حاول مرة أخرى.', 'Could not start. Try again.'));
        break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final th = PTheme(isDark);
    String t(String ar, String en) => tLang(lang, ar, en);

    return ValueListenableBuilder<StepCardConfig>(
      valueListenable: StepCardService.config,
      builder: (context, cfg, _) {
        final on = cfg.b('enabled');
        final goal = cfg.i('goal');
        final theme = cfg.s('theme');
        final demoSteps = _demo >= 0 ? (goal * _demo).round() : -1;

        Widget row({
          required IconData icon,
          required String title,
          String? sub,
          required Widget trailing,
          Color color = AppColors.halalGreen,
        }) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                PBadge(icon, size: 38, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: pText(th.text, 14, w: FontWeight.w800)),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(sub, style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.35)),
                    ],
                  ]),
                ),
                trailing,
              ]),
            );

        Widget sw(IconData icon, String title, String? sub, String key,
                {bool enabled = true}) =>
            row(
              icon: icon,
              title: title,
              sub: sub,
              trailing: Switch(
                value: cfg.b(key),
                activeColor: AppColors.halalGreen,
                onChanged: enabled ? (v) => StepCardService.set(key, v) : null,
              ),
            );

        Widget chips(String key, List<List<String>> opts, {bool enabled = true}) {
          final cur = cfg.s(key);
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in opts)
                  GestureDetector(
                    onTap: enabled ? () => StepCardService.set(key, o[0]) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: cur == o[0]
                            ? AppColors.halalGreen.withOpacity(0.18)
                            : th.cardAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: cur == o[0] ? AppColors.halalGreen : th.border,
                            width: cur == o[0] ? 1.4 : 0.8),
                      ),
                      child: Text(o[1],
                          style: pText(cur == o[0] ? AppColors.halalGreen : th.text, 13,
                              w: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          );
        }

        Widget divider() => Divider(height: 1, color: th.border);

        // ── status ────────────────────────────────────────
        final perm = _status['permission'] == true;
        final notif = _status['notifications'] != false;
        final running = _status['running'] == true;
        final sensor = _status['sensor'] != false;
        final err = (_status['error'] as String?) ?? '';

        Widget statusLine(bool ok, String good, String bad, VoidCallback? fix, String fixLabel) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(children: [
                Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 18, color: ok ? AppColors.halalGreen : AppColors.doubtOrange),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(ok ? good : bad,
                        style: pText(th.text, 12.5, w: FontWeight.w600))),
                if (!ok && fix != null)
                  GestureDetector(
                    onTap: fix,
                    child: Text(fixLabel, style: pText(kGold, 12.5, w: FontWeight.w900)),
                  ),
              ]),
            );

        return Scaffold(
          backgroundColor: th.bg,
          appBar: AppBar(
            title: Text(t('بطاقة الخطوات', 'Step Card'),
                style: pText(th.text, 18, w: FontWeight.w900)),
            backgroundColor: th.bg,
            elevation: 0,
            iconTheme: IconThemeData(color: th.text),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
            children: [
              // ── live preview ───────────────────────────
              _PreviewBox(
                isDark: isDark,
                clock: _clock,
                demoSteps: demoSteps,
                walkAt: _walkAt,
                celebAt: _celebAt,
                configTick: cfg.toMap().toString(),
                note: t('معاينة حيّة — هي نفسها بطاقة الإشعارات',
                    'Live preview — the very card that appears in your shade'),
                th: th,
              ),
              const SizedBox(height: 10),
              PCard(
                th: th,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(t('تجربة التقدّم', 'Try progress'),
                        style: pText(th.text, 13.5, w: FontWeight.w800)),
                    const Spacer(),
                    Text(_demo < 0 ? t('مباشر', 'Live') : '${(_demo * 100).round()}%',
                        style: pText(kGold, 13, w: FontWeight.w900)),
                  ]),
                  Slider(
                    value: _demo < 0 ? 0 : _demo.clamp(0.0, 1.2).toDouble(),
                    min: 0,
                    max: 1.2,
                    activeColor: AppColors.halalGreen,
                    onChanged: (v) => setState(() => _demo = v),
                  ),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _MiniBtn(t('خطوة!', 'Walk!'), Icons.directions_walk_rounded, th,
                        () => setState(() => _walkAt = _now)),
                    _MiniBtn(t('احتفال بالهدف', 'Goal party'), Icons.celebration_rounded, th, () {
                      setState(() {
                        _demo = 1.0;
                        _celebAt = _now;
                      });
                    }),
                    _MiniBtn(t('مباشر', 'Live'), Icons.sensors_rounded, th,
                        () => setState(() => _demo = -1)),
                  ]),
                  const SizedBox(height: 6),
                ]),
              ),

              // ── master + status ────────────────────────
              PSection(t('التشغيل', 'POWER'), th),
              PCard(
                th: th,
                gold: on,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  row(
                    icon: Icons.directions_walk_rounded,
                    title: t('بطاقة الخطوات الحيّة', 'Live step card'),
                    sub: t('عدّاد خطوات متحرك في شريط الإشعارات يعمل حتى والتطبيق مغلق',
                        'An animated step counter in your notification shade, even with the app closed'),
                    trailing: Switch(
                      value: on,
                      activeColor: AppColors.halalGreen,
                      onChanged: (v) => _toggleMaster(v, t),
                    ),
                  ),
                  if (on) ...[
                    divider(),
                    const SizedBox(height: 4),
                    statusLine(perm, t('إذن النشاط البدني مفعّل', 'Physical activity allowed'),
                        t('إذن النشاط البدني ناقص', 'Physical activity permission missing'),
                        () => _toggleMaster(true, t), t('سماح', 'Allow')),
                    statusLine(notif, t('الإشعارات مفعّلة', 'Notifications allowed'),
                        t('الإشعارات محظورة من النظام', 'Notifications blocked by the system'),
                        () async {
                      final ok = await NotificationService.requestPermissions();
                      if (!ok) await NotificationService.openSystemSettings();
                      await _refresh();
                    }, t('إصلاح', 'Fix')),
                    statusLine(running, t('البطاقة تعمل الآن', 'Card is running'),
                        t('البطاقة غير شغّالة', 'Card is not running'), () async {
                      await StepCardService.apply();
                      await Future<void>.delayed(const Duration(milliseconds: 600));
                      await _refresh();
                    }, t('تشغيل', 'Start')),
                    if (!sensor)
                      statusLine(false, '', t('لا يوجد حساس خطوات؛ يُستخدم عدّاد التطبيق فقط',
                          'No step sensor on this phone; the app counter is used'), null, ''),
                    if (err.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
                        child: Text(err, style: pText(th.muted, 10.5, w: FontWeight.w500)),
                      ),
                    const SizedBox(height: 6),
                  ],
                ]),
              ),
              if (_note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                  child: Text(_note!, style: pText(AppColors.doubtOrange, 12.5, w: FontWeight.w700)),
                ),

              // ── theme ──────────────────────────────────
              PSection(t('السمة', 'THEME'), th),
              PCard(
                th: th,
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  chips('theme', [
                    ['green', t('أخضر', 'Green')],
                    ['white', t('أبيض', 'White')],
                    ['random', t('عشوائي', 'Random')],
                    ['auto', t('تلقائي', 'Auto')],
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Text(
                        theme == 'random'
                            ? t('ألوان جديدة تُختار لك — ليلية وفاتحة', 'A fresh colourway picked for you — dark and light')
                            : theme == 'auto'
                                ? t('يتبع وضع التطبيق (داكن/فاتح) ويتحول للذهبي في رمضان',
                                    'Follows the app mode (dark/light) and turns gold in Ramadan')
                                : t('ثابت على هذه السمة', 'Stays on this theme'),
                        style: pText(th.muted, 11.5, w: FontWeight.w500)),
                  ),
                  if (theme == 'random') ...[
                    divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                      child: Text(t('تبديل اللون', 'Shuffle'),
                          style: pText(th.text, 13, w: FontWeight.w800)),
                    ),
                    chips('shuffle', [
                      ['day', t('كل يوم', 'Every day')],
                      ['launch', t('كل تشغيل', 'Every start')],
                      ['manual', t('يدويًا', 'Manual')],
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: PGoldButton(
                        label: t('بدّل الآن', 'Shuffle now'),
                        icon: Icons.shuffle_rounded,
                        outlined: true,
                        onTap: () async {
                          await StepCardService.shuffleNow();
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ] else ...[
                    divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Text(t('لون التمييز', 'Accent'),
                          style: pText(th.text, 13, w: FontWeight.w800)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Wrap(spacing: 12, runSpacing: 10, children: [
                        for (final a in _accents)
                          GestureDetector(
                            onTap: () => StepCardService.set('accent', a.key),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: a.value,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: cfg.s('accent') == a.key ? th.text : Colors.transparent,
                                    width: 2.4),
                              ),
                              child: cfg.s('accent') == a.key
                                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                                  : null,
                            ),
                          ),
                      ]),
                    ),
                  ],
                ]),
              ),

              // ── style ──────────────────────────────────
              PSection(t('التصميم', 'STYLE'), th),
              PCard(
                th: th,
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  chips('style', [
                    ['orbit', t('حلقة', 'Orbit')],
                    ['stride', t('انسيابي', 'Stride')],
                    ['zen', t('هادئ', 'Zen')],
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Text(
                        cfg.s('style') == 'orbit'
                            ? t('الشعار داخل حلقة تقدّم متوهجة', 'Your logo inside a glowing progress ring')
                            : cfg.s('style') == 'stride'
                                ? t('شعار مربع وشريط تقدّم سميك', 'Squircle logo with a thick progress bar')
                                : t('رقم ضخم ونظيف بلا زخارف', 'One huge number, nothing else'),
                        style: pText(th.muted, 11.5, w: FontWeight.w500)),
                  ),
                ]),
              ),

              // ── content ────────────────────────────────
              PSection(t('ما يظهر', 'WHAT IT SHOWS'), th),
              PCard(
                th: th,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  sw(Icons.local_fire_department_rounded, t('السعرات', 'Calories'), null, 'showKcal'),
                  divider(),
                  sw(Icons.route_rounded, t('المسافة', 'Distance'), null, 'showDist'),
                  divider(),
                  sw(Icons.track_changes_rounded, t('نسبة الهدف', 'Goal percent'), null, 'showPct'),
                  divider(),
                  sw(Icons.bar_chart_rounded, t('رسم الأسبوع', 'Weekly chart'),
                      t('يظهر عند توسيع الإشعار', 'Shown when the card is expanded'), 'showWeek'),
                  divider(),
                  sw(Icons.chat_bubble_outline_rounded, t('رسائل التشجيع', 'Encouragement line'), null, 'showMsg'),
                  divider(),
                  sw(Icons.pin_rounded, t('أرقام عربية ٠١٢', 'Arabic-Indic digits ٠١٢'), null, 'arabicDigits'),
                ]),
              ),

              // ── animation ──────────────────────────────
              PSection(t('الحركة', 'ANIMATION'), th),
              PCard(
                th: th,
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final o in <List<Object>>[
                        [0, t('بدون', 'Off')],
                        [1, t('هادئ', 'Calm')],
                        [2, t('حيّ', 'Lively')],
                        [3, t('أقصى', 'Max')],
                      ])
                        GestureDetector(
                          onTap: () => StepCardService.set('anim', o[0] as int),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: cfg.i('anim') == o[0]
                                  ? AppColors.halalGreen.withOpacity(0.18)
                                  : th.cardAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: cfg.i('anim') == o[0] ? AppColors.halalGreen : th.border,
                                  width: cfg.i('anim') == o[0] ? 1.4 : 0.8),
                            ),
                            child: Text(o[1] as String,
                                style: pText(
                                    cfg.i('anim') == o[0] ? AppColors.halalGreen : th.text, 13,
                                    w: FontWeight.w800)),
                          ),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Text(
                        t('تتحرك البطاقة فقط والشاشة مضاءة لتوفير البطارية. تحترم إعداد «إزالة الحركة» في النظام.',
                            'The card only animates while the screen is on, to save battery. It respects the system "remove animations" setting.'),
                        style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.4)),
                  ),
                  divider(),
                  sw(Icons.auto_awesome_rounded, t('شرارات متطايرة', 'Floating sparkles'), null, 'particles',
                      enabled: cfg.i('anim') > 0),
                  divider(),
                  sw(Icons.waves_rounded, t('لمعان شريط التقدّم', 'Progress shimmer'), null, 'shimmer',
                      enabled: cfg.i('anim') > 0),
                  divider(),
                  sw(Icons.directions_walk_rounded, t('آثار الأقدام', 'Footprints'), null, 'footprints',
                      enabled: cfg.i('anim') > 0),
                  divider(),
                  sw(Icons.celebration_rounded, t('إشعار عند بلوغ الهدف', 'Goal celebration'),
                      t('إشعار قصير مع قصاصات ملونة على البطاقة', 'A short notification plus confetti on the card'),
                      'celebrate'),
                ]),
              ),

              // ── goal & body ────────────────────────────
              PSection(t('الهدف والجسم', 'GOAL & BODY'), th),
              PCard(
                th: th,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  row(
                    icon: Icons.flag_rounded,
                    title: t('هدف الخطوات اليومي', 'Daily step goal'),
                    color: kGold,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      _RoundBtn(Icons.remove_rounded, th,
                          () => StepCardService.set('goal', (goal - 500).clamp(1000, 50000))),
                      SizedBox(
                        width: 70,
                        child: Text('$goal',
                            textAlign: TextAlign.center,
                            style: pText(th.text, 15, w: FontWeight.w900)),
                      ),
                      _RoundBtn(Icons.add_rounded, th,
                          () => StepCardService.set('goal', (goal + 500).clamp(1000, 50000))),
                    ]),
                  ),
                  divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Row(children: [
                      Text(t('طول الخطوة', 'Stride length'),
                          style: pText(th.text, 13.5, w: FontWeight.w800)),
                      const Spacer(),
                      Text('${_stride.round()} cm', style: pText(kGold, 13, w: FontWeight.w900)),
                    ]),
                  ),
                  Slider(
                    value: _stride.clamp(50.0, 110.0).toDouble(),
                    min: 50,
                    max: 110,
                    divisions: 60,
                    activeColor: AppColors.halalGreen,
                    onChanged: (v) => setState(() => _stride = v),
                    onChangeEnd: (v) => StepCardService.set('strideCm', v.roundToDouble()),
                  ),
                  divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Row(children: [
                      Text(t('سعرات الخطوة', 'Calories per step'),
                          style: pText(th.text, 13.5, w: FontWeight.w800)),
                      const Spacer(),
                      Text(_kcal.toStringAsFixed(3), style: pText(kGold, 13, w: FontWeight.w900)),
                    ]),
                  ),
                  Slider(
                    value: _kcal.clamp(0.02, 0.08).toDouble(),
                    min: 0.02,
                    max: 0.08,
                    divisions: 60,
                    activeColor: AppColors.halalGreen,
                    onChanged: (v) => setState(() => _kcal = v),
                    onChangeEnd: (v) => StepCardService.set('kcalPerStep', double.parse(v.toStringAsFixed(3))),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _stride = 76;
                            _kcal = 0.04;
                          });
                          StepCardService.update(cfg.set('strideCm', 76.0).set('kcalPerStep', 0.04));
                        },
                        child: Text(t('مطابقة تبويب الصحة (٧٦ سم، ٠٫٠٤)', 'Match the Health tab (76 cm, 0.04)'),
                            style: pText(kGold, 12, w: FontWeight.w800)),
                      ),
                    ),
                  ),
                ]),
              ),

              // ── notification behaviour ─────────────────
              PSection(t('سلوك الإشعار', 'NOTIFICATION'), th),
              PCard(
                th: th,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  sw(Icons.notifications_none_rounded, t('أيقونة في شريط الحالة', 'Status-bar icon'),
                      t('أوقفها لإخفاء الأيقونة والإبقاء على البطاقة', 'Turn off to hide the icon but keep the card'),
                      'statusIcon'),
                  divider(),
                  row(
                    icon: Icons.lock_outline_rounded,
                    title: t('على شاشة القفل', 'On the lock screen'),
                    trailing: DropdownButton<String>(
                      value: cfg.s('lock'),
                      underline: const SizedBox.shrink(),
                      dropdownColor: th.card,
                      style: pText(th.text, 13, w: FontWeight.w800),
                      items: [
                        DropdownMenuItem(value: 'full', child: Text(t('إظهار', 'Show'))),
                        DropdownMenuItem(value: 'hide', child: Text(t('إخفاء', 'Hide'))),
                      ],
                      onChanged: (v) {
                        if (v != null) StepCardService.set('lock', v);
                      },
                    ),
                  ),
                  divider(),
                  sw(Icons.restart_alt_rounded, t('التشغيل بعد إعادة التشغيل', 'Start after reboot'), null, 'bootStart'),
                  divider(),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: PGoldButton(
                      label: t('جرّب إشعار الهدف', 'Test goal notification'),
                      icon: Icons.bolt_rounded,
                      outlined: true,
                      onTap: () async {
                        final ok = await StepCardService.testGoal();
                        if (mounted) {
                          setState(() => _note = ok
                              ? null
                              : t('شغّل البطاقة أولًا لتجربة الإشعار.', 'Turn the card on first to test it.'));
                        }
                      },
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
                child: Text(
                    t('اسحب البطاقة جانبًا لإخفائها؛ تعود عند فتح التطبيق. بعض الهواتف توقف الخدمات في الخلفية — استثنِ التطبيق من توفير البطارية.',
                        'Swipe the card away to hide it; it returns when you open the app. Some phones stop background services — exempt the app from battery optimisation.'),
                    style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.45)),
              ),
            ],
          ),
        );
      },
    );
  }

  static final List<MapEntry<String, Color>> _accents = <MapEntry<String, Color>>[
    const MapEntry('default', AppColors.halalGreen),
    const MapEntry('mint', Color(0xFF5EEAD4)),
    const MapEntry('gold', Color(0xFFDBA75D)),
    const MapEntry('ocean', Color(0xFF6FB3FF)),
    const MapEntry('violet', Color(0xFFBC8CFF)),
    const MapEntry('rose', Color(0xFFFF7BAC)),
    const MapEntry('sunset', Color(0xFFFF8A5B)),
  ];
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final PTheme th;
  final VoidCallback onTap;
  const _MiniBtn(this.label, this.icon, this.th, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: th.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: th.border, width: 0.8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: kGold),
            const SizedBox(width: 6),
            Text(label, style: pText(th.text, 12.5, w: FontWeight.w800)),
          ]),
        ),
      );
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final PTheme th;
  final VoidCallback onTap;
  const _RoundBtn(this.icon, this.th, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: th.cardAlt,
            shape: BoxShape.circle,
            border: Border.all(color: th.border, width: 0.8),
          ),
          child: Icon(icon, size: 18, color: th.text),
        ),
      );
}

/// Polls the native renderer a few times a second and shows what it draws.
class _PreviewBox extends StatefulWidget {
  final bool isDark;
  final Stopwatch clock;
  final int demoSteps;
  final int walkAt;
  final int celebAt;
  final String configTick;
  final String note;
  final PTheme th;
  const _PreviewBox({
    required this.isDark,
    required this.clock,
    required this.demoSteps,
    required this.walkAt,
    required this.celebAt,
    required this.configTick,
    required this.note,
    required this.th,
  });
  @override
  State<_PreviewBox> createState() => _PreviewBoxState();
}

class _PreviewBoxState extends State<_PreviewBox>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // PATCH_V60: one native call per frame (both cards, raw pixels, no PNG), paced
  // by a vsync Ticker, so the preview animates smoothly instead of ~3 fps.
  late final Ticker _ticker;
  bool _busy = false;
  bool _active = true;
  int _lastReq = -1000;
  ui.Image? _small;
  ui.Image? _big;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((_) => _tick())..start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _small?.dispose();
    _big?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  Future<ui.Image> _decode(Uint8List px, int w, int h) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  Future<void> _tick() async {
    if (_busy || !_active || !mounted) return;
    final now = widget.clock.elapsedMilliseconds;
    if (now - _lastReq < 24) return;
    _busy = true;
    _lastReq = now;
    try {
      final since = widget.walkAt == 0 ? 99999 : now - widget.walkAt;
      final celeb = widget.celebAt == 0 ? 99999 : now - widget.celebAt;
      final m = await StepCardService.previewBoth(
          tMs: now, steps: widget.demoSteps, sinceCelebMs: celeb, sinceStepMs: since);
      if (m == null) return;
      final sb = m['small'];
      final bb = m['big'];
      if (sb is! Uint8List || bb is! Uint8List) return;
      final s = await _decode(sb, (m['sw'] as num).toInt(), (m['sh'] as num).toInt());
      final b = await _decode(bb, (m['bw'] as num).toInt(), (m['bh'] as num).toInt());
      if (!mounted) {
        s.dispose();
        b.dispose();
        return;
      }
      final oldS = _small;
      final oldB = _big;
      setState(() {
        _small = s;
        _big = b;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldS?.dispose();
        oldB?.dispose();
      });
    } catch (_) {
      // a dropped preview frame is fine
    } finally {
      _busy = false;
    }
  }

  Widget _frame(ui.Image? im) {
    if (im == null) {
      return const SizedBox(
          height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return AspectRatio(
      aspectRatio: im.width / im.height,
      child: RawImage(image: im, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = widget.th;
    final shade = widget.isDark ? const Color(0xFF1C1F24) : const Color(0xFFE6E9ED);
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: shade,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: th.border, width: 0.8),
        ),
        child: Column(children: [
          _frame(_small),
          const SizedBox(height: 10),
          _frame(_big),
        ]),
      ),
      const SizedBox(height: 8),
      Text(widget.note, style: pText(th.muted, 11.5, w: FontWeight.w500)),
    ]);
  }
}
