// health_service.dart — HalalCalorie
// Uses sensors_plus accelerometer for step detection.
// NOTE: Background step tracking requires pedometer package + SDK 35.
// Current Codemagic CI has a corrupted SDK 35 — tracked for future fix.
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthService {
  static StreamSubscription? _accelSub;
  static Timer? _saveTimer;

  static double _heartRate  = 72;
  static double _sleepHours = 7;
  static int    _steps      = 0;

  // Step detection state
  static double _lastMag       = 0;
  static bool   _stepUp        = false;
  static const  _threshold     = 11.0;

  static Future<bool> requestPermissions() async => true;
  static Future<bool> isAuthorized()       async => true;

  static Future<void> startStepTracking(
    void Function(int steps) onStep, {
    void Function(String)? onStatus,
  }) async {
    await _loadSteps();
    onStep(_steps);

    _accelSub?.cancel();
    _accelSub = accelerometerEventStream().listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      if (!_stepUp && mag > _threshold) {
        _stepUp = true;
        _steps++;
        onStep(_steps);
        _throttleSave();
      } else if (_stepUp && mag < _threshold - 1.5) {
        _stepUp = false;
      }
      _lastMag = mag;
    }, cancelOnError: false);
  }

  static Future<void> _loadSteps() async {
    try {
      final p    = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if ((p.getString('steps_date') ?? '') == today) {
        _steps = p.getInt('steps_count') ?? 0;
      } else {
        _steps = 0;
        await p.setString('steps_date', today);
        await p.setInt('steps_count', 0);
      }
    } catch (_) {}
  }

  static void _throttleSave() {
    if (_saveTimer?.isActive ?? false) return;
    _saveTimer = Timer(const Duration(seconds: 10), () async {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setInt('steps_count', _steps);
      } catch (_) {}
    });
  }

  static void stopTracking() {
    _accelSub?.cancel(); _accelSub = null;
    _saveTimer?.cancel(); _saveTimer = null;
  }

  static void addSteps(int s) => _steps += s;
  static void setManualHeartRate(double v) => _heartRate = v;
  static void setManualSleep(double v)     => _sleepHours = v;

  static Future<int>    fetchTodaySteps() async => _steps;
  static Future<double> fetchHeartRate()  async => _heartRate;
  static int    get currentSteps     => _steps;
  static double get currentHeartRate => _heartRate;
  static double get currentSleep     => _sleepHours;
}
