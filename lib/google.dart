import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Accesso a Google: login, Google Calendar e caricamento video su Google Drive.
class Google {
  static final GoogleSignIn signIn = GoogleSignIn(scopes: ['email']);

  static const calendarScope = 'https://www.googleapis.com/auth/calendar.events';
  static const driveScope = 'https://www.googleapis.com/auth/drive.file';

  /// Restituisce gli header di autorizzazione con i permessi richiesti,
  /// chiedendo l'accesso all'utente se serve.
  static Future<Map<String, String>> _headers(List<String> scopes) async {
    var acc = signIn.currentUser ?? await signIn.signInSilently();
    acc ??= await signIn.signIn();
    if (acc == null) throw GoogleException('Accesso a Google annullato');
    final ok = await signIn.requestScopes(scopes);
    if (!ok) throw GoogleException('Permesso negato');
    final current = signIn.currentUser ?? acc;
    return current.authHeaders;
  }

  static String? get email => signIn.currentUser?.email;

  /// Chiede il permesso per Google Calendar. Restituisce l'email dell'account usato.
  static Future<String> connectCalendar() async {
    await _headers([calendarScope]);
    return signIn.currentUser?.email ?? '';
  }

  static void _check(http.Response r, String what) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    String msg = r.body;
    try {
      final j = jsonDecode(r.body);
      msg = (j['error']?['message'] as String?) ?? msg;
    } catch (_) {}
    if (r.statusCode == 403 && msg.toLowerCase().contains('not been used')) {
      msg = 'API non attiva nel progetto Google Cloud ($what)';
    }
    throw GoogleException('$what: $msg');
  }

  // ---------------- Calendar ----------------

  static const _cal = 'https://www.googleapis.com/calendar/v3/calendars/primary/events';

  static Map<String, dynamic> _eventBody({
    required String title,
    required String description,
    required DateTime start,
    required DateTime end,
    String? attendeeEmail,
  }) =>
      {
        'summary': title,
        'description': description,
        'start': {'dateTime': start.toUtc().toIso8601String(), 'timeZone': 'Europe/Rome'},
        'end': {'dateTime': end.toUtc().toIso8601String(), 'timeZone': 'Europe/Rome'},
        if (attendeeEmail != null && attendeeEmail.isNotEmpty)
          'attendees': [
            {'email': attendeeEmail}
          ],
        'reminders': {
          'useDefault': false,
          'overrides': [
            {'method': 'email', 'minutes': 1440},
            {'method': 'popup', 'minutes': 60},
          ],
        },
      };

  /// Crea l'evento e restituisce il suo id. Se c'è un invitato, Google gli manda
  /// l'invito e i promemoria via email.
  static Future<String> createEvent({
    required String title,
    required String description,
    required DateTime start,
    required DateTime end,
    String? attendeeEmail,
  }) async {
    final h = await _headers([calendarScope]);
    final r = await http.post(
      Uri.parse('$_cal?sendUpdates=all'),
      headers: {...h, 'Content-Type': 'application/json'},
      body: jsonEncode(_eventBody(
          title: title, description: description, start: start, end: end, attendeeEmail: attendeeEmail)),
    );
    _check(r, 'Google Calendar');
    return (jsonDecode(r.body)['id'] as String?) ?? '';
  }

  static Future<void> updateEvent(
    String id, {
    required String title,
    required String description,
    required DateTime start,
    required DateTime end,
    String? attendeeEmail,
  }) async {
    final h = await _headers([calendarScope]);
    final r = await http.patch(
      Uri.parse('$_cal/$id?sendUpdates=all'),
      headers: {...h, 'Content-Type': 'application/json'},
      body: jsonEncode(_eventBody(
          title: title, description: description, start: start, end: end, attendeeEmail: attendeeEmail)),
    );
    _check(r, 'Google Calendar');
  }

  static Future<void> deleteEvent(String id) async {
    final h = await _headers([calendarScope]);
    final r = await http.delete(Uri.parse('$_cal/$id?sendUpdates=all'), headers: h);
    if (r.statusCode == 404 || r.statusCode == 410) return; // già eliminato
    _check(r, 'Google Calendar');
  }

  /// Eventi di Google Calendar nell'intervallo (solo quelli con orario).
  static Future<List<GoogleEvent>> listEvents(DateTime from, DateTime to) async {
    final h = await _headers([calendarScope]);
    final uri = Uri.parse(_cal).replace(queryParameters: {
      'timeMin': from.toUtc().toIso8601String(),
      'timeMax': to.toUtc().toIso8601String(),
      'singleEvents': 'true',
      'orderBy': 'startTime',
      'maxResults': '250',
    });
    final r = await http.get(uri, headers: h);
    _check(r, 'Google Calendar');
    final items = (jsonDecode(r.body)['items'] as List? ?? []);
    final out = <GoogleEvent>[];
    for (final it in items) {
      if (it is! Map) continue;
      final s = it['start']?['dateTime'] as String?;
      final e = it['end']?['dateTime'] as String?;
      final sd = it['start']?['date'] as String?;
      DateTime? start = s != null ? DateTime.tryParse(s)?.toLocal() : null;
      DateTime? end = e != null ? DateTime.tryParse(e)?.toLocal() : null;
      var allDay = false;
      if (start == null && sd != null) {
        start = DateTime.tryParse(sd);
        end = start?.add(const Duration(days: 1));
        allDay = true;
      }
      if (start == null) continue;
      out.add(GoogleEvent(
        id: (it['id'] as String?) ?? '',
        title: (it['summary'] as String?) ?? '(senza titolo)',
        description: (it['description'] as String?) ?? '',
        start: start,
        end: end ?? start.add(const Duration(hours: 1)),
        allDay: allDay,
      ));
    }
    return out;
  }

  // ---------------- Drive ----------------

  /// Carica un video sul Google Drive dell'utente, lo rende visibile a chi ha il link
  /// e restituisce il link da aprire.
  static Future<String> uploadVideo(Uint8List bytes, String name, {String mime = 'video/mp4'}) async {
    final h = await _headers([driveScope]);
    final start = await http.post(
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable'),
      headers: {
        ...h,
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': mime,
        'X-Upload-Content-Length': '${bytes.length}',
      },
      body: jsonEncode({'name': name, 'mimeType': mime, 'description': 'Video caricato da BeCoach'}),
    );
    _check(start, 'Google Drive');
    final location = start.headers['location'];
    if (location == null) throw GoogleException('Google Drive: caricamento non avviato');
    final up = await http.put(Uri.parse(location), headers: {'Content-Type': mime}, body: bytes);
    _check(up, 'Google Drive');
    final id = jsonDecode(up.body)['id'] as String;
    final perm = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$id/permissions'),
      headers: {...h, 'Content-Type': 'application/json'},
      body: jsonEncode({'role': 'reader', 'type': 'anyone'}),
    );
    _check(perm, 'Google Drive');
    return 'https://drive.google.com/file/d/$id/view';
  }
}

class GoogleEvent {
  final String id;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  GoogleEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    this.allDay = false,
  });
}

class GoogleException implements Exception {
  final String message;
  GoogleException(this.message);
  @override
  String toString() => message;
}
