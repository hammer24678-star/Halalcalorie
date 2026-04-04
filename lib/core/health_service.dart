class HealthService {
  static Future<bool> requestPermissions() async => true;
  static Future<bool> isAuthorized() async => true;
  static Future<void> startStepTracking(void Function(int) onStep) async {}
  static void stopTracking() {}
  static void setManualHeartRate(double bpm) {}
  static void setManualSleep(double hours) {}
  static void addSteps(int s) {}
  static int get currentSteps => 0;
  static double get currentHeartRate => 72;
  static double get currentSleep => 7;
}
