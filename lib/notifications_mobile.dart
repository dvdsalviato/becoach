import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'db.dart';
import 'models.dart';
import 'util.dart';

/// Notifiche gratuite, senza server:
/// - programmate sul telefono (fine recupero, promemoria appuntamenti): arrivano anche a schermo spento;
/// - controllo in background ogni 15 minuti circa per le novità (richieste, schede, appuntamenti…).
class Notifs {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const timerId = 900001;
  static const _alarmId = 4242;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'becoach_main',
      'BeCoach',
      channelDescription: 'Richieste, schede, appuntamenti',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_becoach',
    ),
  );

  static const _timerDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'becoach_timer',
      'Timer allenamento',
      channelDescription: 'Fine del recupero e delle serie a tempo',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'ic_stat_becoach',
      category: AndroidNotificationCategory.alarm,
    ),
  );

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    } catch (_) {}
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('ic_stat_becoach')),
    );
    _ready = true;
  }

  /// Chiede il permesso (Android 13+) e avvia il controllo periodico.
  static Future<void> setup() async {
    await init();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
    try {
      await AndroidAlarmManager.initialize();
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        _alarmId,
        backgroundCheck,
        allowWhileIdle: true,
        wakeup: true,
        rescheduleOnReboot: true,
        exact: false,
      );
    } catch (_) {}
  }

  static Future<void> show(int id, String title, String body) async {
    await init();
    await _plugin.show(id, title, body, _details);
  }

  static Future<void> _schedule(int id, DateTime at, String title, String body, NotificationDetails d) async {
    await init();
    if (at.isBefore(DateTime.now())) return;
    final when = tz.TZDateTime.from(at, tz.local);
    try {
      await _plugin.zonedSchedule(id, title, body, when, d,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
    } catch (_) {
      // senza permesso per gli allarmi esatti ripiega su un orario approssimato
      await _plugin.zonedSchedule(id, title, body, when, d,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
    }
  }

  /// Promemoria generico a una data (abbonamento, certificato, lezione prenotata).
  static Future<void> scheduleAt(int id, DateTime at, String title, String body) =>
      _schedule(id, at, title, body, _details);

  static Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  /// Fine recupero / fine serie a tempo, anche con lo schermo spento.
  static Future<void> scheduleTimer(DateTime at, String title, String body) =>
      _schedule(timerId, at, title, body, _timerDetails);

  static Future<void> cancelTimer() async {
    await init();
    await _plugin.cancel(timerId);
  }

  /// Promemoria 24 ore e 1 ora prima di ogni appuntamento futuro (prossimi 30 giorni).
  static Future<void> scheduleAppointmentReminders(List<Appointment> appts, {required bool coach}) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final key = coach ? 'reminders_coach' : 'reminders_client';
    for (final id in prefs.getStringList(key) ?? <String>[]) {
      final n = int.tryParse(id);
      if (n != null) await _plugin.cancel(n);
    }
    final now = DateTime.now();
    final ids = <String>[];
    for (final a in appts) {
      if (a.start.isBefore(now) || a.start.isAfter(now.add(const Duration(days: 30)))) continue;
      final base = 100000 + (a.id.hashCode & 0x3ffff) * 2;
      final who = coach ? (a.clientName.isEmpty ? '' : ' con ${a.clientName}') : ' con il coach';
      final day = a.start.add(const Duration(hours: -24));
      final hour = a.start.add(const Duration(hours: -1));
      await _schedule(base, day, 'Domani: ${a.title}', '${fmtTime(a.start)}$who', _details);
      await _schedule(base + 1, hour, 'Tra un\'ora: ${a.title}', '${fmtTime(a.start)}$who', _details);
      ids..add('$base')..add('${base + 1}');
    }
    await prefs.setStringList(key, ids);
  }
}

/// Eseguito in background ogni 15 minuti circa, anche ad app chiusa.
@pragma('vm:entry-point')
Future<void> backgroundCheck() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await Firebase.initializeApp();
    final user = await FirebaseAuth.instance.authStateChanges().first;
    if (user == null) return;
    await Notifs.init();
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('bg_last_check_${user.uid}');
    final now = DateTime.now();
    await prefs.setInt('bg_last_check_${user.uid}', now.millisecondsSinceEpoch);
    if (lastMs == null) return; // prima esecuzione: segna solo l'orario
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final fs = FirebaseFirestore.instance;
    final meDoc = await fs.collection('users').doc(user.uid).get();
    if (!meDoc.exists) return;
    final me = AppUser.fromDoc(meDoc);
    bool isNew(DateTime? t) => t != null && t.isAfter(last);
    var n = 0;

    if (me.coachMode) {
      // nuove richieste di appuntamento
      final reqs = await Db.requestsRef(me.uid).get();
      for (final d in reqs.docs) {
        final r = AppointmentRequest.fromDoc(me.uid, d);
        if (r.pending && isNew(r.createdAt)) {
          await Notifs.show(1000 + n++, 'Nuova richiesta: ${r.type}', '${r.athleteName} chiede un appuntamento');
        }
      }
      // clienti che hanno iniziato ad allenarsi
      final live = await Db.sessions.where('coachId', isEqualTo: me.uid).get();
      for (final d in live.docs) {
        final s = Session.fromDoc(d);
        if (s.isLive && isNew(s.startedAt)) {
          await Notifs.show(1000 + n++, '${s.athleteName} si sta allenando', s.dayName);
        }
      }
      // nuovi clienti collegati con il codice
      final clients = await Db.users.where('coachId', isEqualTo: me.uid).get();
      for (final d in clients.docs) {
        final joined = d.data()['joinedAt'];
        if (joined is Timestamp && isNew(joined.toDate())) {
          await Notifs.show(1000 + n++, 'Nuovo cliente', '${d.data()['name'] ?? 'Un cliente'} si è collegato a te');
        }
      }
      final appts = await Db.appointmentsRef(me.uid).get();
      await Notifs.scheduleAppointmentReminders(appts.docs.map(Appointment.fromDoc).toList(), coach: true);
    } else if (me.hasCoach) {
      final coachId = me.coachId!;
      // scheda nuova o aggiornata
      final plans = await Db.plans.where('athleteId', isEqualTo: me.uid).get();
      for (final d in plans.docs) {
        final p = Plan.fromDoc(d);
        if (p.active && p.coachId == coachId && isNew(p.updatedAt)) {
          await Notifs.show(1000 + n++, 'Scheda aggiornata', '${me.coachName ?? 'Il coach'} ha preparato "${p.name}"');
        }
      }
      // appuntamenti fissati o modificati dal coach
      final appts = await Db.appointmentsRef(coachId).where('clientId', isEqualTo: me.uid).get();
      final list = <Appointment>[];
      for (final d in appts.docs) {
        final a = Appointment.fromDoc(d);
        list.add(a);
        final upd = d.data()['updatedAt'];
        if (upd is Timestamp && isNew(upd.toDate()) && a.start.isAfter(now)) {
          await Notifs.show(1000 + n++, 'Appuntamento: ${a.title}', '${fmtDate(a.start)} alle ${fmtTime(a.start)}');
        }
      }
      await Notifs.scheduleAppointmentReminders(list, coach: false);
      // richieste rifiutate
      final reqs = await Db.requestsRef(coachId).where('athleteId', isEqualTo: me.uid).get();
      for (final d in reqs.docs) {
        final r = AppointmentRequest.fromDoc(coachId, d);
        final upd = d.data()['updatedAt'];
        if (r.status == 'declined' && upd is Timestamp && isNew(upd.toDate())) {
          await Notifs.show(1000 + n++, 'Richiesta non confermata', 'Il coach non ha confermato: ${r.type}');
        }
      }
    }
  } catch (_) {
    // in background non c'è nessuno a cui mostrare l'errore: si riprova al giro dopo
  }
}
