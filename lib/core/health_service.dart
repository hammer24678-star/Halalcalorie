// health_service.dart — HalalCalorie Build 55
// Uses accurate_step_counter which wraps Android's TYPE_STEP_COUNTER
// hardware sensor in a foreground service. Steps count in:
//   • Foreground  ✅
//   • Background  ✅  (foreground service keeps running)
//   • Killed      ✅  (hardware sensor delta synced on next launch)
// A persistent system notification shows while tracking —
// required by Android for all foreground services.
import 'dart:async';
import 'package:accurate_step_counter/accurate_step_counter.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final _counter   = AccurateStepCounter();
  static StreamSubscription<int>? _sub;
  static bool   _ready       = false;
  static int    _stepsToday  = 0;
  static double _heartRate   = 72;
  static double _sleepHours  = 7;
  static void Function(int)? _onStep;

  // ── Permissions ──────────────────────────────────────────────────
  static Future<bool> requestPermissions() async {
    try {
      await Permission.activityRecognition.request();
      await Permission.notification.request();
    } catch (_) {}
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

    if (!_ready) {
      try {
        await _counter.setNotificationContent(
          title: 'HalalCalorie فيتنس',
          body: 'Counting your steps in the background...',
        );
        await _counter.initializeLogging(useBackgroundIsolate: false);
        await _counter.start(config: StepDetectorConfig.walking());
        await _counter.startLogging(config: StepRecordConfig.aggregated());
        _ready = true;
      } catch (_) {
        // Device has no step sensor — degrade silently
        onStep(0);
        return;
      }
    }

    // Emit persisted count immediately (no blank screen)
    try {
      _stepsToday = await _counter.getTodaySteps();
      onStep(_stepsToday);
    } catch (_) {}

    // Live stream
    await _sub?.cancel();
    _sub = _counter.watchAggregatedStepCounter().listen(
      (steps) { _stepsToday = steps; _onStep?.call(steps); },
      onError: (_) {},
      cancelOnError: false,
    );

    // Catch steps missed while app was killed
    _counter.onTerminatedStepsDetected = (steps, from, to) {
      _stepsToday = steps;
      _onStep?.call(steps);
    };
  }

  // ── Stop (cancels Dart stream; foreground service keeps running) ──
  static void stopTracking() {
    _sub?.cancel();
    _sub = null;
  }

  // ── Lifecycle hook — call from didChangeAppLifecycleState ─────────
  static void onAppStateChange(AppLifecycleState state) {
    if (_ready) _counter.setAppState(state);
  }

  // ── Helpers ───────────────────────────────────────────────────────
  static void setManualHeartRate(double v) => _heartRate = v;
  static void setManualSleep(double v)     => _sleepHours = v;
  static void addSteps(int s) { _stepsToday += s; _onStep?.call(_stepsToday); }

  static Future<int> fetchTodaySteps() async {
    if (_ready) { try { _stepsToday = await _counter.getTodaySteps(); } catch (_) {} }
    return _stepsToday;
  }
  static Future<double> fetchHeartRate() async => _heartRate;
  static int    get currentSteps     => _stepsToday;
  static double get currentHeartRate => _heartRate;
  static double get currentSleep     => _sleepHours;
}
