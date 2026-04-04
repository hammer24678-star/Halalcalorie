// health_service.dart — stub for v1 crash fix
// sensors_plus removed — was causing race condition on startup
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static int _steps = 0;
  static double _heartRate = 72;
  static double _sleepHours = 7;

  static Future<bool> requestPermissions() async {
    try {
      await Permission.activityRecognition.request();
    } catch (_) {}
    return true;
  }

  static Future<bool> isAuthorized() async => true;

  static Future<void> startStepTracking(void Function(int) onStep) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (prefs.getString('steps_date') == today) {
        _steps = prefs.getInt('steps_count') ?? 0;
      } else {
        _steps = 0;
        await prefs.setString('steps_date', today);
        await prefs.setInt('steps_count', 0);
      }
      onStep(_steps);
    } catch (_) {}
  }

  static void stopTracking() {}
  static void setManualHeartRate(double bpm) => _heartRate = bpm;
  static void setManualSleep(double hours) => _sleepHours = hours;
  static void addSteps(int s) async {
    _steps += s;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('steps_count', _steps);
    } catch (_) {}
  }

  static Future<int> fetchTodaySteps() async => _steps;
  static Future<double> fetchHeartRate() async => _heartRate;
  static int get currentSteps => _steps;
  static double get currentHeartRate => _heartRate;
  static double get currentSleep => _sleepHours;
}
