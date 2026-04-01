import 'package:health/health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

class HealthService {
  static final HealthFactory _health = HealthFactory();
  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
  ];

  static Future<bool> requestPermissions() async {
    try {
      return await _health.requestAuthorization(_types);
    } catch (_) { return false; }
  }

  static Future<int> getSteps() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(midnight, now, [HealthDataType.STEPS]);
      return data.fold(0, (sum, e) => sum + (e.value as NumericHealthValue).numericValue.toInt());
    } catch (_) { return 0; }
  }

  static Future<double> getSleep() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 16));
      final data = await _health.getHealthDataFromTypes(yesterday, now, [HealthDataType.SLEEP_ASLEEP]);
      final mins = data.fold(0.0, (sum, e) => sum + (e.value as NumericHealthValue).numericValue.toDouble());
      return mins / 60;
    } catch (_) { return 0; }
  }

  static Future<int> getHeartRate() async {
    try {
      final now = DateTime.now();
      final hour = now.subtract(const Duration(hours: 1));
      final data = await _health.getHealthDataFromTypes(hour, now, [HealthDataType.HEART_RATE]);
      if (data.isEmpty) return 0;
      return (data.last.value as NumericHealthValue).numericValue.toInt();
    } catch (_) { return 0; }
  }

  static Future<void> syncToday(WidgetRef ref) async {
    try {
      final steps = await getSteps();
      final sleep = await getSleep();
      final hr    = await getHeartRate();
      if (steps > 0) await ref.read(healthProvider.notifier).setSteps(steps);
      if (sleep > 0) await ref.read(sleepProvider.notifier).set(sleep);
      if (hr > 0) ref.read(healthProvider.notifier).setHeartRate(hr);
    } catch (_) {}
  }
}
