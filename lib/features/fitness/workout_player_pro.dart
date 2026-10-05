// workout_player_pro.dart — HalalCalorie v57
// Workout player rebuilt: get-ready countdown, timed + rep steps, rest
// periods, haptic/sound cues, pause / back / skip, real elapsed time,
// MET-based calories, saved sessions, weekly stats + history.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';
import '../../core/database.dart';
import '../../core/fx6.dart' show GlassIconBtn, EmojiIcon;
import '../../data/models/models.dart';
import '../../data/icon_assets.dart';

enum _Ph { ready, countdown, work, rest, done }

const Map<String, double> _kMet = {
  'walking': 3.5, 'strength': 5.0, 'cardio': 8.0, 'gentle': 2.5,
  'ramadan': 3.0, 'breathing': 1.5, 'family': 4.0, 'postnatal': 2.5,
};

// ══════════════════════════════════════════════════════════════════
//  Player
// ══════════════════════════════════════════════════════════════════
class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  final String workoutId;
  const WorkoutPlayerScreen({super.key, required this.workoutId});
  @override
  ConsumerState<WorkoutPlayerScreen> createState() => _WorkoutPlayerState();
}

class _WorkoutPlayerState extends ConsumerState<WorkoutPlayerScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  _Ph _ph = _Ph.ready;
  bool _paused = false;
  bool _sound = true;
  bool _saved = false;
  int _i = 0;            // current step
  int _left = 0;         // seconds left (countdown / timed work / rest)
  int _stepElapsed = 0;
  int _workSec = 0, _restSec = 0, _stepsDone = 0;
  int _restLen = 15;
  double _kcalFinal = 0;
  Map<String, dynamic>? _last;
  late final AnimationController _pulse;
  late final AnimationController _confetti;

  Workout get _w => kWorkouts.firstWhere((w) => w.id == widget.workoutId,
      orElse: () => kWorkouts.first);

  List<WorkoutStep> get _steps {
    final w = _w;
    if (w.steps.isNotEmpty) return w.steps;
    // Workouts with no step list play as one timed block.
    return [
      WorkoutStep(
          nameAr: w.titleAr, nameEn: w.titleEn,
          durationSec: w.durationMin * 60, reps: 0),
    ];
  }

  WorkoutStep get _step => _steps[_i.clamp(0, _steps.length - 1)];
  bool get _timed => _step.durationSec > 0;
  bool get _isLast => _i >= _steps.length - 1;

  int get _estSeconds {
    var s = 0;
    for (final st in _steps) {
      s += st.durationSec > 0 ? st.durationSec : math.max(20, st.reps * 3);
    }
    return s + _restLen * math.max(0, _steps.length - 1);
  }

  double get _bodyKg {
    final kg = ref.read(rankingBodyweightProvider);
    return kg > 20 ? kg : 70;
  }

  double get _met => _kMet[_w.category] ?? 4.0;

  double _kcalFor(int work, int rest) =>
      (_met * _bodyKg * work + 1.5 * _bodyKg * rest) / 3600.0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _confetti = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    AppDatabase.getLastSession(widget.workoutId).then((m) {
      if (mounted) setState(() => _last = m);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _confetti.dispose();
    super.dispose();
  }

  // ── cues ───────────────────────────────────────────────
  void _cue(int level) {
    if (level == 0) {
      HapticFeedback.selectionClick();
    } else if (level == 1) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    if (_sound && level > 0) SystemSound.play(SystemSoundType.click);
  }

  // ── flow ───────────────────────────────────────────────
  void _start() {
    setState(() {
      _ph = _Ph.countdown;
      _left = 3;
      _paused = false;
    });
    _cue(1);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer t) {
    if (!mounted || _paused) return;
    setState(() {
      switch (_ph) {
        case _Ph.countdown:
          _left--;
          if (_left <= 0) {
            _beginWork(0);
          } else {
            _cue(0);
          }
          break;
        case _Ph.work:
          _workSec++;
          _stepElapsed++;
          if (_timed) {
            _left = _step.durationSec - _stepElapsed;
            if (_left <= 0) {
              _completeStep();
            } else if (_left <= 3) {
              _cue(0);
            }
          }
          break;
        case _Ph.rest:
          _restSec++;
          _left--;
          if (_left <= 0) {
            _beginWork(_i + 1);
          } else if (_left <= 3) {
            _cue(0);
          }
          break;
        default:
          break;
      }
    });
  }

  void _beginWork(int i) {
    _i = i.clamp(0, _steps.length - 1);
    _ph = _Ph.work;
    _stepElapsed = 0;
    _left = _timed ? _step.durationSec : 0;
    _cue(2);
  }

  void _completeStep() {
    _stepsDone++;
    if (_isLast) {
      _finish();
    } else if (_restLen > 0) {
      _ph = _Ph.rest;
      _left = _restLen;
      _cue(1);
    } else {
      _beginWork(_i + 1);
    }
  }

  void _skip() {
    setState(() {
      if (_ph == _Ph.rest) {
        _beginWork(_i + 1);
      } else if (_ph == _Ph.work) {
        if (_isLast) {
          _finish();
        } else {
          _beginWork(_i + 1);
        }
      }
    });
  }

  void _prev() {
    setState(() {
      if (_ph == _Ph.rest) {
        _beginWork(_i);
      } else if (_ph == _Ph.work) {
        _beginWork(_stepElapsed > 3 || _i == 0 ? _i : _i - 1);
      }
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    HapticFeedback.selectionClick();
  }

  void _finish() {
    _timer?.cancel();
    _ph = _Ph.done;
    _paused = false;
    _kcalFinal = _kcalFor(_workSec, _restSec);
    _confetti.forward(from: 0);
    HapticFeedback.heavyImpact();
    _save(completed: true);
  }

  Future<void> _save({required bool completed}) async {
    if (_saved) return;
    _saved = true;
    final w = _w;
    final secs = _workSec + _restSec;
    if (secs < 5) return;
    final kcal = _kcalFor(_workSec, _restSec);
    final mins = (secs / 60).round().clamp(1, 600).toInt();
    final minN = ref.read(workoutMinutesProvider.notifier);
    final streakN = ref.read(streakProvider.notifier);
    try {
      await minN.add(w.id, mins, kcal: kcal);
      await AppDatabase.logSession(
        workoutId: w.id, seconds: secs, kcal: kcal,
        stepsDone: _stepsDone, stepsTotal: _steps.length,
      );
      if (completed || secs >= 120) await streakN.increment();
      if (mounted) {
        ref.invalidate(caloriesBurnedTodayProvider);
        ref.invalidate(workoutStatsProvider);
      }
    } catch (_) {}
  }

  Future<bool> _confirmQuit() async {
    if (_ph == _Ph.ready || _ph == _Ph.done) return true;
    final wasPaused = _paused;
    setState(() => _paused = true);
    final lang = ref.read(languageProvider);
    String t(String ar, String en) => tLang(lang, ar, en);
    final canSave = _workSec >= 30 || _stepsDone > 0;
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('إنهاء التمرين؟', 'End workout?'),
            style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w800)),
        content: Text(
            canSave
                ? t('يمكنك حفظ ما أنجزته حتى الآن.', 'You can save what you have done so far.')
                : t('لم تنجز شيئاً بعد.', 'You have not done anything yet.'),
            style: const TextStyle(fontFamily: 'Aligarh')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, 'stay'),
              child: Text(t('أكمل', 'Keep going'),
                  style: const TextStyle(fontFamily: 'Aligarh'))),
          TextButton(
              onPressed: () => Navigator.pop(c, 'discard'),
              child: Text(t('تجاهل', 'Discard'),
                  style: const TextStyle(fontFamily: 'Aligarh', color: AppColors.haramRed))),
          if (canSave)
            ElevatedButton(
                onPressed: () => Navigator.pop(c, 'save'),
                child: Text(t('احفظ وأنهِ', 'Save & finish'),
                    style: const TextStyle(fontFamily: 'Aligarh'))),
        ],
      ),
    );
    if (r == 'save') {
      _timer?.cancel();
      await _save(completed: false);
      return true;
    }
    if (r == 'discard') {
      _timer?.cancel();
      return true;
    }
    if (mounted) setState(() => _paused = wasPaused);
    return false;
  }

  String _fmt(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar' || lang == 'ur';
    final isDark = ref.watch(themeProvider);
    final isSis = ref.watch(genderProvider) == 'sisters';
    final ram = ref.watch(ramadanModeProvider) && !isSis;
    String t(String ar, String en) => tLang(lang, ar, en);

    final Color bg = ram
        ? (isDark ? AppColors.ramadanNight : AppColors.ramadanDay)
        : (isDark ? AppColors.darkBg : AppColors.lightBg);
    final Color textC = ram
        ? (isDark ? AppColors.ramadanText : AppColors.ramadanDayText)
        : (isDark ? AppColors.darkText : AppColors.lightText);
    final Color muted = ram
        ? (isDark ? AppColors.ramadanMuted : AppColors.ramadanDayMuted)
        : (isDark ? AppColors.darkMuted : AppColors.lightMuted);
    final Color accent = ram
        ? (isDark ? AppColors.ramadanGold : AppColors.ramadanGoldDim)
        : (isSis ? AppColors.accentGold : AppColors.brandGreen);
    final Color phaseCol = _ph == _Ph.rest
        ? AppColors.waterBlue
        : (_ph == _Ph.countdown ? AppColors.accentGold : accent);

    final w = _w;
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: WillPopScope(
        onWillPop: _confirmQuit,
        child: Scaffold(
          backgroundColor: bg,
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.55),
                radius: 1.15,
                colors: [phaseCol.withOpacity(isDark ? 0.22 : 0.14), bg],
              ),
            ),
            child: SafeArea(
              child: Column(children: [
                _topBar(w, isAr, isDark, textC, muted, phaseCol),
                if (_ph != _Ph.ready && _ph != _Ph.done)
                  _stepBars(accent, textC),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: KeyedSubtree(
                      key: ValueKey('$_ph-${_ph == _Ph.work ? _i : 0}'),
                      child: _ph == _Ph.ready
                          ? _readyView(w, t, isAr, isDark, textC, muted, accent)
                          : _ph == _Ph.done
                              ? _doneView(w, t, isAr, textC, muted, accent)
                              : _liveView(w, t, isAr, isDark, textC, muted, accent, phaseCol, isSis),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(Workout w, bool isAr, bool isDark, Color textC, Color muted, Color col) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(children: [
        GlassIconBtn(
          icon: Icons.close_rounded, isDark: isDark,
          onTap: () async {
            if (await _confirmQuit() && mounted) context.pop();
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(isAr ? w.titleAr : w.titleEn,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 16,
                  fontWeight: FontWeight.w800, color: textC)),
        ),
        GlassIconBtn(
          icon: _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          isDark: isDark,
          onTap: () => setState(() => _sound = !_sound),
        ),
      ]),
    );
  }

  Widget _stepBars(Color accent, Color textC) {
    final n = _steps.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 2),
      child: Row(children: [
        for (var k = 0; k < n; k++) ...[
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: k < _i || (k == _i && _ph == _Ph.rest)
                    ? accent
                    : (k == _i ? accent.withOpacity(0.55) : textC.withOpacity(0.12)),
              ),
            ),
          ),
          if (k < n - 1) const SizedBox(width: 3),
        ],
      ]),
    );
  }

  // ── READY ────────────────────────────────────────────────
  Widget _readyView(Workout w, String Function(String, String) t, bool isAr,
      bool isDark, Color textC, Color muted, Color accent) {
    final estMin = (_estSeconds / 60).ceil();
    final estKcal = _kcalFor((_estSeconds - _restLen * (_steps.length - 1)).clamp(0, 99999).toInt(),
        _restLen * (_steps.length - 1));
    Widget stat(IconData ic, String v, String l) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: textC.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: textC.withOpacity(0.08)),
            ),
            child: Column(children: [
              Icon(ic, size: 20, color: accent),
              const SizedBox(height: 6),
              Text(v, style: TextStyle(fontFamily: 'Aligarh', fontSize: 18,
                  fontWeight: FontWeight.w900, color: textC)),
              Text(l, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
            ]),
          ),
        );
    final last = _last;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        Center(child: _plate(w, isDark, accent, 132)),
        const SizedBox(height: 16),
        Text(isAr ? w.descAr : w.descEn,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 13, height: 1.5, color: muted)),
        const SizedBox(height: 18),
        Row(children: [
          stat(Icons.format_list_numbered_rounded, '${_steps.length}', t('تمارين', 'Exercises')),
          const SizedBox(width: 10),
          stat(Icons.timer_rounded, '$estMin', t('دقيقة', 'Minutes')),
          const SizedBox(width: 10),
          stat(Icons.local_fire_department_rounded, '~${estKcal.round()}', t('سعرة', 'kcal')),
        ]),
        const SizedBox(height: 18),
        Text(t('الراحة بين التمارين', 'Rest between exercises'),
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                fontWeight: FontWeight.w800, color: muted)),
        const SizedBox(height: 8),
        Row(children: [
          for (final r in const [0, 10, 15, 20, 30]) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _restLen = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _restLen == r ? accent : textC.withOpacity(0.06),
                  ),
                  child: Text(r == 0 ? t('بدون', 'Off') : '${r}s',
                      style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _restLen == r
                              ? (isDark && accent == AppColors.accentGold ? AppColors.ramadanInk : Colors.white)
                              : muted)),
                ),
              ),
            ),
            if (r != 30) const SizedBox(width: 6),
          ],
        ]),
        if (last != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(Icons.history_rounded, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('آخر مرة: ${(((last['seconds'] as num?) ?? 0) / 60).round()} دقيقة · ${((last['kcal'] as num?) ?? 0).round()} سعرة',
                      'Last time: ${(((last['seconds'] as num?) ?? 0) / 60).round()} min · ${((last['kcal'] as num?) ?? 0).round()} kcal'),
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: textC)),
              ),
            ]),
          ),
        ],
        if (w.note != null) ...[
          const SizedBox(height: 12),
          Text(isAr ? w.note! : (w.noteEn ?? w.note!),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 11.5, height: 1.6,
                  fontStyle: FontStyle.italic, color: AppColors.accentGold)),
        ],
        const SizedBox(height: 22),
        _bigButton(t('ابدأ التمرين', 'Start workout'), Icons.play_arrow_rounded, accent, _start),
      ],
    );
  }

  Widget _bigButton(String label, IconData ic, Color col, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [col, Color.lerp(col, Colors.black, 0.22)!]),
          boxShadow: [BoxShadow(color: col.withOpacity(0.38), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ic, color: Colors.white, size: 26),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontFamily: 'Aligarh', fontSize: 17,
              fontWeight: FontWeight.w900, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _plate(Workout w, bool isDark, Color accent, double size) {
    final isSis = ref.read(genderProvider) == 'sisters';
    final iconPath = workoutIconAsset(w.id, isSis);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withOpacity(isDark ? 0.12 : 0.10),
        border: Border.all(color: accent.withOpacity(0.28)),
      ),
      child: Center(
        child: iconPath != null
            ? darkSafeAsset(iconPath,
                width: size * 0.62, height: size * 0.62, fit: BoxFit.contain,
                isDark: isDark, errorChild: EmojiIcon(w.emoji, size: size * 0.4))
            : EmojiIcon(w.emoji, size: size * 0.4),
      ),
    );
  }

  // ── LIVE (countdown / work / rest) ───────────────────────
  Widget _liveView(Workout w, String Function(String, String) t, bool isAr,
      bool isDark, Color textC, Color muted, Color accent, Color phaseCol, bool isSis) {
    final st = _step;
    final next = _isLast ? null : _steps[_i + 1];
    final isCount = _ph == _Ph.countdown;
    final isRest = _ph == _Ph.rest;

    double prog;
    String big, small;
    if (isCount) {
      prog = (3 - _left) / 3.0;
      big = '$_left';
      small = t('استعد', 'Get ready');
    } else if (isRest) {
      prog = _restLen == 0 ? 1 : 1 - _left / _restLen;
      big = _fmt(_left);
      small = t('راحة', 'Rest');
    } else if (_timed) {
      prog = _stepElapsed / st.durationSec;
      big = _fmt(_left);
      small = t('متبقي', 'left');
    } else {
      prog = 1;
      big = '${st.reps}';
      small = t('مرة', 'reps');
    }

    final shownStep = isRest ? (next ?? st) : st;
    final title = isCount
        ? t('سنبدأ بـ ${isAr ? st.nameAr : st.nameEn}', 'First up: ${isAr ? st.nameAr : st.nameEn}')
        : (isRest
            ? t('التالي: ${isAr ? shownStep.nameAr : shownStep.nameEn}',
                'Up next: ${isAr ? shownStep.nameAr : shownStep.nameEn}')
            : (isAr ? st.nameAr : st.nameEn));
    final instr = (isRest ? shownStep : st);
    final instrText = isAr ? instr.instructionAr : (instr.instructionEn ?? instr.instructionAr);

    return Column(children: [
      const SizedBox(height: 6),
      Text(
        isCount ? t('تجهّز', 'GET READY')
            : isRest ? t('استرح', 'REST')
            : t('تمرين ${_i + 1} من ${_steps.length}', 'EXERCISE ${_i + 1} OF ${_steps.length}'),
        style: TextStyle(fontFamily: 'Aligarh', fontSize: 11.5, letterSpacing: 1.2,
            fontWeight: FontWeight.w800, color: phaseCol)),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Text(title, textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 22,
                fontWeight: FontWeight.w900, color: textC, height: 1.2)),
      ),
      const SizedBox(height: 4),
      if (instrText != null && instrText.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(instrText, textAlign: TextAlign.center, maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 12.5, height: 1.5, color: muted)),
        ),
      Expanded(
        child: Center(
          child: SizedBox(
            width: 250, height: 250,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => CustomPaint(
                  size: const Size(250, 250),
                  painter: _RingPainter(
                    progress: prog.clamp(0.0, 1.0).toDouble(),
                    color: phaseCol,
                    track: textC.withOpacity(0.10),
                    glow: _paused ? 0 : _pulse.value,
                  ),
                ),
              ),
              if (!isCount && !isRest)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(34),
                    child: Opacity(opacity: 0.16, child: _plate(w, isDark, phaseCol, 180)),
                  ),
                ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(big, style: TextStyle(fontFamily: 'Aligarh',
                    fontSize: isCount ? 84 : 60, fontWeight: FontWeight.w900,
                    color: textC, height: 1.0)),
                const SizedBox(height: 4),
                Text(_paused ? t('متوقف', 'Paused') : small,
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _paused ? AppColors.accentGold : muted)),
              ]),
            ]),
          ),
        ),
      ),
      if (next != null && !isRest && !isCount)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.skip_next_rounded, size: 16, color: muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                  t('التالي: ${isAr ? next.nameAr : next.nameEn}',
                      'Next: ${isAr ? next.nameAr : next.nameEn}'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: muted)),
            ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Column(children: [
          if (_ph == _Ph.work && !_timed) ...[
            _bigButton(t('أنهيت المجموعة', 'Set done'), Icons.check_rounded, accent,
                () => setState(_completeStep)),
            const SizedBox(height: 12),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _roundBtn(Icons.skip_previous_rounded, textC, 52, _ph == _Ph.countdown ? null : _prev),
            const SizedBox(width: 18),
            _roundBtn(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                phaseCol, 72, _togglePause, filled: true),
            const SizedBox(width: 18),
            _roundBtn(Icons.skip_next_rounded, textC, 52, _ph == _Ph.countdown ? null : _skip),
          ]),
          if (isRest) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _left += 15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.waterBlue.withOpacity(0.14),
                  border: Border.all(color: AppColors.waterBlue.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, size: 16, color: AppColors.waterBlue),
                  const SizedBox(width: 4),
                  Text('15 ${t("ثانية", "sec")}',
                      style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12.5,
                          fontWeight: FontWeight.w800, color: AppColors.waterBlue)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }

  Widget _roundBtn(IconData ic, Color col, double size, VoidCallback? onTap,
      {bool filled = false}) {
    final off = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: off ? 0.3 : 1,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? col : col.withOpacity(0.10),
            border: filled ? null : Border.all(color: col.withOpacity(0.25)),
            boxShadow: filled
                ? [BoxShadow(color: col.withOpacity(0.40), blurRadius: 18, offset: const Offset(0, 6))]
                : null,
          ),
          child: Icon(ic, size: size * 0.5, color: filled ? Colors.white : col),
        ),
      ),
    );
  }

  // ── DONE ─────────────────────────────────────────────────
  Widget _doneView(Workout w, String Function(String, String) t, bool isAr,
      Color textC, Color muted, Color accent) {
    final secs = _workSec + _restSec;
    final mins = (secs / 60).ceil().clamp(1, 999).toInt();
    final streak = ref.watch(streakProvider);
    final last = _last;
    String? delta;
    if (last != null) {
      final prev = ((last['seconds'] as num?) ?? 0).toInt();
      final d = ((secs - prev) / 60).round();
      if (d != 0) {
        delta = d > 0
            ? t('أطول بـ $d دقيقة من آخر مرة', '$d min longer than last time')
            : t('أقصر بـ ${-d} دقيقة من آخر مرة', '${-d} min shorter than last time');
      } else {
        delta = t('نفس مدة آخر مرة', 'Same length as last time');
      }
    }
    Widget tile(IconData ic, String v, String l, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: c.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.withOpacity(0.25)),
            ),
            child: Column(children: [
              Icon(ic, size: 22, color: c),
              const SizedBox(height: 6),
              Text(v, style: TextStyle(fontFamily: 'Aligarh', fontSize: 22,
                  fontWeight: FontWeight.w900, color: textC)),
              Text(l, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10.5, color: muted)),
            ]),
          ),
        );
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _confetti,
            builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_confetti.value)),
          ),
        ),
      ),
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Center(
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [accent, Color.lerp(accent, Colors.black, 0.25)!]),
                boxShadow: [BoxShadow(color: accent.withOpacity(0.45), blurRadius: 28)],
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 52, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(t('أحسنت!', 'Well done!'), textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 28,
                  fontWeight: FontWeight.w900, color: accent)),
          const SizedBox(height: 4),
          Text(isAr ? w.titleAr : w.titleEn, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 14, color: muted)),
          const SizedBox(height: 22),
          Row(children: [
            tile(Icons.timer_rounded, '$mins', t('دقيقة', 'Minutes'), AppColors.waterBlue),
            const SizedBox(width: 10),
            tile(Icons.local_fire_department_rounded, '${_kcalFinal.round()}', t('سعرة', 'kcal'), AppColors.haramRed),
            const SizedBox(width: 10),
            tile(Icons.check_circle_rounded, '$_stepsDone/${_steps.length}', t('تمارين', 'Exercises'), AppColors.halalGreen),
          ]),
          const SizedBox(height: 14),
          if (streak > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.local_fire_department_rounded, color: AppColors.accentGold),
                const SizedBox(width: 8),
                Text(t('سلسلتك $streak يوم', 'Your streak: $streak days'),
                    style: const TextStyle(fontFamily: 'Aligarh', fontSize: 14,
                        fontWeight: FontWeight.w800, color: AppColors.accentGold)),
              ]),
            ),
          if (delta != null) ...[
            const SizedBox(height: 10),
            Text(delta, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: muted)),
          ],
          const SizedBox(height: 22),
          _bigButton(t('رجوع للتمارين', 'Back to workouts'), Icons.check_rounded, accent,
              () => context.pop()),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _timer?.cancel();
                  _ph = _Ph.ready; _i = 0; _workSec = 0; _restSec = 0;
                  _stepsDone = 0; _saved = false; _left = 0; _stepElapsed = 0;
                });
                AppDatabase.getLastSession(widget.workoutId).then((m) {
                  if (mounted) setState(() => _last = m);
                });
              },
              icon: Icon(Icons.replay_rounded, size: 18, color: muted),
              label: Text(t('تمرين مرة أخرى', 'Go again'),
                  style: TextStyle(fontFamily: 'Aligarh', color: muted)),
            ),
          ),
        ],
      ),
    ]);
  }
}

// ── painters ─────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress, glow;
  final Color color, track;
  _RingPainter({required this.progress, required this.color,
      required this.track, required this.glow});
  @override
  void paint(Canvas c, Size s) {
    const stroke = 14.0;
    final r = Rect.fromLTWH(stroke, stroke, s.width - stroke * 2, s.height - stroke * 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    c.drawArc(r, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    final glowP = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 6 * glow
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.16 + 0.12 * glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    c.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, glowP);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    c.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.glow != glow || o.color != color;
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);
  static const _cols = [
    Color(0xFF3FB950), Color(0xFFDBA75D), Color(0xFF6FB3FF),
    Color(0xFFBC8CFF), Color(0xFFEF6A60),
  ];
  @override
  void paint(Canvas c, Size s) {
    if (t <= 0 || t >= 1) return;
    final rnd = math.Random(7);
    for (var i = 0; i < 60; i++) {
      final x0 = rnd.nextDouble() * s.width;
      final speed = 0.6 + rnd.nextDouble() * 0.9;
      final drift = (rnd.nextDouble() - 0.5) * 80;
      final spin = rnd.nextDouble() * 6;
      final y = -20 + (s.height * 0.9) * (t * speed);
      final x = x0 + drift * t;
      final p = Paint()..color = _cols[i % _cols.length].withOpacity((1 - t).clamp(0.0, 1.0).toDouble());
      c.save();
      c.translate(x, y);
      c.rotate(spin * t * 6);
      c.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -2, 8, 4), const Radius.circular(1.5)), p);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════
//  Weekly stats + history (shown on the Fitness screen)
// ══════════════════════════════════════════════════════════════════
class WorkoutStats {
  final Map<String, Map<String, num>> byDay; // date_key → {s, k, c}
  final List<Map<String, dynamic>> sessions;
  const WorkoutStats(this.byDay, this.sessions);
}

final workoutStatsProvider = FutureProvider.autoDispose<WorkoutStats>((ref) async {
  ref.watch(workoutMinutesProvider);
  final rows = await AppDatabase.getDailyWorkoutStats(7);
  final sessions = await AppDatabase.getSessions(limit: 40);
  return WorkoutStats({
    for (final r in rows)
      '${r['date_key']}': {
        's': (r['s'] as num?) ?? 0,
        'k': (r['k'] as num?) ?? 0,
        'c': (r['c'] as num?) ?? 0,
      }
  }, sessions);
});

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';

class WorkoutStatsCard extends ConsumerWidget {
  final Color card, textC, muted, accent;
  final bool isAr, isDark;
  const WorkoutStatsCard({
    super.key, required this.card, required this.textC, required this.muted,
    required this.accent, required this.isAr, required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(workoutStatsProvider);
    return data.maybeWhen(
      data: (s) {
        if (s.sessions.isEmpty) return const SizedBox.shrink();
        String t(String ar, String en) => isAr ? ar : en;
        final today = DateTime.now();
        final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
        num sumS = 0, sumK = 0, sumC = 0, maxS = 1;
        for (final d in days) {
          final m = s.byDay[_dayKey(d)];
          if (m == null) continue;
          sumS += m['s']!; sumK += m['k']!; sumC += m['c']!;
          if (m['s']! > maxS) maxS = m['s']!;
        }
        const arD = ['إث', 'ث', 'أر', 'خ', 'ج', 'س', 'ح'];
        const enD = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withOpacity(0.18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.insights_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t('أسبوعك', 'Your week'),
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 15,
                        fontWeight: FontWeight.w900, color: textC)),
              ),
              GestureDetector(
                onTap: () => showWorkoutHistory(context, s.sessions, isAr, isDark, textC, muted, accent, card),
                child: Text(t('السجل', 'History'),
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                        fontWeight: FontWeight.w800, color: accent)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _mini('${sumC.round()}', t('جلسات', 'Sessions'), textC, muted),
              _mini('${(sumS / 60).round()}', t('دقيقة', 'Minutes'), textC, muted),
              _mini('${sumK.round()}', t('سعرة', 'kcal'), textC, muted),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              height: 64,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final d in days) ...[
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        height: 4 + 38 * ((s.byDay[_dayKey(d)]?['s'] ?? 0) / maxS),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: s.byDay[_dayKey(d)] == null
                              ? textC.withOpacity(0.10)
                              : accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(isAr ? arD[d.weekday - 1] : enD[d.weekday - 1],
                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                ],
              ]),
            ),
          ]),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _mini(String v, String l, Color textC, Color muted) => Expanded(
        child: Column(children: [
          Text(v, style: TextStyle(fontFamily: 'Aligarh', fontSize: 20,
              fontWeight: FontWeight.w900, color: textC)),
          Text(l, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10.5, color: muted)),
        ]),
      );
}

void showWorkoutHistory(BuildContext context, List<Map<String, dynamic>> sessions,
    bool isAr, bool isDark, Color textC, Color muted, Color accent, Color card) {
  String t(String ar, String en) => isAr ? ar : en;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      height: MediaQuery.of(ctx).size.height * 0.7,
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: muted.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Icon(Icons.history_rounded, color: accent),
            const SizedBox(width: 10),
            Text(t('سجل التمارين', 'Workout history'),
                style: TextStyle(fontFamily: 'Aligarh', fontSize: 17,
                    fontWeight: FontWeight.w900, color: textC)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: sessions.length,
            itemBuilder: (_, i) {
              final r = sessions[i];
              final id = '${r['workout_id']}';
              final w = kWorkouts.where((x) => x.id == id).toList();
              final title = w.isEmpty ? id : (isAr ? w.first.titleAr : w.first.titleEn);
              final dt = DateTime.tryParse('${r['created']}') ?? DateTime.now();
              final mins = (((r['seconds'] as num?) ?? 0) / 60).round();
              final done = (r['steps_done'] as num?)?.toInt() ?? 0;
              final total = (r['steps_total'] as num?)?.toInt() ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: textC.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(0.14)),
                    child: Icon(Icons.fitness_center_rounded, size: 18, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 13.5,
                              fontWeight: FontWeight.w800, color: textC)),
                      Text('${dt.day}/${dt.month}  ${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}'
                          '  ·  $done/$total',
                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 10.5, color: muted)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$mins ${t("د", "min")}',
                        style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
                            fontWeight: FontWeight.w900, color: textC)),
                    Text('${((r['kcal'] as num?) ?? 0).round()} kcal',
                        style: const TextStyle(fontFamily: 'Aligarh', fontSize: 10.5,
                            color: AppColors.haramRed)),
                  ]),
                ]),
              );
            },
          ),
        ),
      ]),
    ),
  );
}
