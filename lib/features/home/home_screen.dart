// home_screen.dart — HalalCalorie — Ultra-polished v4
// Staggered entrance · Animated calorie ring · Live prayer · Glass cards
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';
import '../ramadan/ramadan_ui.dart';
import '../../core/prayer_provider.dart';
import '../../data/models/models.dart';
import '../../data/models/user_profile.dart';


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

class HomeScreen extends ConsumerStatefulWidget {
const HomeScreen({super.key});
@override ConsumerState<HomeScreen> createState() => _HomeState();
}

class _HomeState extends ConsumerState<HomeScreen>
with TickerProviderStateMixin {

// ── Stagger controller — drives ALL entrance animations ──
late AnimationController _stagger;

// ── Calorie ring fill ────────────────────────────────────
late AnimationController _ringCtrl;
late Animation<double> _ringVal;
int _lastCals = 0;

// ── Mosque pulse ─────────────────────────────────────────
late AnimationController _mosqueCtrl;
late Animation<double> _mosqueScale;

// ── Hadith breathing dot ─────────────────────────────────
late AnimationController _dotCtrl;

// ── Clock ────────────────────────────────────────────────
Timer? _clock;
DateTime _now = DateTime.now();

static const _prayers = [
{'ar': 'الفجر', 'en': 'Fajr', 'h': 5, 'm': 12},
{'ar': 'الظهر', 'en': 'Dhuhr', 'h': 12, 'm': 18},
{'ar': 'العصر', 'en': 'Asr', 'h': 15, 'm': 42},
{'ar': 'المغرب', 'en': 'Maghrib', 'h': 18, 'm': 5},
{'ar': 'العشاء', 'en': 'Isha', 'h': 19, 'm': 28},
 ];

Map<String, dynamic> _next([List<Map<String,dynamic>>? times]) {
final list = times ?? _prayers;
final cur = _now.hour * 60 + _now.minute;
for (final p in list) {
if ((p['h'] as int) * 60 + (p['m'] as int) > cur) return p;
}
return list[0];
}

String _countdown([List<Map<String,dynamic>>? times]) {
final list = times ?? _prayers;
final cur = _now.hour * 60 + _now.minute;
for (final p in list) {
final t = (p['h'] as int) * 60 + (p['m'] as int);
if (t > cur) {
final d = t - cur;
return d >= 60 ? '${d ~/ 60}h ${(d % 60).toString().padLeft(2,'0')}m' : '${d}m';
}
}
return '--';
}

String _fmtPrayerTime(int h, int m) {
final hh = h > 12 ? h - 12 : h == 0 ? 12 : h;
return '$hh:${m.toString().padLeft(2,'0')}';
}

Map<String, String> get _hadith {
final i = _now.difference(DateTime(_now.year)).inDays;
return {
'ar': kDailyNotes[i % kDailyNotes.length]['ar']!,
'en': kDailyNotes[i % kDailyNotes.length]['en']!,
};
}

// Staggered fade+slide for each card
Animation<double> _fade(int i) => CurvedAnimation(
parent: _stagger,
curve: Interval(i * 0.1, i * 0.1 + 0.55, curve: Curves.easeOut),
);
Animation<Offset> _slide(int i) => Tween<Offset>(
begin: const Offset(0, 0.18), end: Offset.zero,
).animate(CurvedAnimation(
parent: _stagger,
curve: Interval(i * 0.1, i * 0.1 + 0.55, curve: Curves.easeOutCubic),
));

Widget _anim(int i, Widget child) => FadeTransition(
opacity: _fade(i),
child: SlideTransition(position: _slide(i), child: child),
);

@override
void initState() {
super.initState();

_stagger = AnimationController(
vsync: this, duration: const Duration(milliseconds: 950));

_ringCtrl = AnimationController(
vsync: this, duration: const Duration(milliseconds: 900));
_ringVal = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);

_mosqueCtrl = AnimationController(
vsync: this, duration: const Duration(milliseconds: 2200))
..repeat(reverse: true);
_mosqueScale = Tween<double>(begin: 0.92, end: 1.0).animate(
CurvedAnimation(parent: _mosqueCtrl, curve: Curves.easeInOut));

_dotCtrl = AnimationController(
vsync: this, duration: const Duration(milliseconds: 1800))
..repeat(reverse: true);

_stagger.forward();
_ringCtrl.forward();

_clock = Timer.periodic(const Duration(seconds: 30), (_) {
if (mounted) setState(() => _now = DateTime.now());
});
}

@override
void dispose() {
_stagger.dispose();
_ringCtrl.dispose();
_mosqueCtrl.dispose();
_dotCtrl.dispose();
_clock?.cancel();
super.dispose();
}

@override
Widget build(BuildContext context) {
final lang  = ref.watch(languageProvider);
final isAr  = lang == 'ar' || lang == 'ur';
final isDark = ref.watch(themeProvider);
final cals = ref.watch(caloriesProvider);
final water = ref.watch(waterProvider);
final sleep = ref.watch(sleepProvider);
final streak = ref.watch(streakProvider);
final profile = ref.watch(userProfileProvider);
final wMin      = ref.watch(workoutMinutesProvider);
final isRamadan = ref.watch(ramadanModeProvider);

// Animate ring when cals change
if (cals.total != _lastCals) {
_lastCals = cals.total;
_ringCtrl.forward(from: 0.4);
}

final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
final card = isDark ? AppColors.darkCard : AppColors.lightCard;
final border = isDark ? AppColors.darkBorder2 : AppColors.lightBorder;
final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
final text = isDark ? AppColors.darkText : AppColors.lightText;
String t(String ar, String en) => tLang(lang, ar, en);
final l = L.fromLang(lang);

final calCol = cals.total > cals.goal
? AppColors.haramRed
: cals.percent > 0.85
? AppColors.doubtOrange
: AppColors.halalGreen;
final pct = cals.percent.clamp(0.0, 1.0);

return Scaffold(
backgroundColor: bg,
body: CustomScrollView(
physics: const BouncingScrollPhysics(
parent: AlwaysScrollableScrollPhysics()),
slivers: [// ── SLIM APP BAR ──────────────────────────────────
SliverAppBar(
backgroundColor: bg,
surfaceTintColor: Colors.transparent,
elevation: 0,
pinned: false,
floating: true,
snap: true,
toolbarHeight: 52,
title: Row(children: [
// Logo pill
Container(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: isRamadan
    ? [const Color(0xFF7A5010), const Color(0xFFD4A017)]
    : [const Color(0xFF238636), const Color(0xFF3FB950)],
begin: Alignment.topLeft, end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(20),
),
child: Row(mainAxisSize: MainAxisSize.min, children: [
Text(isRamadan ? '🌙' : '🌿', style: const TextStyle(fontSize: 12)),
const SizedBox(width: 5),
const Text('HalalCalorie', style: TextStyle(
fontFamily: 'Cairo', fontSize: 13,
fontWeight: FontWeight.w800, color: Colors.white,
letterSpacing: 0.2,
)),
 ]),
),
]),
actions: [
_IconBtn(
icon: isDark ? '☀' : '☾',
isDark: isDark,
onTap: () {
HapticFeedback.lightImpact();
ref.read(themeProvider.notifier).toggle();
},
),
_IconBtn(
icon: _langLabel(lang),
isDark: isDark,
isText: true,
onTap: () {
HapticFeedback.lightImpact();
ref.read(languageProvider.notifier).set(_nextLang(lang));
},
),
_IconBtn(
icon: '⚙',
isDark: isDark,
onTap: () => context.push('/settings'),
),
const SizedBox(width: 6),
 ],
),

SliverPadding(
padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
sliver: SliverList(delegate: SliverChildListDelegate([

// ── 1 PRAYER CARD ───────────────────────────
Builder(builder: (_) {
  final pt = ref.watch(prayerTimesProvider);
  List<Map<String,dynamic>> livePrayers = _prayers;
  pt.whenData((times) {
    if (times != null) {
      livePrayers = [
        {'ar':'الفجر',  'en':'Fajr',    'h':times.fajr.hour,    'm':times.fajr.minute},
        {'ar':'الظهر',  'en':'Dhuhr',   'h':times.dhuhr.hour,   'm':times.dhuhr.minute},
        {'ar':'العصر',  'en':'Asr',     'h':times.asr.hour,     'm':times.asr.minute},
        {'ar':'المغرب','en':'Maghrib','h':times.maghrib.hour,'m':times.maghrib.minute},
        {'ar':'العشاء', 'en':'Isha',   'h':times.isha.hour,    'm':times.isha.minute},
      ];
    }
  });
  final livNext = _next(livePrayers);
  return _anim(0, _PrayerCard(
    next: livNext, countdown: _countdown(livePrayers),
    prayers: livePrayers,
    fmtTime: _fmtPrayerTime,
    now: _now,
    isAr: isAr, isDark: isDark,
    card: card, border: border, muted: muted,
    mosqueScale: _mosqueScale,
  ));
}),
const SizedBox(height: 12),

// ── RAMADAN HERO ──
if (isRamadan) ...[
  _anim(1, RamadanHero(
    now: _now,
    shimmer: _mosqueScale,
    onLogWater: () {
      HapticFeedback.lightImpact();
      ref.read(waterProvider.notifier).add();
    },
    onOpenNutrition: () => context.go('/nutrition'),
  )),
  const SizedBox(height: 12),
],

// ── Optional fasting-day banner (Mon/Thu) ───────
if (_now.weekday == DateTime.monday ||
    _now.weekday == DateTime.thursday) ...[
  _anim(0, _FastingDayBanner(
      isAr: isAr, isDark: isDark, lang: lang,
      card: card, border: border)),
  const SizedBox(height: 12),
],

// ── 2 CALORIE RING ──────────────────────────
_anim(1, _CalRing(
eaten: cals.total, goal: cals.goal,
remaining: cals.remaining,
pct: pct, calCol: calCol,
proteinTotal: cals.proteinTotal,
carbsTotal: cals.carbsTotal,
fatTotal: cals.fatTotal,
profile: profile,
ringAnim: _ringVal,
isAr: isAr, isDark: isDark, isRamadan: isRamadan, lang: lang,
card: card, border: border, muted: muted, text: text,
onAdd: () => context.push('/food-photo'),
)),
const SizedBox(height: 12),

// ── 3 STATS ROW ─────────────────────────────
_anim(2, _StatsRow(
    lang: lang,
water: water, sleep: sleep,
streak: streak, wMin: wMin,
isAr: isAr, isDark: isDark,
card: card, border: border, muted: muted,
onWater: () {
HapticFeedback.lightImpact();
ref.read(waterProvider.notifier).add();
},
onRemoveWater: () {
if (ref.read(waterProvider).cups > 0) {
  ref.read(waterProvider.notifier).remove();
}
},
onSleep: () => context.go('/health'),
onWorkout: () => context.go('/fitness'),
)),
const SizedBox(height: 12),

// ── ASCENT CARD ─────────────────────────────
_anim(3, _AscentCard(
  isDark: isDark,
  card: card, border: border, muted: muted, text: text,
  onTap: () => context.go('/ascent'),
)),
const SizedBox(height: 12),

// ── 4 HADITH ────────────────────────────────
_anim(4, _HadithCard(
hadith: _hadith, isAr: isAr, isDark: isDark,
card: card, border: border, muted: muted, text: text,
dotAnim: _dotCtrl,
)),
const SizedBox(height: 12),

// ── 5 QUICK ACTIONS ─────────────────────────
_anim(5, _QuickGrid(
    lang: lang,
isAr: isAr, isDark: isDark,
card: card, border: border, text: text, muted: muted,
onTap: (r) {
HapticFeedback.lightImpact();
final needsPush = r == '/food-photo' || r == '/body-photo'
|| r == '/paywall' || r == '/body';
if (needsPush) context.push(r); else context.go(r);
},
)),

// ── MEDICAL DISCLAIMER ──────────────────────────────
_MedDisclaimer(isAr: isAr),

])),
),
],
),
);
}
}

// ════════════════════════════════════════════════════════════
// MEDICAL DISCLAIMER — required by Google Play Health policy
// ════════════════════════════════════════════════════════════
class _MedDisclaimer extends StatelessWidget {
  final bool isAr;
  const _MedDisclaimer({required this.isAr});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D), width: 0.5),
      ),
      child: Text(
        isAr
          ? '⚕️ هذا التطبيق لأغراض المعلومات العامة فقط وليس بديلاً عن الاستشارة الطبية المتخصصة. استشر طبيبك أو أخصائياً معتمداً قبل اتخاذ أي قرارات صحية.'
          : '⚕️ This app is for general informational purposes only and is not a substitute for professional medical advice, diagnosis or treatment. Always consult a qualified healthcare professional before making health decisions.',
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          color: Color(0xFF8B949E),
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// PRAYER CARD
// ════════════════════════════════════════════════════════════
class _PrayerCard extends ConsumerWidget {
final Map next;
final String countdown;
final List prayers;
final String Function(int, int) fmtTime;
final DateTime now;
final bool isAr, isDark;
final Color card, border, muted;
final Animation<double> mosqueScale;
const _PrayerCard({
required this.next, required this.countdown,
required this.prayers, required this.fmtTime, required this.now,
required this.isAr, required this.isDark,
required this.card, required this.border, required this.muted,
required this.mosqueScale,
});

bool _isPast(int h, int m) =>
h * 60 + m < now.hour * 60 + now.minute;

bool _isNext(int h, int m) {
final cur = now.hour * 60 + now.minute;
for (final p in prayers) {
final t = (p['h'] as int) * 60 + (p['m'] as int);
if (t > cur) return (p['h'] as int) == h && (p['m'] as int) == m;
}
return false;
}

@override
Widget build(BuildContext context, WidgetRef ref) {
final lang     = ref.watch(languageProvider);
final h = next['h'] as int;
final m = next['m'] as int;
final nm = isAr ? next['ar'] as String : next['en'] as String;

return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: card,
borderRadius: BorderRadius.circular(14),
border: Border.all(color: border, width: 0.5),
),
child: Column(children: [
Row(children: [
// Pulsing mosque
ScaleTransition(
scale: mosqueScale,
child: Container(
width: 48, height: 48,
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [Color(0xFF238636), Color(0xFF3FB950)],
begin: Alignment.topLeft, end: Alignment.bottomRight,
),
borderRadius: BorderRadius.circular(12),
boxShadow: [BoxShadow(
color: AppColors.brandGreen.withOpacity(0.4),
blurRadius: 12, spreadRadius: 0,
)],
),
child: const Center(
child: Text('🕌', style: TextStyle(fontSize: 22))),
),
),
const SizedBox(width: 12),
Expanded(child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(tLang(lang, 'الصلاة القادمة', 'Next Prayer', 'Prochaine prière', 'Sonraki Namaz', 'Solat Seterusnya', 'Shalat Berikutnya'),
style: TextStyle(fontFamily: 'Cairo',
fontSize: 11, color: muted)),
Text(nm, style: const TextStyle(
fontFamily: 'Cairo', fontSize: 20,
fontWeight: FontWeight.w900, color: AppColors.halalGreen,
)),
 ],
)),
// Countdown chip
Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
decoration: BoxDecoration(
color: AppColors.brandGreen.withOpacity(0.1),
borderRadius: BorderRadius.circular(24),
border: Border.all(
color: AppColors.brandGreen.withOpacity(0.3), width: 0.5),
),
child: Text(countdown, style: const TextStyle(
fontFamily: 'Cairo', fontSize: 14,
fontWeight: FontWeight.w900, color: AppColors.halalGreen,
)),
),
]),

Padding(
padding: const EdgeInsets.symmetric(vertical: 12),
child: Divider(color: border, height: 0.5, thickness: 0.5),
),

// 5 prayer times
Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
children: prayers.map((p) {
final ph = p['h'] as int;
final pm = p['m'] as int;
final past = _isPast(ph, pm);
final active = _isNext(ph, pm);
final name = isAr ? p['ar'] as String : p['en'] as String;
final col = active ? AppColors.halalGreen
: past ? muted.withOpacity(0.35)
: (isDark ? AppColors.darkText : AppColors.lightText);

return Column(children: [
Text(name, style: TextStyle(
fontFamily: 'Cairo', fontSize: 9,
fontWeight: active ? FontWeight.w800 : FontWeight.w400,
color: col,
)),
const SizedBox(height: 3),
Text(fmtTime(ph, pm), style: TextStyle(
fontFamily: 'Cairo', fontSize: 11,
fontWeight: active ? FontWeight.w900 : FontWeight.w400,
color: col,
)),
const SizedBox(height: 4),
AnimatedContainer(
duration: const Duration(milliseconds: 300),
width: active ? 16 : 3,
height: 2.5,
decoration: BoxDecoration(
color: active ? AppColors.halalGreen : Colors.transparent,
borderRadius: BorderRadius.circular(2),
),
),
 ]);
}).toList(),
),
]),
);
}
}

// ════════════════════════════════════════════════════════════
// CALORIE RING
// ════════════════════════════════════════════════════════════
class _CalRing extends StatelessWidget {
final int eaten, goal, remaining;
final double pct, proteinTotal, carbsTotal, fatTotal;
final Color calCol, card, border, muted, text;
final bool isAr, isDark, isRamadan;
final String lang;
final UserProfile? profile;
final Animation<double> ringAnim;
final VoidCallback onAdd;
const _CalRing({
required this.eaten, required this.goal, required this.remaining,
required this.pct, required this.calCol,
required this.proteinTotal, required this.carbsTotal,
required this.fatTotal, required this.profile,
required this.ringAnim, required this.isAr, required this.isDark,
required this.isRamadan, required this.lang,
required this.card, required this.border, required this.muted,
required this.text, required this.onAdd,
});

@override
Widget build(BuildContext context) {
String t(String ar, String en) => tLang(lang, ar, en);
return Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: card,
borderRadius: BorderRadius.circular(14),
border: Border.all(color: border, width: 0.5),
),
child: Column(children: [
// Header
Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
Text(t('سعرات اليوم', "Today's Calories"),
style: TextStyle(fontFamily: 'Cairo',
fontSize: 13, fontWeight: FontWeight.w700, color: text)),
GestureDetector(
onTap: onAdd,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
decoration: BoxDecoration(
color: AppColors.brandGreen,
borderRadius: BorderRadius.circular(20),
),
child: Row(mainAxisSize: MainAxisSize.min, children: [
const Icon(Icons.add_rounded, color: Colors.white, size: 13),
const SizedBox(width: 3),
Text(t('أضف', 'Add'), style: const TextStyle(
fontFamily: 'Cairo', fontSize: 11,
fontWeight: FontWeight.w800, color: Colors.white,
)),
 ]),
),
),
]),
const SizedBox(height: 18),

Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
// ── Animated ring ──
AnimatedBuilder(
animation: ringAnim,
builder: (_, __) => CustomPaint(
size: const Size(120, 120),
painter: _RingPainter(
pct: pct * ringAnim.value,
color: calCol,
isDark: isDark,
),
child: SizedBox(
width: 120, height: 120,
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
TweenAnimationBuilder<int>(
tween: IntTween(begin: 0, end: eaten),
duration: const Duration(milliseconds: 800),
curve: Curves.easeOutCubic,
builder: (_, v, __) => Text('`$v',
style: TextStyle(
fontFamily: 'Cairo', fontSize: 26,
fontWeight: FontWeight.w900, color: calCol, height: 1,
)),
),
Text(t('مأكول', 'eaten'), style: TextStyle(
fontFamily: 'Cairo', fontSize: 9, color: muted)),
 ],
),
),
),
),

const SizedBox(width: 20),

// ── Right column ──
Expanded(child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_KvRow(t('المتبقي','Left'), '$remaining', calCol, muted),
const SizedBox(height: 14),
// Macro bars
_MacroBar(t('P','P'), proteinTotal,
profile?.proteinGrams ?? 50, AppColors.halalGreen),
const SizedBox(height: 5),
_MacroBar(t('C','C'), carbsTotal,
(profile?.calorieGoalKcal ?? 2000) / 4, AppColors.waterBlue),
const SizedBox(height: 5),
_MacroBar(t('F','F'), fatTotal,
(profile?.calorieGoalKcal ?? 2000) / 9 * 0.3, AppColors.accentGold),
 ],
)),
]),
// ── Prophet's 1/3 rule hint ───────────────────────────
if (pct >= 0.90)
  Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (isRamadan ? AppColors.accentGold : AppColors.brandGreen).withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: (isRamadan ? AppColors.accentGold : AppColors.brandGreen).withOpacity(0.2)),
      ),
      child: Text(
        t('اترك في معدتك مساحة — ثلث طعام وثلث شراب وثلث فراغ',
          'Leave room in the stomach: a third food, a third drink, a third air'),
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 10,
          color: AppColors.brandGreen,
          fontWeight: FontWeight.w600, height: 1.4),
        textAlign: TextAlign.center,
      ),
    ),
  ),
]),
);
}
}

// ════════════════════════════════════════════════════════════
// SUNNAH FAST BANNER
// ════════════════════════════════════════════════════════════
class _FastingDayBanner extends ConsumerWidget {
  final bool isAr, isDark;
  final String lang;
  final Color card, border;
  const _FastingDayBanner({
    required this.isAr, required this.isDark,
    required this.lang,
    required this.card, required this.border,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    String t(String ar, String en) => tLang(lang, ar, en);
    final dayName = DateTime.now().weekday == DateTime.monday
      ? t('الاثنين', 'Monday') : t('الخميس', 'Thursday');
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.accentGold.withOpacity(0.35), width: 1),
      ),
      child: Row(children: [
        const Text('🌙', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            t('يوم صيام سنة — $dayName 🌿',
              'Fasting day — $dayName 🌿'),
            style: const TextStyle(
              fontFamily: 'Cairo', fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.accentGold),
          ),
          Text(
            t('الاثنين والخميس أشهر يومَي صيام تطوّعي',
              'Monday and Thursday are the usual voluntary fasting days'),
            style: const TextStyle(
              fontFamily: 'Cairo', fontSize: 11,
              color: AppColors.accentGold, height: 1.4),
          ),
        ])),
        const Text('✨', style: TextStyle(fontSize: 16)),
      ]),
    );
  }
}


class _KvRow extends StatelessWidget {
final String label, value;
final Color valueColor, muted;
const _KvRow(this.label, this.value, this.valueColor, this.muted);
@override
Widget build(BuildContext context) => Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: muted)),
Text(value, style: TextStyle(
fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: valueColor)),
 ],
);
}

class _MacroBar extends StatelessWidget {
final String label;
final double val, max;
final Color color;
const _MacroBar(this.label, this.val, this.max, this.color);
@override
Widget build(BuildContext context) => Row(children: [
SizedBox(width: 14, child: Text(label, style: TextStyle(
fontFamily: 'Cairo', fontSize: 9, fontWeight: FontWeight.w800, color: color))),
const SizedBox(width: 6),
Expanded(child: ClipRRect(
borderRadius: BorderRadius.circular(3),
child: LinearProgressIndicator(
value: max > 0 ? (val / max).clamp(0.0, 1.0) : 0,
minHeight: 4,
color: color,
backgroundColor: color.withOpacity(0.1),
),
)),
const SizedBox(width: 6),
Text('${val.toInt()}g', style: TextStyle(
fontFamily: 'Cairo', fontSize: 9, color: color, fontWeight: FontWeight.w700)),
 ]);
}

// Custom ring painter with glow
class _RingPainter extends CustomPainter {
final double pct;
final Color color;
final bool isDark;
const _RingPainter({required this.pct, required this.color, required this.isDark});

@override
void paint(Canvas canvas, Size size) {
final cx = size.width / 2;
final cy = size.height / 2;
final r = size.width / 2 - 10;
const sw = 9.0;

// Track
final trackPaint = Paint()
..color = isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF)
..strokeWidth = sw
..style = PaintingStyle.stroke
..strokeCap = StrokeCap.round;
canvas.drawCircle(Offset(cx, cy), r, trackPaint);

if (pct <= 0) return;

// Glow
final glowPaint = Paint()
..color = color.withOpacity(0.25)
..strokeWidth = sw + 6
..style = PaintingStyle.stroke
..strokeCap = StrokeCap.round
..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
canvas.drawArc(
Rect.fromCircle(center: Offset(cx, cy), radius: r),
-pi / 2, 2 * pi * pct, false, glowPaint,
);

// Main arc
final arcPaint = Paint()
..shader = SweepGradient(
startAngle: -pi / 2,
endAngle: -pi / 2 + 2 * pi * pct,
colors: [color.withOpacity(0.7), color],
).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
..strokeWidth = sw
..style = PaintingStyle.stroke
..strokeCap = StrokeCap.round;
canvas.drawArc(
Rect.fromCircle(center: Offset(cx, cy), radius: r),
-pi / 2, 2 * pi * pct, false, arcPaint,
);

// End dot
if (pct > 0.02) {
final angle = -pi / 2 + 2 * pi * pct;
final dotX = cx + r * cos(angle);
final dotY = cy + r * sin(angle);
canvas.drawCircle(Offset(dotX, dotY), 5,
Paint()..color = color);
}
}

@override bool shouldRepaint(_RingPainter old) =>
old.pct != pct || old.color != color;
}

// ════════════════════════════════════════════════════════════
// STATS ROW
// ════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
final String lang;
final WaterState water;
final SleepState sleep;
final int streak, wMin;
final bool isAr, isDark;
final Color card, border, muted;
final VoidCallback onWater, onSleep, onWorkout;
final VoidCallback? onRemoveWater;
const _StatsRow({
required this.lang,
required this.water, required this.sleep,
required this.streak, required this.wMin,
required this.isAr, required this.isDark,
required this.card, required this.border, required this.muted,
required this.onWater, required this.onSleep, required this.onWorkout,
this.onRemoveWater,
});

@override
Widget build(BuildContext context) => Row(children: [
_Stat(
emoji: '💧',
value: '${water.cups}', total: '/${water.goal}',
label: tLang(lang, 'ماء', 'Water', 'Eau', 'Su', 'Air', 'Air'),
color: AppColors.waterBlue,
pct: water.percent,
isDark: isDark, card: card, border: border, muted: muted,
onTap: onWater,
onLongPress: onRemoveWater,
),
const SizedBox(width: 10),
_Stat(
emoji: '😴',
value: '${sleep.hours.toInt()}', total: '/${sleep.goal.toInt()}h',
label: tLang(lang, 'نوم', 'Sleep', 'Sommeil', 'Uyku', 'Tidur', 'Tidur'),
color: AppColors.sleepPurple,
pct: sleep.percent,
isDark: isDark, card: card, border: border, muted: muted,
onTap: onSleep,
),
const SizedBox(width: 10),
_Stat(
emoji: '🔥',
value: '$streak',
total: tLang(lang, ' يوم', 'd', 'd', 'd', 'd', 'd'),
label: tLang(lang, 'تتابع', 'Streak', 'Série', 'Seri', 'Streak', 'Streak'),
color: AppColors.haramRed,
pct: (streak / 30).clamp(0.0, 1.0),
isDark: isDark, card: card, border: border, muted: muted,
onTap: () => _showStreakDialog(context, streak, isAr, lang, card, border),
),
const SizedBox(width: 10),
_Stat(
emoji: '🏃',
value: wMin > 0 ? '$wMin' : '0',
total: tLang(lang, 'د', 'm', 'm', 'm', 'm', 'm'),
label: tLang(lang, 'تمرين', 'Workout', 'Entraînement', 'Antrenman', 'Senaman', 'Olahraga'),
color: AppColors.halalGreen,
pct: (wMin / 30).clamp(0.0, 1.0),
isDark: isDark, card: card, border: border, muted: muted,
onTap: onWorkout,
),
 ]);
}

class _Stat extends StatefulWidget {
final String emoji, value, total, label;
final Color color, card, border, muted;
final double pct;
final bool isDark;
final VoidCallback onTap;
final VoidCallback? onLongPress;
const _Stat({
required this.emoji, required this.value, required this.total,
required this.label, required this.color, required this.pct,
required this.isDark, required this.card, required this.border,
required this.muted, required this.onTap, this.onLongPress,
});
@override State<_Stat> createState() => _StatState();
}

class _StatState extends State<_Stat> with SingleTickerProviderStateMixin {
late AnimationController _press;
@override
void initState() {
super.initState();
_press = AnimationController(vsync: this,
duration: const Duration(milliseconds: 110),
lowerBound: 0.93, upperBound: 1.0, value: 1.0);
}
@override void dispose() { _press.dispose(); super.dispose(); }

@override
Widget build(BuildContext context) {
return Expanded(child: GestureDetector(
onTapDown: (_) => _press.reverse(),
onTapUp: (_) { _press.forward(); widget.onTap(); },
onTapCancel: () => _press.forward(),
onLongPress: widget.onLongPress != null ? () {
  HapticFeedback.mediumImpact();
  widget.onLongPress!();
} : null,
child: AnimatedBuilder(
animation: _press,
builder: (_, child) => Transform.scale(scale: _press.value, child: child),
child: Container(
padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
decoration: BoxDecoration(
color: widget.card,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: widget.border, width: 0.5),
),
child: Column(children: [
Text(widget.emoji, style: const TextStyle(fontSize: 18)),
const SizedBox(height: 5),
RichText(text: TextSpan(children: [
TextSpan(text: widget.value, style: TextStyle(
fontFamily: 'Cairo', fontSize: 15,
fontWeight: FontWeight.w900, color: widget.color,
)),
TextSpan(text: widget.total, style: TextStyle(
fontFamily: 'Cairo', fontSize: 10, color: widget.muted,
)),
 ])),
const SizedBox(height: 4),
ClipRRect(
borderRadius: BorderRadius.circular(3),
child: LinearProgressIndicator(
value: widget.pct, minHeight: 3,
color: widget.color,
backgroundColor: widget.color.withOpacity(0.1),
),
),
const SizedBox(height: 4),
Text(widget.label, style: TextStyle(
fontFamily: 'Cairo', fontSize: 9, color: widget.muted)),
]),
),
),
));
}
}

// ════════════════════════════════════════════════════════════
// STREAK DIALOG
// ════════════════════════════════════════════════════════════
void _showStreakDialog(BuildContext context, int streak, bool isAr, String lang, Color card, Color border) {
  final msg = streak == 0
    ? (tLang(lang, 'ابدأ يومك بتسجيل وجبة! 💪', 'Log a meal today to start your streak! 💪', 'Enregistrez un repas aujourd\'hui pour démarrer votre série ! 💪', 'Serinizi başlatmak için bugün öğün kaydedin! 💪', 'Log makanan hari ini untuk mulakan streak! 💪', 'Catat makan hari ini untuk mulai streak! 💪'))
    : streak < 7
    ? (tLang(lang, 'رائع! استمر للحصول على أسبوع كامل 🌟', 'Great start! Keep going for a full week 🌟', 'Bon début ! Continuez une semaine complète 🌟', 'Harika başlangıç! Tam bir hafta devam et 🌟', 'Permulaan hebat! Teruskan seminggu penuh 🌟', 'Awal yang bagus! Teruskan seminggu penuh 🌟'))
    : streak < 30
    ? (isAr ? 'أنت على المسار الصحيح! 🔥' : "You're on fire! 🔥")
    : (tLang(lang, 'مبارك! تتابع رائع جداً 🏆', 'Masha Allah! Incredible streak 🏆', 'Masha Allah ! Série incroyable 🏆', 'Maşaallah! İnanılmaz seri 🏆', 'Masha Allah! Streak yang luar biasa 🏆', 'Masha Allah! Streak yang luar biasa 🏆'));
  showDialog(context: context, builder: (_) => Dialog(
    backgroundColor: card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: border)),
    child: Padding(padding: const EdgeInsets.all(28), child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        const Text('🔥', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text('$streak', style: const TextStyle(
          fontFamily: 'Cairo', fontSize: 48,
          fontWeight: FontWeight.w900, color: AppColors.haramRed)),
        Text(tLang(lang, 'يوم تتابع', 'day streak', 'jours de suite', 'günlük seri', 'hari berturut', 'hari berturut'), style: const TextStyle(
          fontFamily: 'Cairo', fontSize: 14, color: AppColors.haramRed)),
        const SizedBox(height: 16),
        Text(msg, textAlign: TextAlign.center, style: const TextStyle(
          fontFamily: 'Cairo', fontSize: 13, height: 1.5)),
        const SizedBox(height: 20),
        if (streak > 0) LinearProgressIndicator(
          value: (streak % 30) / 30,
          color: AppColors.haramRed,
          backgroundColor: AppColors.haramRed.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
        if (streak > 0) Padding(padding: const EdgeInsets.only(top: 6),
          child: Text(tLang(lang, '${streak % 30}/30 يوم للجائزة التالية 🎁', '${streak % 30}/30 days to next milestone 🎁', '${streak % 30}/30 days to next milestone 🎁', '${streak % 30}/30 days to next milestone 🎁', '${streak % 30}/30 days to next milestone 🎁', '${streak % 30}/30 days to next milestone 🎁'),
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 10,
              color: AppColors.haramRed))),
        const SizedBox(height: 16),
        TextButton(onPressed: () => Navigator.pop(context),
          child: Text(tLang(lang, 'حسناً 👍', 'Got it 👍', 'Compris 👍', 'Anlaşıldı 👍', 'Faham 👍', 'Mengerti 👍'),
            style: const TextStyle(fontFamily: 'Cairo',
              color: AppColors.brandGreen, fontWeight: FontWeight.w700))),
      ],
    )),
  ));
}

// ════════════════════════════════════════════════════════════
// HADITH CARD
// ════════════════════════════════════════════════════════════
class _HadithCard extends StatelessWidget {
final Map<String, String> hadith;
final bool isAr, isDark;
final Color card, border, muted, text;
final AnimationController dotAnim;
const _HadithCard({
required this.hadith, required this.isAr, required this.isDark,
required this.card, required this.border, required this.muted,
required this.text, required this.dotAnim,
});

@override
Widget build(BuildContext context) {
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: card,
borderRadius: BorderRadius.circular(14),
border: Border.all(color: border, width: 0.5),
),
child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
// Green left bar
Container(
width: 3, height: 56,
margin: const EdgeInsets.only(top: 2),
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [AppColors.brandGreen, AppColors.accentGold],
begin: Alignment.topCenter, end: Alignment.bottomCenter,
),
borderRadius: BorderRadius.circular(3),
),
),
const SizedBox(width: 12),
Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(children: [
Text(isAr ? '📖 كلمة اليوم' : '📖 Note of the day',
style: const TextStyle(fontFamily: 'Cairo',
fontSize: 10, fontWeight: FontWeight.w700,
color: AppColors.brandGreen)),
const Spacer(),
// Breathing dot
AnimatedBuilder(
animation: dotAnim,
builder: (_, __) {
final v = (dotAnim.value + 1) / 2;
return Container(
width: 6, height: 6,
decoration: BoxDecoration(
color: AppColors.brandGreen.withOpacity(0.4 + 0.6 * v),
shape: BoxShape.circle,
boxShadow: [BoxShadow(
color: AppColors.brandGreen.withOpacity(0.3 * v),
blurRadius: 6,
)],
),
);
},
),
]),
const SizedBox(height: 7),
Text(
isAr ? hadith['ar']! : hadith['en']!,
style: TextStyle(
fontFamily: 'Cairo',
fontSize: isAr ? 13 : 12,
height: 1.65, fontStyle: FontStyle.italic,
color: text,
),
),
],
)),
]),
);
}
}

// ════════════════════════════════════════════════════════════
// ASCENT CARD — level, rank and today's quest progress
// ════════════════════════════════════════════════════════════
class _AscentCard extends ConsumerWidget {
  final bool isDark;
  final Color card, border, muted, text;
  final VoidCallback onTap;
  const _AscentCard({required this.isDark,
    required this.card, required this.border, required this.muted,
    required this.text, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ascent = ref.watch(ascentProvider);
    final lang   = ref.watch(languageProvider);
    final l      = L.fromLang(lang);
    final col    = ascent.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: col.withOpacity(0.35), width: 1.2),
          boxShadow: [BoxShadow(
            color: col.withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 18, offset: const Offset(0, 5))],
        ),
        child: Column(children: [
          Row(children: [
            // Rank chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: col.withOpacity(0.55), width: 1.1),
                borderRadius: BorderRadius.circular(6)),
              child: Text(ascent.rank.letter,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
                    fontWeight: FontWeight.w900, color: col)),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(l.ascentHomeCard,
              style: TextStyle(fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800, fontSize: 14, color: text))),
            Text('${l.levelShort} ${ascent.level}',
              style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 12, fontWeight: FontWeight.w800, color: col)),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 12, color: muted),
          ]),
          const SizedBox(height: 12),
          // Quest pips — one per daily quest
          Row(children: kQuests.map((q) {
            final done = ascent.isDone(q.id);
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                height: 6,
                decoration: BoxDecoration(
                  color: done
                      ? q.color
                      : q.color.withOpacity(
                          ascent.points(q.id) > 0 ? 0.35 : 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ));
          }).toList()),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${ascent.questsDone}/${kQuests.length} ${l.questsLabel}'
                 '  ·  ${ascent.score}/1000',
              style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 11, color: col, fontWeight: FontWeight.w700)),
            Text(ascent.chain > 0 ? '🔥 ${ascent.chain}' : '+${ascent.todayXp} XP',
              style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 11, color: muted)),
          ]),
        ]),
      ),
    );
  }
}

// QUICK GRID
// ════════════════════════════════════════════════════════════
class _QuickGrid extends StatelessWidget {
final String lang;
final bool isAr, isDark;
final Color card, border, text, muted;
final void Function(String) onTap;
const _QuickGrid({
required this.lang,
required this.isAr, required this.isDark,
required this.card, required this.border,
required this.text, required this.muted, required this.onTap,
});

@override
Widget build(BuildContext context) {
final items = [
_Q('📸', tLang(lang, 'صوّر طعامك', 'Photo Food', 'Photo alimentaire', 'Fotoğraflı Yiyecek', 'Foto Makanan', 'Foto Makanan'),
tLang(lang, 'AI يحلل فوراً', 'AI instant', 'IA instantanée', 'Anlık AI', 'AI Segera', 'AI Instan'), '/food-photo',
const Color(0xFF238636)),
_Q('📷', tLang(lang, 'باركود', 'Barcode', 'Code-barres', 'Barkod', 'Kod Bar', 'Barcode'),
tLang(lang, 'فحص الحلال', 'Halal check', 'Vérification halal', 'Helal kontrol', 'Semakan halal', 'Cek halal'), '/scanner',
const Color(0xFF1F6FEB)),
_Q('🏃', tLang(lang, 'تمارين', 'Workouts', 'Entraînements', 'Antrenmanlar', 'Senaman', 'Olahraga'),
tLang(lang, '١٨٠ خطة', '180 plans', '180 plans', '180 plan', '180 rancangan', '180 rencana'), '/fitness',
const Color(0xFF8957E5)),
_Q('💪', tLang(lang, 'مقاييس', 'Body', 'Corps', 'Vücut', 'Badan', 'Tubuh'),
tLang(lang, 'BMI وأكثر', 'BMI & more', 'IMC & plus', 'VKİ & daha fazlası', 'BMI & lagi', 'IMT & lebih'), '/body',
const Color(0xFFBF8700)),
 ];

return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
Text(tLang(lang, 'ابدأ الآن', 'Quick Actions', 'Actions rapides', 'Hızlı İşlemler', 'Tindakan Pantas', 'Tindakan Cepat'),
style: TextStyle(fontFamily: 'Cairo',
fontSize: 13, fontWeight: FontWeight.w700, color: muted)),
const SizedBox(height: 10),
Row(children: items.map((item) => Expanded(
child: Padding(
padding: EdgeInsets.only(
right: item == items.last ? 0 : 8),
child: _QTile(
item: item, isDark: isDark,
card: card, border: border, text: text,
onTap: () => onTap(item.route),
),
),
)).toList()),
 ]);
}
}

class _Q {
final String emoji, title, sub, route;
final Color color;
const _Q(this.emoji, this.title, this.sub, this.route, this.color);
}

class _QTile extends StatefulWidget {
final _Q item;
final bool isDark;
final Color card, border, text;
final VoidCallback onTap;
const _QTile({required this.item, required this.isDark,
required this.card, required this.border,
required this.text, required this.onTap});
@override State<_QTile> createState() => _QTileState();
}

class _QTileState extends State<_QTile> with SingleTickerProviderStateMixin {
late AnimationController _c;
@override void initState() {
super.initState();
_c = AnimationController(vsync: this,
duration: const Duration(milliseconds: 100),
lowerBound: 0.92, upperBound: 1.0, value: 1.0);
}
@override void dispose() { _c.dispose(); super.dispose(); }

@override
Widget build(BuildContext context) {
final item = widget.item;
return GestureDetector(
onTapDown: (_) => _c.reverse(),
onTapUp: (_) { _c.forward(); widget.onTap(); },
onTapCancel: () => _c.forward(),
child: AnimatedBuilder(
animation: _c,
builder: (_, child) => Transform.scale(scale: _c.value, child: child),
child: Container(
padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
decoration: BoxDecoration(
color: widget.card,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: widget.border, width: 0.5),
),
child: Column(children: [
Container(
width: 36, height: 36,
decoration: BoxDecoration(
color: item.color.withOpacity(0.12),
borderRadius: BorderRadius.circular(9),
),
child: Center(child: Text(item.emoji,
style: const TextStyle(fontSize: 17))),
),
const SizedBox(height: 7),
Text(item.title, style: TextStyle(
fontFamily: 'Cairo', fontSize: 11,
fontWeight: FontWeight.w700, color: widget.text),
textAlign: TextAlign.center,
maxLines: 1, overflow: TextOverflow.ellipsis),
const SizedBox(height: 2),
Text(item.sub, style: TextStyle(
fontFamily: 'Cairo', fontSize: 9,
color: item.color),
textAlign: TextAlign.center,
maxLines: 1),
 ]),
),
),
);
}
}

// ════════════════════════════════════════════════════════════
// ICON BUTTON
// ════════════════════════════════════════════════════════════
class _IconBtn extends StatelessWidget {
final String icon;
final bool isDark;
final bool isText;
final VoidCallback onTap;
const _IconBtn({required this.icon, required this.isDark,
this.isText = false, required this.onTap});

@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: onTap,
child: Container(
margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
width: 34, height: 34,
decoration: BoxDecoration(
color: isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA),
borderRadius: BorderRadius.circular(8),
border: Border.all(
color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
width: 0.5),
),
child: Center(child: Text(icon, style: TextStyle(
fontFamily: isText ? 'Cairo' : null,
fontSize: isText ? 11 : 15,
fontWeight: isText ? FontWeight.w800 : null,
color: isDark ? AppColors.darkText : AppColors.lightText,
))),
),
);
}
}
