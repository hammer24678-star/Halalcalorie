import 'package:shared_preferences/shared_preferences.dart';

class HealthService {
  static int _steps = 0;
  static double _heartRate = 72;
  static double _sleepHours = 7;

  static Future<bool> requestPermissions() async => true;
  static Future<bool> isAuthorized() async => true;
  static Future<void> startStepTracking(void Function(int) onStep) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0,10);
      if (prefs.getString('steps_date') == today) {
        _steps = prefs.getInt('steps_count') ?? 0;
      } else {
        _steps = 0;
        await prefs.setString('steps_date', today);
        await prefs.setInt('steps_count', 0);
      }
      onStep(_steps);
    } catch(_) {}
  }
  static void stopTracking() {}
  static void setManualHeartRate(double bpm) => _heartRate = bpm;
  static void setManualSleep(double hours) => _sleepHours = hours;
  static void addSteps(int s) => _steps += s;
  static Future<int> fetchTodaySteps() async => _steps;
  static Future<double> fetchHeartRate() async => _heartRate;
  static int get currentSteps => _steps;
  static double get currentHeartRate => _heartRate;
  static double get currentSleep => _sleepHours;
}
