import 'package:flutter/material.dart';

import 'calendar_export_mobile.dart' if (dart.library.js_interop) 'calendar_export_web.dart' as impl;
import 'models.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _utc(DateTime d) {
  final u = d.toUtc();
  return '${u.year}${_two(u.month)}${_two(u.day)}T${_two(u.hour)}${_two(u.minute)}${_two(u.second)}Z';
}

String _esc(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll(';', '\;').replaceAll(',', '\\,').replaceAll('\n', '\\n');

/// File .ics con due promemoria: il giorno prima e un'ora prima.
String buildIcs(Appointment a, {String who = ''}) {
  final title = who.isEmpty ? a.title : '${a.title} · $who';
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//BeCoach//IT',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:${a.id.isEmpty ? a.start.millisecondsSinceEpoch : a.id}@becoach',
    'DTSTAMP:${_utc(DateTime.now())}',
    'DTSTART:${_utc(a.start)}',
    'DTEND:${_utc(a.end)}',
    'SUMMARY:${_esc(title)}',
    if (a.notes.isNotEmpty) 'DESCRIPTION:${_esc(a.notes)}',
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'DESCRIPTION:${_esc(title)}',
    'TRIGGER:-P1D',
    'END:VALARM',
    'BEGIN:VALARM',
    'ACTION:DISPLAY',
    'DESCRIPTION:${_esc(title)}',
    'TRIGGER:-PT1H',
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');
}

/// Link di Google Calendar con l'evento già compilato.
String googleCalendarLink(Appointment a, {String who = ''}) {
  final title = who.isEmpty ? a.title : '${a.title} · $who';
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${_utc(a.start)}/${_utc(a.end)}',
    if (a.notes.isNotEmpty) 'details': a.notes,
  }).toString();
}

/// Aggiunge l'appuntamento al calendario del telefono, che poi manda i promemoria.
Future<void> addToCalendar(BuildContext context, Appointment a, {String who = ''}) =>
    impl.addToCalendar(context, a, buildIcs(a, who: who), googleCalendarLink(a, who: who));
