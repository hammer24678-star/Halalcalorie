// health_service.dart — HalalCalorie v1.0
// Uses health package only (no pedometer)

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  static final Health _health = Health();
  static int _steps = 0;
  static double _heartRate = 72;
  static double _sleepHours = 7;

  static Future<bool> requestPermissions() async {
    await Permission.activityRecognition.request();
    final types = [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_ASLEEP,
    ];
    try {
      return await _health.requestAuthorization(types);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isAuthorized() async {
    try {
      return await _health.requestAuthorization([HealthDataType.STEPS],
          permissions: [HealthDataAccess.READ]);
    } catch (_) {
      return false;
    }
  }

  static Future<int> fetchTodaySteps() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.STEPS],
      );
      int total = 0;
      for (final d in data) {
        total += (d.value as NumericHealthValue).numericValue.toInt();
      }
      _steps = total;
      return total;
    } catch (_) {
      return _steps;
    }
  }

  static Future<double> fetchHeartRate() async {
    try {
      final now = DateTime.now();
      final data = await _health.getHealthDataFromTypes(
        startTime: now.subtract(const Duration(hours: 1)),
        endTime: now,
        types: [HealthDataType.HEART_RATE],
      );
      if (data.isNotEmpty) {
        _heartRate =
            (data.last.value as NumericHealthValue).numericValue.toDouble();
      }
      return _heartRate;
    } catch (_) {
      return _heartRate;
    }
  }

  static void stopTracking() {}
  static void setManualHeartRate(double bpm) => _heartRate = bpm;
  static void setManualSleep(double hours) => _sleepHours = hours;
  static int get currentSteps => _steps;
  static double get currentHeartRate => _heartRate;
  static double get currentSleep => _sleepHours;
}
