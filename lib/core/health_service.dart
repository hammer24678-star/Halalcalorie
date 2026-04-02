// health_service.dart — HalalCalorie v1.0
// Manual entry only — health package restored in v2 on newer runner

import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static int _steps = 0;
  static double _heartRate = 72;
  static double _sleepHours = 7;

  static Future<bool> requestPermissions() async {
    await Permission.activityRecognition.request();
    return true;
  }

  static Future<bool> isAuthorized() async => true;
  static Future<int> fetchTodaySteps() async => _steps;
  static Future<double> fetchHeartRate() async => _heartRate;
  static void stopTracking() {}
  static void setManualHeartRate(double bpm) => _heartRate = bpm;
  static void setManualSleep(double hours) => _sleepHours = hours;
  static void addSteps(int s) => _steps += s;
  static int get currentSteps => _steps;
  static double get currentHeartRate => _heartRate;
  static double get currentSleep => _sleepHours;
}
