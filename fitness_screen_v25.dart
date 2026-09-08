// fitness_screen.dart
// PATCH_V25_PLAYER_HEALTH — HalalCalorie v1.0
// 23 workouts, category tabs, Ramadan mode, step-by-step player
import 'dart:async'; import'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:go_router/go_router.dart'; import'../../core/theme.dart'; import'../../core/providers.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import 'lift_screen.dart'; import'../../data/models/models.dart'; import '../../data/muscle_assets.dart'; import '../../data/icon_assets.dart';

// ══════════════════════════════════════════════════
//  FitnessScreen
// ══════════════════════════════════════════════════
class FitnessScreen extends ConsumerStatefulWidget {
  const FitnessScreen({super.key});
  @override ConsumerState<FitnessScreen> createState() => _FitnessState();
}

class _FitnessState extends ConsumerState<FitnessScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab; String _filter ='all';
  late AnimationController _stagger;
  Animation<double> _fade(int i) => CurvedAnimation(
      parent: _stagger,
      curve: Interval(i * 0.09, (i * 0.09 + 0.5).clamp(0,1), curve: Curves.easeOutQuart));
  Animation<Offset> _slide(int i) => Tween<Offset>(
      begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(
      parent: _stagger,
      curve: Interval(i * 0.09, (i * 0.09 + 0.5).clamp(0,1), curve: Curves.easeOutQuart)));
  Widget _anim(int i, Widget child) => FadeTransition(
      opacity: _fade(i), child: SlideTransition(position: _slide(i), child: child));
 static const _cats = ['all','walking','strength','gentle','ramadan','breathing','family'];

  @override void initState() {
    super.initState();
    _tab = TabController(length: _cats.length, vsync: this);
    _tab.addListener(() => setState(() => _filter = _cats[_tab.index]));
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
  }
  @override void dispose() { _tab.dispose(); _stagger.dispose(); super.dispose(); }

  List<Workout> _filtered(String gender, bool isRamadan, bool isPremium) { var list = kWorkouts.where((w) => w.gender =='both'|| w.gender == gender).toList();
    if (isRamadan) {
      // Put Ramadan workouts first
      list.sort((a, b) { final aR = a.category =='ramadan'? 0 : 1; final bR = b.category =='ramadan'? 0 : 1;
        return aR.compareTo(bR);
      });
    } if (_filter !='all') list = list.where((w) => w.category == _filter).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final gender    = ref.watch(genderProvider);
    final lang      = ref.watch(languageProvider);
    final isAr      = lang == 'ar' || lang == 'ur';
    final isDark    = ref.watch(themeProvider);
    final isPremium = ref.watch(premiumProvider);
    final isRamadan = ref.watch(ramadanModeProvider);
    final workoutMin = ref.watch(workoutMinutesProvider); final isSis     = gender =='sisters';
    final barCol    = isSis ? AppColors.accentGold : AppColors.brandGreen;
    final barGrad   = isSis ? AppColors.gradientGold : AppColors.gradientGreen;
    final bg        = isDark ? AppColors.darkBg   : AppColors.lightBg;
    final card      = isDark ? AppColors.darkCard : Colors.white;
    final muted     = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final l         = L.fromLang(lang);

    final workouts = _filtered(gender, isRamadan, isPremium);

    String t(String ar, String en) => l.t(ar, en);

    final catLabels = { 'all':       t('الكل', 'All'), 'walking':   t('مشي', 'Walk'), 'strength':  t('قوة', 'Strength'), 'gentle':    t('لطيف', 'Gentle'), 'ramadan':   t('رمضان', 'Ramadan'), 'breathing': t('تنفس', 'Breathe'), 'family':    t('عائلة', 'Family'),
    };

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isRamadan && !isSis
                    ? [AppColors.ramadanNight, AppColors.ramadanCard]
                    : isSis
                        ? [const Color(0xFFB8860B), const Color(0xFFDAA520)]
                        : [const Color(0xFF1A6B3C), AppColors.brandGreen],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          // PATCH_V24_FITNESS_REMASTER
          backgroundColor: Colors.transparent,
          title: Text(l.fitnessTitle,
              style: const TextStyle(fontFamily: 'Bravoon',
                  fontWeight: FontWeight.w400, fontSize: 26, color: Colors.white)),
          actions: [
            if (workoutMin > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🔥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text('$workoutMin ${t("د","min")}',
                        style: const TextStyle(fontFamily: 'Aligarh',
                            fontSize: 12, color: Colors.white,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: AppColors.accentGold,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontFamily: 'Aligarh',
                fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Aligarh',
                fontSize: 13),
            tabAlignment: TabAlignment.start,
            tabs: _cats.map((c) => Tab(text: catLabels[c] ?? c)).toList(),
          ),
        ),
        body: Column(children: [
          // Mode banner
          if (isRamadan || isSis)
            Container(
              color: (isRamadan && !isSis ? AppColors.ramadanGold : isSis ? AppColors.accentGold : AppColors.darkGreen).withOpacity(0.10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [ Text(isSis ?'🧕' : '🌙', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  isSis && isRamadan ? t('وضع النساء + رمضان — تمارين محتشمة وخفيفة', 'Women + Ramadan — modest and light sessions')
                      : isRamadan ? l.ramadanModeLabel : t('وضع النساء — تمارين محتشمة', 'Women mode — modest sessions'), style: TextStyle(fontFamily:'Aligarh', fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isRamadan && !isSis ? AppColors.ramadanGold : isSis ? AppColors.accentGold : AppColors.brandGreen),
                )),
              ]),
            ),

          // ── Ranked lifting entry — PATCH_V24 ─────────────
          Reveal(
            index: 0,
            child: Consumer(builder: (ctx, r, __) {
              final rank = r.watch(liftLogProvider).overall;
              final ranked = r.watch(liftLogProvider).bests.length;
              return PressFx(
                onTap: () => ctx.push('/lift'),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: rank.color.withOpacity(0.40), width: 1.4),
                    boxShadow: [
                      BoxShadow(
                          color: rank.color.withOpacity(0.18),
                          blurRadius: 22,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(children: [
                    RankBadge(rank: rank, size: 58, arabic: l.isAr),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.strengthCardTitle,
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText)),
                            const SizedBox(height: 4),
                            Text(
                                ranked == 0
                                    ? l.notRankedYet
                                    : '${rank.label(arabic: l.isAr)} · '
                                        '$ranked/${kLiftExercises.length} '
                                        '${l.liftsRanked}',
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            AnimatedBar(
                              value: rank.divisionProgress,
                              color: rank.color,
                              background: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                              height: 7,
                              radius: 4,
                            ),
                          ]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: rank.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: rank.color),
                    ),
                  ]),
                ),
              );
            }),
          ),

          // ── Smart Recommendation Banner ──────────────────
          Builder(builder: (bCtx) {
            final wMin = workoutMin;
            final hour = DateTime.now().hour;
            if (wMin >= 30) return const SizedBox.shrink();
            Workout? rec;
            if (isRamadan) { rec = kWorkouts.firstWhere((w) => w.category =='ramadan', orElse: () => kWorkouts.first);
            } else if (hour >= 5 && hour < 8) { rec = kWorkouts.firstWhere((w) => w.id =='w6', orElse: () => kWorkouts.first);
            } else if (hour >= 16 && hour < 20) { rec = kWorkouts.firstWhere((w) => w.category =='strength'&& !w.isPremium, orElse: () => kWorkouts.first);
            } else if (hour >= 21) { rec = kWorkouts.firstWhere((w) => w.category =='breathing', orElse: () => kWorkouts.first);
            }
            if (rec == null) return const SizedBox.shrink();
            final Workout recommended = rec; // promote for null-safety
            // PATCH_V24: recommended as a true hero card
            return _anim(0, GestureDetector(
              onTap: () => Navigator.push(bCtx, MaterialPageRoute(
                  builder: (_) => WorkoutPlayerScreen(workoutId: recommended.id))),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRamadan
                        ? [AppColors.ramadanNight, AppColors.ramadanCardAlt]
                        : isSis
                            ? [const Color(0xFFB8860B), const Color(0xFFDAA520)]
                            : [const Color(0xFF0F3D24), const Color(0xFF2E9C40)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                    color: (isRamadan ? AppColors.ramadanGold : AppColors.brandGreen)
                        .withOpacity(0.42),
                    blurRadius: 28, offset: const Offset(0, 10))],
                ),
                child: Stack(children: [
                  Positioned(
                    right: isAr ? null : -8,
                    left: isAr ? -8 : null,
                    bottom: -6,
                    child: Opacity(
                      opacity: 0.22,
                      child: workoutIconAsset(recommended.id, isSis) != null
                          ? Image.asset(workoutIconAsset(recommended.id, isSis)!,
                              width: 110, height: 110, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  Text(recommended.emoji, style: const TextStyle(fontSize: 72)))
                          : Text(recommended.emoji, style: const TextStyle(fontSize: 72)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Row(children: [
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                              isAr ? '⚡ موصى به الآن' : '⚡ Recommended Now',
                              style: const TextStyle(fontFamily: 'Aligarh',
                                  fontSize: 11, fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                        const SizedBox(height: 10),
                        Text(isAr ? recommended.titleAr : recommended.titleEn,
                            style: const TextStyle(fontFamily: 'Aligarh',
                                fontSize: 20, fontWeight: FontWeight.w900,
                                color: Colors.white, height: 1.1)),
                        const SizedBox(height: 4),
                        Text('${recommended.durationMin} ${isAr ? "دقيقة" : "min"}  •  ${isAr ? recommended.level : recommended.levelEn}',
                            style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.85))),
                      ])),
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Icon(Icons.play_arrow_rounded,
                            color: isRamadan
                                ? AppColors.ramadanNight
                                : const Color(0xFF145C32),
                            size: 34),
                      ),
                    ]),
                  ),
                ]),
              ),
            ));
          }),
          const SizedBox(height: 6),

          // Workout grid
          Expanded(child: TabBarView(
            controller: _tab,
            children: _cats.map((_) {
              final list = _filtered(gender, isRamadan, isPremium);
              if (list.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [ const Text('🔍', style: TextStyle(fontSize: 42)),
                    const SizedBox(height: 12), Text(t('لا تمارين في هذه الفئة', 'No workouts in this category'), style: TextStyle(fontFamily:'Aligarh', color: muted)),
                  ],
                ));
              }
              // PATCH_V24_FITNESS_REMASTER: magazine workout grid
              return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 2),
                  child: Text(t('التمارين', 'Workouts'),
                      style: TextStyle(fontFamily: 'Aligarh', fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.darkText : AppColors.lightText)),
                ),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 14,
                    crossAxisSpacing: 14, childAspectRatio: 0.72),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final w  = list[i];
                    final lc = _hexColor(w.levelColor);
                    final locked = w.isPremium && !isPremium;
                    final iconPath = workoutIconAsset(w.id, isSis);

                    return _anim(i + 1, GestureDetector(
                      onTap: () {
                        if (locked) { context.push('/paywall');
                        } else { context.push('/workout/${w.id}');
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.32 : 0.08),
                              blurRadius: 20, offset: const Offset(0, 8)),
                          ],
                          border: Border.all(
                              color: locked
                                  ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                  : barCol.withOpacity(isDark ? 0.28 : 0.16),
                              width: 1.0),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          // Illustration zone
                          Expanded(
                            flex: 5,
                            child: Container(
                              color: isDark
                                  ? barCol.withOpacity(0.08)
                                  : barCol.withOpacity(0.06),
                              child: Stack(children: [
                                Center(
                                  child: iconPath != null
                                      ? Image.asset(iconPath,
                                          width: 88, height: 88, fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              Text(w.emoji, style: const TextStyle(fontSize: 48)))
                                      : Text(w.emoji, style: const TextStyle(fontSize: 48)),
                                ),
                                if (locked)
                                  Positioned(
                                    top: 10, right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentGold.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.lock_rounded,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                              ]),
                            ),
                          ),
                          // Footer info band
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(isAr ? w.titleAr : w.titleEn,
                                    style: TextStyle(
                                        fontFamily: 'Aligarh',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5, height: 1.25,
                                        color: isDark
                                            ? AppColors.darkText
                                            : AppColors.lightText),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                const Spacer(),
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: lc.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20)),
                                    child: Text(isAr ? w.level : w.levelEn,
                                        style: TextStyle(
                                            fontFamily: 'Aligarh',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: lc)),
                                  ),
                                  const Spacer(),
                                  Text('${w.durationMin}${t("د","m")}',
                                      style: TextStyle(
                                          fontFamily: 'Aligarh',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: muted)),
                                ]),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                    ));
                  },
                ),

                // Premium upsell
                if (!isPremium) ...[
                  const SizedBox(height: 16),
                  GestureDetector( onTap: () => context.push('/paywall'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF1A6B3C), AppColors.brandGreen]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                          color: AppColors.brandGreen.withOpacity(0.30),
                          blurRadius: 14, offset: const Offset(0, 5))],
                      ),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(t('🔒 ${kWorkouts.where((w) => w.isPremium).length} خطة متقدمة', '🔒 ${kWorkouts.where((w) => w.isPremium).length} Advanced Plans'), style: const TextStyle(fontFamily:'Aligarh',
                                  fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)), Text(t('HIIT • كارديو • تناسق • قوة كاملة', 'HIIT • Cardio • Toning • Full strength'), style: const TextStyle(fontFamily:'Aligarh',
                                  fontSize: 11, color: Colors.white70)),
                        ])),
                        ElevatedButton( onPressed: () => context.push('/paywall'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGold,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)), child: Text(t('ترقية', 'Upgrade'), style: const TextStyle(fontFamily:'Aligarh',
                                  fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ]);
            }).toList(),
          )),
        ]),
      ),
    );
  }

  Color _hexColor(String hex) { final h = hex.replaceAll('#', ''); return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00A86B);
  }
}

// ══════════════════════════════════════════════════
//  WorkoutPlayerScreen — Step-by-step exercise timer
// ══════════════════════════════════════════════════
class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  final String workoutId;
  const WorkoutPlayerScreen({super.key, required this.workoutId});
  @override ConsumerState<WorkoutPlayerScreen> createState() => _WorkoutPlayerState();
}

class _WorkoutPlayerState extends ConsumerState<WorkoutPlayerScreen>
    with SingleTickerProviderStateMixin {
  Timer?  _timer;
  int     _elapsed   = 0;
  int     _stepIndex = 0;
  bool    _running   = false;
  bool    _done      = false;
  late AnimationController _pulse;

  Workout? get _workout =>
      kWorkouts.firstWhere((w) => w.id == widget.workoutId, orElse: () => kWorkouts.first);

  bool get _hasSteps => (_workout?.steps.isNotEmpty) ?? false;

  List<WorkoutStep> get _steps => _workout?.steps ?? [];
  WorkoutStep?      get _currentStep =>
      _hasSteps && _stepIndex < _steps.length ? _steps[_stepIndex] : null;

  int get _stepDuration => _currentStep?.durationSec ?? 30;
  int get _totalSeconds  => (_workout?.durationMin ?? 10) * 60;

  int get _overallElapsed {
    if (!_hasSteps) return _elapsed;
    int total = 0;
    for (int i = 0; i < _stepIndex && i < _steps.length; i++) {
      total += _steps[i].durationSec > 0 ? _steps[i].durationSec : 30;
    }
    return total + _elapsed;
  }

  double get _overallProgress =>
      _totalSeconds > 0 ? (_overallElapsed / _totalSeconds).clamp(0.0, 1.0) : 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900), lowerBound: 0.95, upperBound: 1.0)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_done) return;
    setState(() => _running = !_running);
    if (_running) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _elapsed++;
          // Step-based progression
          if (_hasSteps && _currentStep != null) {
            if (_currentStep!.durationSec > 0 && _elapsed >= _currentStep!.durationSec) {
              _nextStep();
            }
          } else if (_elapsed >= _totalSeconds) {
            _finish();
          }
        });
      });
    } else {
      _timer?.cancel();
    }
  }

  void _nextStep() {
    if (_stepIndex < _steps.length - 1) {
      _stepIndex++;
      _elapsed = 0;
    } else {
      _finish();
    }
  }

  void _finish() {
    _timer?.cancel();
    _running = false;
    _done    = true;
    final w = _workout;
    if (w != null) {
      ref.read(streakProvider.notifier).increment();
      ref.read(workoutMinutesProvider.notifier).add(w.id, w.durationMin);
    }
  }

  String _fmt(int secs) { final m = (secs ~/ 60).toString().padLeft(2,'0'); final s = (secs % 60).toString().padLeft(2,'0'); return'$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final w     = _workout;
    final lang      = ref.watch(languageProvider);
    final isAr      = lang == 'ar' || lang == 'ur';
    final isDark    = ref.watch(themeProvider); if (w == null) return const Scaffold(body: Center(child: Text('Not found')));
            final isSis = ref.watch(genderProvider) == 'sisters';
    final isRamadan = ref.watch(ramadanModeProvider);

    final bg   = isDark ? AppColors.darkBg   : AppColors.lightBg;
    final card = isDark ? AppColors.darkCard : Colors.white;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    String t(String ar, String en) => tLang(lang, ar, en);

    final step = _currentStep;
    final rem  = _hasSteps
        ? (step?.durationSec ?? 30) - _elapsed
        : (_totalSeconds - _elapsed);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: Text(isAr ? w.titleAr : w.titleEn, style: const TextStyle(fontFamily:'Aligarh', fontSize: 14,
                  fontWeight: FontWeight.w700)),
          backgroundColor: isRamadan ? AppColors.ramadanCard : AppColors.brandGreen,
        ),
        body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [

          // ── Overall progress bar ──────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text(t('التقدم الكلي', 'Overall Progress'), style: TextStyle(fontFamily:'Aligarh', fontSize: 11, color: muted)), Text('${(_overallProgress * 100).toInt()}%', style: TextStyle(fontFamily:'Aligarh', fontSize: 11,
                        fontWeight: FontWeight.w700, color: AppColors.brandGreen)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: _overallProgress, minHeight: 7,
                backgroundColor: AppColors.brandGreen.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation(AppColors.brandGreen),
              )),
            ]),
          ),

          // ── Illustration (PATCH_V25: solid plate, no checkerboard)
          Builder(builder: (_) {
            final iconPath = workoutIconAsset(w.id, isSis);
            return Container(
              width: 140, height: 140,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A2E22)
                    : const Color(0xFFE8F5EC),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: (isRamadan ? AppColors.ramadanGold : AppColors.brandGreen)
                      .withOpacity(0.25),
                ),
              ),
              child: Center(
                child: iconPath != null
                    ? Image.asset(iconPath,
                        width: 100, height: 100, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Text(w.emoji, style: const TextStyle(fontSize: 56)))
                    : Text(w.emoji, style: const TextStyle(fontSize: 56)),
              ),
            );
          }),

          // Step name
          if (_hasSteps && step != null && !_done)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                key: ValueKey(_stepIndex),
                isAr ? step.nameAr : step.nameEn,
                textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 18,
                    fontWeight: FontWeight.w800, color: text, height: 1.3),
              ),
            ),
          if (!_hasSteps)
            Text(isAr ? w.titleAr : w.titleEn, textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 16,
                    fontWeight: FontWeight.w700, color: text)),

          // Step instruction
          if (_hasSteps && step?.instructionAr != null && !_done) ...[
            const SizedBox(height: 8),
            Text(isAr ? step!.instructionAr! : (step!.instructionEn ?? step.instructionAr!),
                textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 13,
                    color: muted, height: 1.5)),
          ],

          const SizedBox(height: 24),

          // ── Circle timer ──────────────────────────────────
          SizedBox(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(
              value: _done ? 1.0 : _overallProgress,
              strokeWidth: 10,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(
                  _done ? AppColors.accentGold : AppColors.brandGreen),
              strokeCap: StrokeCap.round,
            )),
            if (_hasSteps && step != null && !_done)
              SizedBox.expand(child: Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  value: step.durationSec > 0
                      ? (_elapsed / step.durationSec).clamp(0.0, 1.0)
                      : 0,
                  strokeWidth: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accentGold),
                  strokeCap: StrokeCap.round,
                ),
              )),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_done) const Text('🎉', style: TextStyle(fontSize: 44))
              else ...[
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Transform.scale(
                    scale: _running ? _pulse.value : 1.0,
                    child: Text(
                      _hasSteps && step?.durationSec == 0 ?'${step?.reps ?? 0}\n${t("مرة","reps")}': _fmt(rem.clamp(0, 9999)),
                      textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 36,
                          fontWeight: FontWeight.w900, color: text, height: 1.1),
                    ),
                  ),
                ), Text(_hasSteps ? t('للخطوة','for step') : t('متبقي','remaining'), style: TextStyle(fontFamily:'Aligarh', fontSize: 12, color: muted)),
              ],
            ]),
          ])),

          const SizedBox(height: 24),

          // ── Step progress dots ────────────────────────────
          if (_hasSteps && !_done)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < _steps.length; i++) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _stepIndex ? 24 : 8, height: 8,
                  decoration: BoxDecoration(
                    color: i < _stepIndex
                        ? AppColors.halalGreen
                        : i == _stepIndex
                            ? AppColors.brandGreen
                            : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (i < _steps.length - 1) const SizedBox(width: 4),
              ],
            ]),

          const SizedBox(height: 24),

          // ── Coaching note ─────────────────────────────────
          if (w.note != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withOpacity(isDark ? 0.1 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
              ),
              child: Text( '💡 ${isAr ? w.note! : (w.noteEn ?? w.note!)}',
                textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 12,
                    color: AppColors.accentGold, fontStyle: FontStyle.italic, height: 1.6),
              ),
            ),

          const SizedBox(height: 20),

          // ── Done screen ───────────────────────────────────
          if (_done) ...[
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.brandGreen.withOpacity(0.3)),
              ),
              child: Column(children: [ const Text('🌟', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 12), Text(t('أحسنت!', 'Well done!'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 22,
                        fontWeight: FontWeight.w900, color: AppColors.brandGreen)),
                const SizedBox(height: 6), Text(t('أتممت ${w.durationMin} دقيقة من ${isAr ? w.titleAr : w.titleEn}', 'Completed ${w.durationMin} min of ${isAr ? w.titleAr : w.titleEn}'),
                    textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 13, color: muted, height: 1.5)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => context.pop(), child: Text(t('رجوع للتمارين', 'Back to Workouts'), style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w700)),
                )),
              ]),
            ),
          ] else ...[
            // ── Controls ──────────────────────────────────
            Row(children: [
              Expanded(child: ElevatedButton(
                onPressed: _toggle,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text( _running ? t('⏸ إيقاف', '⏸ Pause') : t('▶ ابدأ', '▶ Start'), style: const TextStyle(fontFamily:'Aligarh',
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              )),
              const SizedBox(width: 12),
              if (_hasSteps && _stepIndex < _steps.length - 1)
                Expanded(child: OutlinedButton(
                  onPressed: () => setState(() { _nextStep(); }),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(t('⏭ التالي', '⏭ Next'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 14)),
                ))
              else
                Expanded(child: OutlinedButton(
                  onPressed: () { _timer?.cancel(); _finish(); setState(() {}); },
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(t('✓ أكملت', '✓ Done'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 14)),
                )),
            ]),
          ],

          const SizedBox(height: 20),
        ])),
      ),
    );
  }
}

