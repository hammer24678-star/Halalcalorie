// notification_service.dart — stub for v1
// flutter_local_notifications restored in v2 with proper Android permissions:
// POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, FOREGROUND_SERVICE, RECEIVE_BOOT_COMPLETED
class NotificationService {
  static Future<void> init() async {}
  static Future<void> requestPermissions() async {}
  static Future<void> scheduleWaterReminder() async {}
  static Future<void> scheduleWorkoutReminder() async {}
  static Future<void> scheduleMealReminder() async {}
  static Future<void> cancelAll() async {}
}
