import '../models/orientation_models.dart';

class LocalReminderService {
  LocalReminderService._();
  static final instance = LocalReminderService._();
  Future<void> initialize() async {}
  Future<void> scheduleForAppointment(OrientationAppointment appointment) async {}
  Future<void> cancel(String id) async {}
}
