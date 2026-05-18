import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthService {
  static StreamSubscription<StepCount>?        _stepSub;
  static StreamSubscription<PedestrianStatus>? _statusSub;
  static Timer? _saveTimer;

  static int    _stepsToday  = 0;
  static int    _stepOffset  = 0;
  static bool   _offsetReady = false;
  static double _heartRate   = 72;
  static double _sleepHours  = 7;

  static void Function(int)?    _onStep;
  static void Function(String)? _onStatus;

  static Future<bool> requestPermissions() async {
    try { return (await Permission.activityRecognition.request()).isGranted; }
    catch (_) { return true; }
  }
  static Future<bool> isAuthorized() async => true;

  static Future<void> startStepTracking(void Function(int) onStep,
      {void Function(String)? onStatus}) async {
    _onStep = onStep; _onStatus = onStatus;
    await requestPermissions();
    await _load();
    _onStep?.call(_stepsToday);
    await _stepSub?.cancel();
    await _statusSub?.cancel();

    _stepSub = Pedometer.stepCountStream.listen((StepCount e) {
      if (!_offsetReady) {
        _offsetReady = true;
        if (_stepOffset == 0) { _stepOffset = e.steps - _stepsToday; _saveOffset(); }
      }
      final t = (e.steps - _stepOffset).clamp(0, 999999);
      if (t != _stepsToday) { _stepsToday = t; _onStep?.call(t); _throttleSave(); }
    }, onError: (_) {}, cancelOnError: false);

    _statusSub = Pedometer.pedestrianStatusStream.listen(
        (PedestrianStatus e) => _onStatus?.call(e.status),
        onError: (_) {}, cancelOnError: false);
  }

  static Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if ((p.getString('steps_date') ?? '') == today) {
        _stepsToday = p.getInt('steps_count')  ?? 0;
        _stepOffset = p.getInt('steps_offset') ?? 0;
        _offsetReady = _stepOffset != 0;
      } else {
        _stepsToday = 0; _stepOffset = 0; _offsetReady = false;
        await p.setString('steps_date', today);
        await p.setInt('steps_count',  0);
        await p.setInt('steps_offset', 0);
      }
    } catch (_) {}
  }

  static void _throttleSave() {
    if (_saveTimer?.isActive ?? false) return;
    _saveTimer = Timer(const Duration(seconds: 8), () async {
      try { final p = await SharedPreferences.getInstance();
            await p.setInt('steps_count', _stepsToday); } catch (_) {}
    });
  }

  static Future<void> _saveOffset() async {
    try { final p = await SharedPreferences.getInstance();
          await p.setInt('steps_offset', _stepOffset); } catch (_) {}
  }

  static void stopTracking() {
    _stepSub?.cancel();   _stepSub   = null;
    _statusSub?.cancel(); _statusSub = null;
    _saveTimer?.cancel(); _saveTimer = null;
  }

  static void addSteps(int s) { _stepsToday += s; _throttleSave(); _onStep?.call(_stepsToday); }
  static void setManualHeartRate(double v) => _heartRate = v;
  static void setManualSleep(double v)     => _sleepHours = v;
  static Future<int>    fetchTodaySteps() async => _stepsToday;
  static Future<double> fetchHeartRate()  async => _heartRate;
  static int    get currentSteps     => _stepsToday;
  static double get currentHeartRate => _heartRate;
  static double get currentSleep     => _sleepHours;
}
