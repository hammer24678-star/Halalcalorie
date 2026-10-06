// fasting_planner_screen.dart — HalalCalorie v58 (PATCH_V58_FASTING)
// Sunnah-fast calendar. Everyone sees the next three fasts; Premium gets the
// full two-month calendar, a fasting log with streak, suhoor/iftar times from
// the user's own prayer times, and a suhoor/iftar plate guide.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/fasting_calendar.dart';
import '../../core/hijri.dart';
import '../../core/l10n.dart';
import '../../core/prayer_provider.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'premium_ui.dart';

class FastingPlannerScreen extends ConsumerStatefulWidget {
  const FastingPlannerScreen({super.key});
  @override
  ConsumerState<FastingPlannerScreen> createState() => _FastingState();
}

class _FastingState extends ConsumerState<FastingPlannerScreen> {
  static const _prefKey = 'fasts_done_v1';
  Set<String> _done = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _done = (p.getStringList(_prefKey) ?? const <String>[]).toSet());
  }

  Future<void> _toggle(String key) async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      if (!_done.remove(key)) _done.add(key);
    });
    await p.setStringList(_prefKey, _done.toList());
  }

  /// Consecutive recommended-fast days completed, counted back from the most
  /// recent one that has passed (a missed fast ends the run).
  int _streak() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var streak = 0;
    for (var i = 0; i < 120; i++) {
      final d = today.subtract(Duration(days: i));
      if (!FastingCalendar.isSunnahFast(d)) continue;
      final k = FastingCalendar.dateKey(d);
      if (_done.contains(k)) {
        streak++;
      } else if (i == 0) {
        continue; // today is still open
      } else {
        break;
      }
    }
    return streak;
  }

  String _dayName(DateTime d, bool isAr) {
    const ar = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (isAr ? ar : en)[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final th = PTheme(isDark);
    final isAr = lang == 'ar';
    String t(String ar, String en) => tLang(lang, ar, en);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final all = FastingCalendar.upcoming(from: today, days: 60);
    final shown = premium ? all : all.take(3).toList();
    final hToday = HijriDate.fromGregorian(today);
    final prayer = ref.watch(prayerTimesProvider).valueOrNull;
    final next = all.isEmpty ? null : all.first;
    final inRamadan = hToday.isRamadan;

    String two(int v) => v.toString().padLeft(2, '0');
    String clock(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('مخطط الصيام', 'Fasting Planner'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // Hero
          PCard(
            th: th,
            gold: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const PBadge(Icons.nightlight_round, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      inRamadan
                          ? t('رمضان مبارك', 'Ramadan Mubarak')
                          : next == null
                              ? t('لا صيام مستحب قريبًا', 'No recommended fast soon')
                              : () {
                                  final d = next.date.difference(today).inDays;
                                  final title = isAr
                                      ? FastingCalendar.titleAr(next.kind)
                                      : FastingCalendar.titleEn(next.kind);
                                  return d == 0
                                      ? t('اليوم: $title', 'Today: $title')
                                      : d == 1
                                          ? t('غدًا: $title', 'Tomorrow: $title')
                                          : t('بعد $d أيام: $title', 'In $d days: $title');
                                }(),
                      style: pText(th.text, 16.5, w: FontWeight.w900, h: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${hToday.day} ${hToday.monthName(arabic: isAr)} ${hToday.year}',
                      style: pText(th.muted, 12.5, w: FontWeight.w600),
                    ),
                  ]),
                ),
              ]),
              if (premium && prayer != null) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _timeBox(th, Icons.free_breakfast_rounded,
                        t('إمساك السحور', 'Suhoor ends'),
                        clock(prayer.fajr), kGold),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _timeBox(th, Icons.nightlight_round,
                        t('الإفطار', 'Iftar'), clock(prayer.maghrib),
                        AppColors.halalGreen),
                  ),
                ]),
              ],
              if (premium) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _timeBox(th, Icons.local_fire_department_rounded,
                        t('سلسلة الصيام', 'Fasting streak'),
                        '${_streak()}', AppColors.haramRed),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _timeBox(th, Icons.check_circle_rounded,
                        t('أيام أتممتها', 'Days completed'),
                        '${_done.length}', AppColors.waterBlue),
                  ),
                ]),
              ],
            ]),
          ),

          PSection(t('الأيام القادمة', 'UPCOMING FASTS'), th),
          if (shown.isEmpty)
            PCard(
                th: th,
                child: Text(t('لا أيام مستحبة في الشهرين القادمين.',
                    'No recommended fasting days in the next two months.'),
                    style: pText(th.muted, 13))),
          for (final f in shown) ...[
            _fastTile(f, th, isAr, premium, today),
            const SizedBox(height: 8),
          ],
          if (!premium && all.length > 3)
            PCard(
              th: th,
              gold: true,
              onTap: () => openPaywall(context),
              child: Row(children: [
                const PBadge(Icons.lock_rounded, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('+${all.length - 3} يومًا قادمًا، وسجل الصيام والسلسلة وتذكير السحور والإفطار — مع بريميوم',
                        '+${all.length - 3} more fasts, your fasting log and streak, plus suhoor and iftar reminders — with Premium'),
                    style: pText(th.text, 13, w: FontWeight.w700, h: 1.45),
                  ),
                ),
              ]),
            ),

          // Plate guide
          PSection(t('طبق السحور والإفطار', 'SUHOOR & IFTAR PLATE'), th),
          PLocked(
            locked: !premium,
            th: th,
            label: t('افتح مع بريميوم', 'Unlock with Premium'),
            onUnlock: () => openPaywall(context),
            child: PCard(
              th: th,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _guideTitle(th, Icons.free_breakfast_rounded, t('السحور — يدوم شبعه', 'Suhoor — built to last')),
                const SizedBox(height: 6),
                _bullet(th, t('بطيئة الهضم: شوفان أو خبز أسمر أو فول (٤٠–٦٠ غ كربوهيدرات)',
                    'Slow carbs: oats, whole-grain bread or ful (40–60 g carbs)')),
                _bullet(th, t('بروتين: بيضتان أو زبادي يوناني أو جبنة قريش',
                    'Protein: two eggs, Greek yogurt or cottage cheese')),
                _bullet(th, t('ماء وفير، وقلّل الملح والمخللات حتى لا تعطش',
                    'Plenty of water; go easy on salt and pickles so thirst stays away')),
                const SizedBox(height: 12),
                _guideTitle(th, Icons.nightlight_round, t('الإفطار — بهدوء', 'Iftar — gently')),
                const SizedBox(height: 6),
                _bullet(th, t('٣ تمرات وماء، ثم صلِّ المغرب، ثم وجبة متوازنة',
                    '3 dates and water, pray Maghrib, then a balanced meal')),
                _bullet(th, t('ابدأ بشوربة أو سلطة، وخفّف المقليات والحلويات',
                    'Start with soup or salad; go light on fried food and sweets')),
                _bullet(th, t('نصف الطبق خضار، وربعه بروتين، وربعه نشويات',
                    'Half the plate vegetables, a quarter protein, a quarter starch')),
              ]),
            ),
          ),

          const SizedBox(height: 18),
          Text(
            t('التقويم الهجري هنا حسابي وقد يختلف عن رؤية الهلال في بلدك بيوم. اعتمد إعلان دار الإفتاء في بلدك.',
                'The Hijri dates here are calculated and can differ from your local moon sighting by a day. Follow your country\u2019s announcement.'),
            textAlign: TextAlign.center,
            style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(PTheme th, IconData icon, String label, String value, Color c) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: th.card.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(0.35), width: 0.8),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: pText(th.muted, 11, w: FontWeight.w700)),
              Text(value, style: pText(th.text, 17, w: FontWeight.w900)),
            ]),
          ),
        ]),
      );

  Widget _guideTitle(PTheme th, IconData i, String s) => Row(children: [
        Icon(i, size: 18, color: kGold),
        const SizedBox(width: 8),
        Text(s, style: pText(th.text, 14, w: FontWeight.w900)),
      ]);

  Widget _bullet(PTheme th, String s) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(s, style: pText(th.muted, 12.5, w: FontWeight.w600, h: 1.5))),
        ]),
      );

  Widget _fastTile(FastDay f, PTheme th, bool isAr, bool premium, DateTime today) {
    final key = FastingCalendar.dateKey(f.date);
    final done = _done.contains(key);
    final diff = f.date.difference(today).inDays;
    final title = isAr ? FastingCalendar.titleAr(f.kind) : FastingCalendar.titleEn(f.kind);
    final note = isAr ? FastingCalendar.noteAr(f.kind) : FastingCalendar.noteEn(f.kind);
    final when = diff == 0
        ? (isAr ? 'اليوم' : 'Today')
        : diff == 1
            ? (isAr ? 'غدًا' : 'Tomorrow')
            : '${_dayName(f.date, isAr)} ${f.date.day}/${f.date.month}';
    return PCard(
      th: th,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: kGold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text('${f.date.day}', style: pText(kGold, 20, w: FontWeight.w900)),
            Text('${f.hijri.day}/${f.hijri.month}', style: pText(th.muted, 10.5, w: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: pText(th.text, 14, w: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('$when · $note', style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.4)),
          ]),
        ),
        const SizedBox(width: 8),
        if (premium && diff <= 0)
          GestureDetector(
            onTap: () => _toggle(key),
            child: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 28, color: done ? AppColors.halalGreen : th.muted),
          ),
      ]),
    );
  }
}
