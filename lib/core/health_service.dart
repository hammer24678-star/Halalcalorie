// health_service.dart — HalalCalorie Build 39
// Uses the `pedometer` package which wraps:
//   Android → TYPE_STEP_COUNTER (hardware chip, background-capable)
//   iOS     → CMPedometer       (CoreMotion, background-capable)
// The hardware step counter runs independently of the app process,
// so steps accumulate even when the app is closed or backgrounded.
import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthService {
  static StreamSubscription<StepCount>?       _stepSub;
  static StreamSubscription<PedestrianStatus>? _statusSub;

  static int    _stepsToday  = 0;
  static int    _stepOffset  = 0;
  static bool   _offsetReady = false;
  static double _heartRate   = 72;
  static double _sleepHours  = 7;

  static void Function(int)?    _onStep;
  static void Function(String)? _onStatus;
  static Timer? _saveTimer;

  static Future<bool> requestPermissions() async {
    try {
      final status = await Permission.activityRecognition.request();
      return status.isGranted || status.isLimited;
    } catch (_) { return true; }
  }

  static Future<bool> isAuthorized() async => true;

  static Future<void> startStepTracking(
    void Function(int steps) onStep, {
    void Function(String status)? onStatus,
  }) async {
    _onStep   = onStep;
    _onStatus = onStatus;
    await requestPermissions();
    await _loadPersistedSteps();
    _onStep?.call(_stepsToday);
    await _stepSub?.cancel();
    await _statusSub?.cancel();

    _stepSub = Pedometer.stepCountStream.listen(
      (StepCount event) {
        final raw = event.steps;
        if (!_offsetReady) {
          _offsetReady = true;
          if (_stepOffset == 0) {
            _stepOffset = raw - _stepsToday;
            _persistOffset(_stepOffset);
          }
        }
        final today = (raw - _stepOffset).clamp(0, 999999);
        if (today != _stepsToday) {
          _stepsToday = today;
          _onStep?.call(_stepsToday);
          _throttledSave();
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );

    _statusSub = Pedometer.pedestrianStatusStream.listen(
      (PedestrianStatus event) => _onStatus?.call(event.status),
      onError: (_) {},
      cancelOnError: false,
    );
  }

  static Future<void> _loadPersistedSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final savedDate = prefs.getString('steps_date') ?? '';
      if (savedDate == today) {
        _stepsToday  = prefs.getInt('steps_count')  ?? 0;
        _stepOffset  = prefs.getInt('steps_offset') ?? 0;
        _offsetReady = _stepOffset != 0;
      } else {
        _stepsToday = 0; _stepOffset = 0; _offsetReady = false;
        await prefs.setString('steps_date',  today);
        await prefs.setInt('steps_count',    0);
        await prefs.setInt('steps_offset',   0);
      }
    } catch (_) {}
  }

  static void _throttledSave() {
    if (_saveTimer?.isActive ?? false) return;
    _saveTimer = Timer(const Duration(seconds: 8), _saveSteps);
  }

  static Future<void> _saveSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('steps_count', _stepsToday);
    } catch (_) {}
  }

  static Future<void> _persistOffset(int offset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('steps_offset', offset);
    } catch (_) {}
  }

  static void addSteps(int s) { _stepsToday += s; _saveSteps(); _onStep?.call(_stepsToday); }

  static void stopTracking() {
    try {
      _stepSub?.cancel();   _stepSub   = null;
      _statusSub?.cancel(); _statusSub = null;
      _saveTimer?.cancel(); _saveTimer = null;
    } catch (_) {}
  }

  static void setManualHeartRate(double bpm) => _heartRate = bpm;
  static void setManualSleep(double hours)   => _sleepHours = hours;
  static Future<int>    fetchTodaySteps()  async => _stepsToday;
  static Future<double> fetchHeartRate()   async => _heartRate;
  static int    get currentSteps     => _stepsToday;
  static double get currentHeartRate => _heartRate;
  static double get currentSleep     => _sleepHours;
}
