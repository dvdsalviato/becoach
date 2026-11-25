import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';

/// Importa iscritti dal vecchio gestionale (file CSV esportato da Excel).
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

/// Colonne riconosciute (intestazioni in minuscolo, senza accenti e spazi).
const _aliases = {
  'firstName': ['nome'],
  'lastName': ['cognome'],
  'fullName': ['nominativo', 'cognomeenome', 'nomeecognome', 'cliente', 'iscritto', 'socio'],
  'email': ['email', 'e-mail', 'mail', 'posta'],
  'phone': ['telefono', 'cellulare', 'cell', 'tel', 'mobile'],
  'taxCode': ['codicefiscale', 'cf', 'codfiscale', 'codfisc'],
  'birthDate': ['datadinascita', 'nascita', 'datanascita', 'nato'],
  'birthPlace': ['luogodinascita', 'luogonascita', 'natoa'],
  'address': ['indirizzo', 'via', 'residenza'],
  'zip': ['cap'],
  'city': ['citta', 'comune', 'localita'],
  'notes': ['note', 'annotazioni'],
  'cert': ['scadenzacertificato', 'certificato', 'certificatomedico', 'scadcertificato'],
  'sub': ['scadenzaabbonamento', 'abbonamento', 'scadenza', 'scadabbonamento', 'finevalidita'],
  'enroll': ['scadenzaiscrizione', 'iscrizione', 'tessera', 'scadenzatessera'],
};

String _key(String h) => norm(h).replaceAll(RegExp(r'[^a-z0-9]'), '');

List<List<String>> parseCsv(String text) {
  final first = text.split('\n').first;
  final sep = ';,\t'.split('').reduce((a, b) => first.split(a).length >= first.split(b).length ? a : b);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == sep) {
      row.add(cell.toString().trim());
      cell.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString().trim());
      cell.clear();
      if (row.any((c) => c.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  row.add(cell.toString().trim());
  if (row.any((c) => c.isNotEmpty)) rows.add(row);
  return rows;
}

DateTime? parseDateIt(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})').firstMatch(t);
  if (m != null) {
    var y = int.parse(m.group(3)!);
    if (y < 100) y += y > (DateTime.now().year % 100) + 10 ? 1900 : 2000;
    return DateTime(y, int.parse(m.group(2)!), int.parse(m.group(1)!));
  }
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(t);
  if (iso != null) return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
  return null;
}

class _ImportPageState extends State<ImportPage> {
  List<String> _headers = [];
  List<List<String>> _rows = [];
  Map<String, int> _map = {};
  String? _file;
  bool _busy = false;
  int _done = 0;
  int _skipped = 0;
  String? _error;
  bool _finished = false;

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt'], withData: true);
      if (r == null || r.files.isEmpty) return;
      final f = r.files.first;
      final bytes = f.bytes;
      if (bytes == null) throw 'Impossibile leggere il file';
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }
      if (text.startsWith('﻿')) text = text.substring(1);
      final rows = parseCsv(text);
      if (rows.length < 2) throw 'Il file è vuoto o senza intestazioni';
      final headers = rows.first;
      final map = <String, int>{};
      for (var i = 0; i < headers.length; i++) {
        final k = _key(headers[i]);
        for (final e in _aliases.entries) {
          if (!map.containsKey(e.key) && e.value.contains(k)) map[e.key] = i;
        }
      }
      if (!map.containsKey('lastName') && !map.containsKey('fullName')) {
        throw 'Non trovo le colonne Nome e Cognome. La prima riga deve avere le intestazioni.';
      }
      setState(() {
        _file = f.name;
        _headers = headers;
        _rows = rows.skip(1).toList();
        _map = map;
        _finished = false;
        _done = 0;
        _skipped = 0;
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  String _v(List<String> r, String k) {
    final i = _map[k];
    return i == null || i >= r.length ? '' : r[i];
  }

  Future<void> _import() async {
    final g = GymScope.of(context).gym.id;
    final existing = await GymDb.membersStream(g).first;
    final known = {for (final m in existing) if (m.taxCode.isNotEmpty) m.taxCode.toUpperCase()};
    final knownNames = {for (final m in existing) norm(m.fullName)};
    setState(() {
      _busy = true;
      _done = 0;
      _skipped = 0;
    });
    for (final r in _rows) {
      if (!mounted) return;
      var first = _v(r, 'firstName'), last = _v(r, 'lastName');
      if (first.isEmpty && last.isEmpty) {
        final full = _v(r, 'fullName').split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
        if (full.isEmpty) {
          setState(() => _skipped++);
          continue;
        }
        last = full.first;
        first = full.skip(1).join(' ');
      }
      final cf = _v(r, 'taxCode').toUpperCase();
      final name = norm('$first $last'.trim());
      if ((cf.isNotEmpty && known.contains(cf)) || (cf.isEmpty && knownNames.contains(name))) {
        setState(() => _skipped++);
        continue;
      }
      final b = cfBirth(cf);
      final m = Member(
        firstName: first,
        lastName: last,
        email: _v(r, 'email'),
        phone: _v(r, 'phone'),
        taxCode: cf,
        birthDate: parseDateIt(_v(r, 'birthDate')) ?? b?.$1,
        gender: b?.$2 ?? '',
        birthPlace: _v(r, 'birthPlace'),
        address: _v(r, 'address'),
        zip: _v(r, 'zip'),
        city: _v(r, 'city'),
        notes: _v(r, 'notes'),
        privacy: true,
        consentAt: DateTime.now(),
      );
      try {
        final id = await GymDb.createMember(g, m);
        final cert = parseDateIt(_v(r, 'cert'));
        if (cert != null) {
          await GymDb.setCert(g, id, CertInfo(expiry: cert, issued: addMonths(cert, -12).add(const Duration(days: 1))));
        }
        final today = dayOnly(DateTime.now());
        final sub = parseDateIt(_v(r, 'sub'));
        if (sub != null) {
          await GymDb.sellSubscription(
              g,
              Subscription(memberId: id, memberName: m.fullName, name: 'Abbonamento importato', start: sub.isBefore(today) ? sub : today, end: sub),
              by: 'import',
              byName: 'Importazione');
        }
        final enr = parseDateIt(_v(r, 'enroll'));
        if (enr != null) {
          await GymDb.sellSubscription(
              g,
              Subscription(memberId: id, memberName: m.fullName, name: 'Iscrizione importata', kind: 'enroll', start: addMonths(enr, -12).add(const Duration(days: 1)), end: enr),
              by: 'import',
              byName: 'Importazione');
        }
        known.add(cf);
        knownNames.add(name);
        setState(() => _done++);
      } catch (e) {
        setState(() {
          _error = friendlyError(e);
          _busy = false;
        });
        return;
      }
    }
    setState(() {
      _busy = false;
      _finished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const labels = {
      'firstName': 'Nome',
      'lastName': 'Cognome',
      'fullName': 'Nome completo',
      'email': 'Email',
      'phone': 'Telefono',
      'taxCode': 'Codice fiscale',
      'birthDate': 'Data di nascita',
      'birthPlace': 'Luogo di nascita',
      'address': 'Indirizzo',
      'zip': 'CAP',
      'city': 'Città',
      'notes': 'Note',
      'cert': 'Scadenza certificato',
      'sub': 'Scadenza abbonamento',
      'enroll': 'Scadenza iscrizione',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Importa iscritti')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text(
            'Dal vecchio gestionale esporta l\'elenco clienti in Excel e salvalo come CSV '
            '(File → Salva con nome → CSV). La prima riga deve contenere le intestazioni, ad esempio: '
            'Nome; Cognome; Codice fiscale; Telefono; Email; Data di nascita; Scadenza certificato; Scadenza abbonamento; Scadenza iscrizione.',
            style: TextStyle(color: BC.body, height: 1.45),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(_file == null ? 'Scegli il file CSV' : 'Cambia file'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: BC.danger)),
          ],
          if (_file != null) ...[
            SectionLabel('$_file · ${_rows.length} righe'),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final e in labels.entries)
                  if (_map.containsKey(e.key))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('✓ ${e.value} ← "${_headers[_map[e.key]!]}"', style: const TextStyle(fontSize: 13)),
                    ),
                const SizedBox(height: 6),
                Text(
                  'Colonne non usate: ${[for (var i = 0; i < _headers.length; i++) if (!_map.values.contains(i)) _headers[i]].join(', ')}',
                  style: const TextStyle(fontSize: 12, color: BC.muted),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gli iscritti già presenti (stesso codice fiscale o stesso nome) vengono saltati. '
              'Abbonamenti e iscrizioni importati non generano incassi in cassa.',
              style: TextStyle(fontSize: 12.5, color: BC.muted),
            ),
            const SizedBox(height: 14),
            if (_busy || _finished)
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  LinearProgressIndicator(value: _rows.isEmpty ? 0 : (_done + _skipped) / _rows.length),
                  const SizedBox(height: 8),
                  Text(_finished ? 'Fatto: $_done importati, $_skipped saltati.' : 'Importati $_done, saltati $_skipped di ${_rows.length}…'),
                ]),
              ),
            if (!_finished) ...[
              const SizedBox(height: 10),
              FilledButton(onPressed: _busy ? null : _import, child: Text('Importa ${_rows.length} iscritti')),
            ],
          ],
        ],
      ),
    );
  }
}
