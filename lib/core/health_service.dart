// health_service.dart — HalalCalorie Build 56
// Uses pedometer package (compatible with Flutter 3.22 / Dart 3.4)
import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static StreamSubscription<StepCount>? _sub;
  static int    _baseline    = -1;
  static int    _stepsToday  = 0;
  static double _heartRate   = 72;
  static double _sleepHours  = 7;
  static void Function(int)? _onStep;

  // ── Permissions ──────────────────────────────────────────────────
  static Future<bool> requestPermissions() async {
    try { await Permission.activityRecognition.request(); } catch (_) {}
    return true;
  }
  static Future<bool> isAuthorized() async => true;

  // ── Start ────────────────────────────────────────────────────────
  static Future<void> startStepTracking(
    void Function(int steps) onStep, {
    void Function(String)? onStatus,
  }) async {
    _onStep = onStep;
    await requestPermissions();

    await _sub?.cancel();
    _baseline = -1;

    try {
      _sub = Pedometer.stepCountStream.listen(
        (StepCount e) {
          // First event sets baseline so we count from 0 per session
          if (_baseline < 0) _baseline = e.steps;
          _stepsToday = e.steps - _baseline;
          if (_stepsToday < 0) _stepsToday = 0;
          _onStep?.call(_stepsToday);
        },
        onError: (_) => onStep(_stepsToday),
        cancelOnError: false,
      );
    } catch (_) {
      onStep(0);
    }
  }

  // ── Stop ─────────────────────────────────────────────────────────
  static void stopTracking() {
    _sub?.cancel();
    _sub = null;
  }

  // ── Lifecycle hook (no-op — pedometer handles background) ────────
  static void onAppStateChange(AppLifecycleState state) {}

  // ── Helpers ───────────────────────────────────────────────────────
  static void setManualHeartRate(double v) => _heartRate = v;
  static void setManualSleep(double v)     => _sleepHours = v;
  static void addSteps(int s) { _stepsToday += s; _onStep?.call(_stepsToday); }

  static Future<int>    fetchTodaySteps()  async => _stepsToday;
  static Future<double> fetchHeartRate()   async => _heartRate;
  static int    get currentSteps          => _stepsToday;
  static double get currentHeartRate      => _heartRate;
  static double get currentSleepHours     => _sleepHours;
}
