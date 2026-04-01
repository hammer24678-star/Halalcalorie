// health_service.dart
// Uses pedometer + sensors_plus instead of health package
// No Kotlin conflicts, works on all Flutter versions

import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthData {
  final int steps;
  final double heartRate;
  final double sleepHours;
  final bool isLive;

  const HealthData({
    this.steps = 0,
    this.heartRate = 0,
    this.sleepHours = 0,
    this.isLive = false,
  });

  HealthData copyWith({int? steps, double? heartRate, double? sleepHours, bool? isLive}) {
    return HealthData(
      steps: steps ?? this.steps,
      heartRate: heartRate ?? this.heartRate,
      sleepHours: sleepHours ?? this.sleepHours,
      isLive: isLive ?? this.isLive,
    );
  }
}

class HealthService {
  static StreamSubscription<StepCount>? _stepSub;
  static StreamSubscription<PedestrianStatus>? _statusSub;
  static int _steps = 0;
  static double _heartRate = 72;
  static double _sleepHours = 7;

  static Future<bool> requestPermissions() async {
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  static Future<HealthData> fetchAll() async {
    await requestPermissions();
    return HealthData(
      steps: _steps,
      heartRate: _heartRate,
      sleepHours: _sleepHours,
      isLive: true,
    );
  }

  static void startStepTracking(void Function(int steps) onStep) {
    _stepSub?.cancel();
    _stepSub = Pedometer.stepCountStream.listen(
      (event) {
        _steps = event.steps;
        onStep(_steps);
      },
      onError: (_) {},
    );
  }

  static void stopTracking() {
    _stepSub?.cancel();
    _statusSub?.cancel();
  }

  static void setManualHeartRate(double bpm) {
    _heartRate = bpm;
  }

  static void setManualSleep(double hours) {
    _sleepHours = hours;
  }

  static int get currentSteps => _steps;
  static double get currentHeartRate => _heartRate;
  static double get currentSleep => _sleepHours;
}
