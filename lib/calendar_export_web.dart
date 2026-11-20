import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'models.dart';

/// Web (iPhone): apre il file .ics, Safari propone "Aggiungi al Calendario" con i promemoria.
Future<void> addToCalendar(BuildContext context, Appointment a, String ics, String googleLink) async {
  web.window.location.href = 'data:text/calendar;charset=utf-8,${Uri.encodeComponent(ics)}';
}
