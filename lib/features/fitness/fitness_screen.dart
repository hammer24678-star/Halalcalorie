// fitness_screen.dart — HalalCalorie v1.0
// 23 workouts, category tabs, Ramadan mode, step-by-step player
import 'dart:async'; import'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:go_router/go_router.dart'; import'../../core/theme.dart'; import'../../core/providers.dart';
import '../../core/l10n.dart'; import'../../data/models/models.dart';

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
    final gender    = ref.watch(genderProvider); final isAr      = ref.watch(languageProvider) =='ar';
    final isDark    = ref.watch(themeProvider);
    final isPremium = ref.watch(premiumProvider);
    final isRamadan = ref.watch(ramadanModeProvider);
    final workoutMin = ref.watch(workoutMinutesProvider); final isSis     = gender =='sisters';
    final barCol    = isSis ? AppColors.barakahGold : AppColors.sunnahGreen;
    final barGrad   = isSis ? AppColors.gradientGold : AppColors.gradientGreen;
    final bg        = isDark ? AppColors.darkBg   : AppColors.lightBg;
    final card      = isDark ? AppColors.darkCard : Colors.white;
    final muted     = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    final workouts = _filtered(gender, isRamadan, isPremium);

    String t(String ar, String en) => tLang(lang, ar, en);

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
                colors: isSis
                    ? [const Color(0xFFB8860B), const Color(0xFFDAA520)]
                    : [const Color(0xFF1A6B3C), AppColors.sunnahGreen],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          title: Text(t('اللياقة الإسلامية 🏃', 'Islamic Fitness 🏃'),
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 18)),
          actions: [
            if (workoutMin > 0)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Chip(
                  backgroundColor: Colors.white.withOpacity(0.2), label: Text('$workoutMin ${t("د","min")}', style: const TextStyle(fontFamily:'Cairo',
                          fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)), avatar: const Text('🔥', style: TextStyle(fontSize: 13)),
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70, labelStyle: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700, fontSize: 11), unselectedLabelStyle: const TextStyle(fontFamily:'Cairo', fontSize: 11),
            tabAlignment: TabAlignment.start,
            tabs: _cats.map((c) => Tab(text: catLabels[c] ?? c)).toList(),
          ),
        ),
        body: Column(children: [
          // Mode banner
          if (isRamadan || isSis)
            Container(
              color: (isSis ? AppColors.barakahGold : AppColors.darkGreen).withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [ Text(isSis ?'🧕' : '🌙', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  isSis && isRamadan ? t('وضع النساء + رمضان — محتشم وخفيف', 'Sisters + Ramadan — modest & light')
                      : isRamadan ? t('وضع رمضان — التمارين الخفيفة أولاً', 'Ramadan mode — light workouts first') : t('وضع النساء — محتشم دائماً', 'Sisters mode — always modest'), style: TextStyle(fontFamily:'Cairo', fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSis ? AppColors.barakahGold : AppColors.sunnahGreen),
                )),
              ]),
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
            return _anim(0, GestureDetector(
              onTap: () => Navigator.push(bCtx, MaterialPageRoute(
                  builder: (_) => WorkoutPlayerScreen(workoutId: rec!.id))),
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRamadan
                        ? [const Color(0xFF1A0F00), const Color(0xFF3D2000)]
                        : [const Color(0xFF1A6B3C), AppColors.sunnahGreen],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: AppColors.sunnahGreen.withOpacity(0.35),
                    blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: Row(children: [
                  Text(rec.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(isAr ?'⚡ موصى به الآن' : '⚡ Recommended Now', style: TextStyle(fontFamily:'Cairo', fontSize: 10,
                            color: isRamadan ? AppColors.barakahGold : Colors.white70)),
                    Text(isAr ? rec.titleAr : rec.titleEn, style: const TextStyle(fontFamily:'Cairo', fontSize: 13,
                            fontWeight: FontWeight.w800, color: Colors.white)), Text('${rec.durationMin} ${isAr ? "دقيقة" : "min"}  •  ${isAr ? rec.level : rec.levelEn}', style: const TextStyle(fontFamily:'Cairo', fontSize: 10, color: Colors.white70)),
                  ])),
                  const Icon(Icons.play_circle_filled, color: Colors.white, size: 32),
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
                    const SizedBox(height: 12), Text(t('لا تمارين في هذه الفئة', 'No workouts in this category'), style: TextStyle(fontFamily:'Cairo', color: muted)),
                  ],
                ));
              }
              return ListView(padding: const EdgeInsets.all(14), children: [
                // Hadith quote at top
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: barCol.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: barCol.withOpacity(0.2)),
                  ),
                  child: Text(
                    isAr ?'«المؤمن القوي خير وأحب إلى الله من المؤمن الضعيف» — مسلم' :'"The strong believer is better & more beloved to Allah" — Muslim',
                    textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 12,
                        color: barCol, height: 1.6, fontStyle: FontStyle.italic),
                  ),
                ),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12,
                    crossAxisSpacing: 12, childAspectRatio: 0.88),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final w  = list[i];
                    final lc = _hexColor(w.levelColor);
                    final locked = w.isPremium && !isPremium;

                    return _anim(i + 1, GestureDetector(
                      onTap: () {
                        if (locked) { context.push('/paywall');
                        } else { context.push('/workout/${w.id}');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                              blurRadius: 16, offset: const Offset(0, 5)),
                            if (!locked) BoxShadow(
                              color: barCol.withOpacity(0.06),
                              blurRadius: 12, spreadRadius: 1),
                          ],
                          border: Border.all(
                              color: locked
                                  ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                  : barCol.withOpacity(isDark ? 0.25 : 0.18),
                              width: 0.8),
                        ),
                        child: Stack(children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(w.emoji, style: const TextStyle(fontSize: 32)),
                              const Spacer(),
                              if (locked)
                                const Icon(Icons.lock, size: 16, color: AppColors.barakahGold),
                            ]),
                            const SizedBox(height: 8),
                            Text(isAr ? w.titleAr : w.titleEn, style: TextStyle(fontFamily:'Cairo',
                                    fontWeight: FontWeight.w700, fontSize: 11,
                                    height: 1.4, color: isDark ? AppColors.darkText : AppColors.lightText),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const Spacer(),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: lc.withOpacity(0.13),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(isAr ? w.level : w.levelEn, style: TextStyle(fontFamily:'Cairo',
                                        fontSize: 9, fontWeight: FontWeight.w700, color: lc)),
                              ),
                              const Spacer(), Text('${w.durationMin}${t("د","m")}', style: TextStyle(fontFamily:'Cairo',
                                      fontSize: 11, color: muted)),
                            ]),
                          ]),
                          if (w.steps.isEmpty) Positioned(
                            top: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.barakahGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ), child: Text('⏱', style: TextStyle(fontSize: 9, color: muted)),
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
                            colors: [Color(0xFF1A6B3C), AppColors.sunnahGreen]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                          color: AppColors.sunnahGreen.withOpacity(0.30),
                          blurRadius: 14, offset: const Offset(0, 5))],
                      ),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(t('🔒 ${kWorkouts.where((w) => w.isPremium).length} خطة متقدمة', '🔒 ${kWorkouts.where((w) => w.isPremium).length} Advanced Plans'), style: const TextStyle(fontFamily:'Cairo',
                                  fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)), Text(t('HIIT • كارديو • تناسق • قوة كاملة', 'HIIT • Cardio • Toning • Full strength'), style: const TextStyle(fontFamily:'Cairo',
                                  fontSize: 11, color: Colors.white70)),
                        ])),
                        ElevatedButton( onPressed: () => context.push('/paywall'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.barakahGold,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)), child: Text(t('ترقية', 'Upgrade'), style: const TextStyle(fontFamily:'Cairo',
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
    final w     = _workout; final isAr  = ref.watch(languageProvider) =='ar';
    final isDark = ref.watch(themeProvider); if (w == null) return const Scaffold(body: Center(child: Text('Not found')));

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
          title: Text(isAr ? w.titleAr : w.titleEn, style: const TextStyle(fontFamily:'Cairo', fontSize: 14,
                  fontWeight: FontWeight.w700)),
          backgroundColor: AppColors.sunnahGreen,
        ),
        body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [

          // ── Overall progress bar ──────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text(t('التقدم الكلي', 'Overall Progress'), style: TextStyle(fontFamily:'Cairo', fontSize: 11, color: muted)), Text('${(_overallProgress * 100).toInt()}%', style: TextStyle(fontFamily:'Cairo', fontSize: 11,
                        fontWeight: FontWeight.w700, color: AppColors.sunnahGreen)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: _overallProgress, minHeight: 7,
                backgroundColor: AppColors.sunnahGreen.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation(AppColors.sunnahGreen),
              )),
            ]),
          ),

          // ── Emoji + step info ─────────────────────────────
          Text(w.emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 8),

          // Step name
          if (_hasSteps && step != null && !_done)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                key: ValueKey(_stepIndex),
                isAr ? step.nameAr : step.nameEn,
                textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 18,
                    fontWeight: FontWeight.w800, color: text, height: 1.3),
              ),
            ),
          if (!_hasSteps)
            Text(isAr ? w.titleAr : w.titleEn, textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 16,
                    fontWeight: FontWeight.w700, color: text)),

          // Step instruction
          if (_hasSteps && step?.instructionAr != null && !_done) ...[
            const SizedBox(height: 8),
            Text(isAr ? step!.instructionAr! : (step!.instructionEn ?? step.instructionAr!),
                textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 13,
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
                  _done ? AppColors.barakahGold : AppColors.sunnahGreen),
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
                  valueColor: const AlwaysStoppedAnimation(AppColors.barakahGold),
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
                      textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 36,
                          fontWeight: FontWeight.w900, color: text, height: 1.1),
                    ),
                  ),
                ), Text(_hasSteps ? t('للخطوة','for step') : t('متبقي','remaining'), style: TextStyle(fontFamily:'Cairo', fontSize: 12, color: muted)),
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
                            ? AppColors.sunnahGreen
                            : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (i < _steps.length - 1) const SizedBox(width: 4),
              ],
            ]),

          const SizedBox(height: 24),

          // ── Hadith card ───────────────────────────────────
          if (w.hadith != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.barakahGold.withOpacity(isDark ? 0.1 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.barakahGold.withOpacity(0.3)),
              ),
              child: Text( '📖 ${isAr ? w.hadith! : (w.hadithEn ?? w.hadith!)}',
                textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 12,
                    color: AppColors.barakahGold, fontStyle: FontStyle.italic, height: 1.6),
              ),
            ),

          const SizedBox(height: 20),

          // ── Done screen ───────────────────────────────────
          if (_done) ...[
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.sunnahGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.sunnahGreen.withOpacity(0.3)),
              ),
              child: Column(children: [ const Text('🌟', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 12), Text(t('بارك الله فيك!', 'May Allah bless you!'), style: const TextStyle(fontFamily:'Cairo', fontSize: 22,
                        fontWeight: FontWeight.w900, color: AppColors.sunnahGreen)),
                const SizedBox(height: 6), Text(t('أتممت ${w.durationMin} دقيقة من ${isAr ? w.titleAr : w.titleEn}', 'Completed ${w.durationMin} min of ${isAr ? w.titleAr : w.titleEn}'),
                    textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 13, color: muted, height: 1.5)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => context.pop(), child: Text(t('رجوع للتمارين', 'Back to Workouts'), style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700)),
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
                child: Text( _running ? t('⏸ إيقاف', '⏸ Pause') : t('▶ ابدأ', '▶ Start'), style: const TextStyle(fontFamily:'Cairo',
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              )),
              const SizedBox(width: 12),
              if (_hasSteps && _stepIndex < _steps.length - 1)
                Expanded(child: OutlinedButton(
                  onPressed: () => setState(() { _nextStep(); }),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(t('⏭ التالي', '⏭ Next'), style: const TextStyle(fontFamily:'Cairo', fontSize: 14)),
                ))
              else
                Expanded(child: OutlinedButton(
                  onPressed: () { _timer?.cancel(); _finish(); setState(() {}); },
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(t('✓ أكملت', '✓ Done'), style: const TextStyle(fontFamily:'Cairo', fontSize: 14)),
                )),
            ]),
          ],

          const SizedBox(height: 20),
        ])),
      ),
    );
  }
}
