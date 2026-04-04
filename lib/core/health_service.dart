// health_service.dart — HalalCalorie v1.0
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthService {
  static StreamSubscription? _accelSub;
  static int _steps = 0;
  static double _lastMagnitude = 0;
  static bool _wasAboveThreshold = false;
  static const double _threshold = 12.0;
  static const double _minMagnitude = 9.0;
  static double _heartRate = 72;
  static double _sleepHours = 7;
  static void Function(int)? _onStep;

  static Future<bool> requestPermissions() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted || status.isLimited;
  }

  static Future<bool> isAuthorized() async => true;

  static Future<void> startStepTracking(void Function(int) onStep) async {
    _onStep = onStep;
    await requestPermissions();
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDay = prefs.getString('steps_date') ?? '';
    if (savedDay == today) {
      _steps = prefs.getInt('steps_count') ?? 0;
    } else {
      _steps = 0;
      await prefs.setString('steps_date', today);
      await prefs.setInt('steps_count', 0);
    }
    onStep(_steps);
    _accelSub?.cancel();
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent e) {
      final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      if (magnitude > _threshold && !_wasAboveThreshold && magnitude > _lastMagnitude) {
        _wasAboveThreshold = true;
        _steps++;
        _onStep?.call(_steps);
        _saveSteps();
      } else if (magnitude < _minMagnitude) {
        _wasAboveThreshold = false;
      }
      _lastMagnitude = magnitude;
    });
  }

  static Future<void> _saveSteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('steps_count', _steps);
  }

  static void stopTracking() { _accelSub?.cancel(); _accelSub = null; }
  static void setManualHeartRate(double bpm) => _heartRate = bpm;
  static void setManualSleep(double hours) => _sleepHours = hours;
  static void addSteps(int s) { _steps += s; _saveSteps(); _onStep?.call(_steps); }
  static Future<int> fetchTodaySteps() async => _steps;
  static Future<double> fetchHeartRate() async => _heartRate;
  static int get currentSteps => _steps;
  static double get currentHeartRate => _heartRate;
  static double get currentSleep => _sleepHours;
}
