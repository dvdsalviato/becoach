import 'models.dart';

/// Sul web (iPhone) non ci sono notifiche locali: i promemoria arrivano dal calendario del telefono.
class Notifs {
  static const timerId = 900001;
  static Future<void> init() async {}
  static Future<void> setup() async {}
  static Future<void> show(int id, String title, String body) async {}
  static Future<void> scheduleTimer(DateTime at, String title, String body) async {}
  static Future<void> cancelTimer() async {}
  static Future<void> scheduleAt(int id, DateTime at, String title, String body) async {}
  static Future<void> cancel(int id) async {}
  static Future<void> scheduleAppointmentReminders(List<Appointment> appts, {required bool coach}) async {}
}

Future<void> backgroundCheck() async {}
