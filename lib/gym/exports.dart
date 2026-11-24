import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'gym_models.dart';
import 'save_file.dart';

pw.Font? _reg, _bold;
Future<void> _fonts() async {
  _reg ??= pw.Font.ttf(await rootBundle.load('assets/fonts/SpaceGrotesk-Regular.ttf'));
  _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/SpaceGrotesk-Bold.ttf'));
}

const _ink = PdfColor.fromInt(0xFF16181D);
const _muted = PdfColor.fromInt(0xFF5C6068);
const _line = PdfColor.fromInt(0xFFD9DCE0);

String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

pw.Widget _gymHeader(Gym g) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(g.legalName.isNotEmpty ? g.legalName : g.name,
            style: pw.TextStyle(font: _bold, fontSize: 16, color: _ink)),
        if (g.legalName.isNotEmpty && g.name != g.legalName)
          pw.Text(g.name, style: pw.TextStyle(font: _reg, fontSize: 10, color: _muted)),
        if (g.address.isNotEmpty) pw.Text(g.address, style: pw.TextStyle(font: _reg, fontSize: 10, color: _muted)),
        pw.Text(
            [
              if (g.vat.isNotEmpty) 'P. IVA ${g.vat}',
              if (g.taxCode.isNotEmpty) 'C.F. ${g.taxCode}',
              if (g.phone.isNotEmpty) 'Tel. ${g.phone}',
              if (g.email.isNotEmpty) g.email,
            ].join('  ·  '),
            style: pw.TextStyle(font: _reg, fontSize: 9, color: _muted)),
      ],
    );

/// Ricevuta di pagamento (documento non fiscale) in PDF.
Future<void> shareReceipt(Gym g, Payment p, {Member? m}) async {
  await _fonts();
  final doc = pw.Document();
  pw.Widget row(String k, String v, {bool big = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(children: [
          pw.SizedBox(width: 130, child: pw.Text(k, style: pw.TextStyle(font: _reg, fontSize: 10, color: _muted))),
          pw.Expanded(child: pw.Text(v, style: pw.TextStyle(font: big ? _bold : _reg, fontSize: big ? 16 : 11, color: _ink))),
        ]),
      );
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(32),
    build: (c) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _gymHeader(g),
        pw.SizedBox(height: 22),
        pw.Text('RICEVUTA DI PAGAMENTO', style: pw.TextStyle(font: _bold, fontSize: 13, letterSpacing: 1.2)),
        pw.Text('N. ${p.receiptNo.isEmpty ? '—' : p.receiptNo} del ${dmy(p.date)}',
            style: pw.TextStyle(font: _reg, fontSize: 10, color: _muted)),
        pw.SizedBox(height: 14),
        pw.Container(height: 1, color: _line),
        pw.SizedBox(height: 10),
        row('Ricevuto da', p.memberName.isEmpty ? '—' : p.memberName),
        if (m != null && m.taxCode.isNotEmpty) row('Codice fiscale', m.taxCode),
        if (m != null && (m.address.isNotEmpty || m.city.isNotEmpty))
          row('Indirizzo', [m.address, [m.zip, m.city].where((e) => e.isNotEmpty).join(' ')].where((e) => e.isNotEmpty).join(', ')),
        row('Causale', p.description.isEmpty ? p.category : p.description),
        row('Metodo', p.method),
        pw.SizedBox(height: 6),
        pw.Container(height: 1, color: _line),
        pw.SizedBox(height: 6),
        row('Importo', euro(p.amount), big: true),
        pw.Spacer(),
        if (g.receiptNote.isNotEmpty)
          pw.Text(g.receiptNote, style: pw.TextStyle(font: _reg, fontSize: 8.5, color: _muted)),
        pw.SizedBox(height: 4),
        pw.Text('Documento non valido ai fini fiscali. Il documento fiscale è emesso separatamente.',
            style: pw.TextStyle(font: _reg, fontSize: 8, color: _muted)),
      ],
    ),
  ));
  final bytes = await doc.save();
  await saveBytes('Ricevuta_${_safe(p.receiptNo.isEmpty ? p.id : p.receiptNo)}.pdf', Uint8List.fromList(bytes), 'application/pdf');
}

/// Tessera da stampare (formato carta di credito) con QR.
Future<void> shareCard(Gym g, Member m) async {
  await _fonts();
  final doc = pw.Document();
  const fmt = PdfPageFormat(85.6 * PdfPageFormat.mm, 54 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm);
  doc.addPage(pw.Page(
    pageFormat: fmt,
    build: (c) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(g.name.toUpperCase(), style: pw.TextStyle(font: _bold, fontSize: 9, letterSpacing: 1)),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(m.fullName, style: pw.TextStyle(font: _bold, fontSize: 12)),
                pw.Text('Tessera n. ${m.cardNumber}', style: pw.TextStyle(font: _reg, fontSize: 8, color: _muted)),
                pw.Text('Codice ${m.cardCode}', style: pw.TextStyle(font: _reg, fontSize: 8, color: _muted)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(
          width: 30 * PdfPageFormat.mm,
          height: 30 * PdfPageFormat.mm,
          child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: 'BECOACH:${m.cardCode}', drawText: false),
        ),
      ],
    ),
  ));
  final bytes = await doc.save();
  await saveBytes('Tessera_${m.cardNumber}_${_safe(m.lastName)}.pdf', Uint8List.fromList(bytes), 'application/pdf');
}

String _csvCell(Object? v) {
  final s = v?.toString() ?? '';
  if (s.contains(';') || s.contains('"') || s.contains('\n')) return '"${s.replaceAll('"', '""')}"';
  return s;
}

String _num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

Future<void> _saveCsv(String name, List<List<Object?>> rows) async {
  final text = rows.map((r) => r.map(_csvCell).join(';')).join('\r\n');
  final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
  await saveBytes(name, bytes, 'text/csv');
}

/// Prima nota del periodo, per il commercialista (si apre con Excel).
Future<void> exportPayments(String gymName, String period, List<Payment> list) async {
  final rows = <List<Object?>>[
    ['Data', 'N. ricevuta', 'Tipo', 'Categoria', 'Descrizione', 'Socio', 'Metodo', 'Entrata', 'Uscita'],
    for (final p in list.reversed)
      [
        dmy(p.date),
        p.receiptNo,
        p.isIncome ? 'Entrata' : 'Uscita',
        p.category,
        p.description,
        p.memberName,
        p.method,
        p.isIncome ? _num(p.amount) : '',
        p.isIncome ? '' : _num(-p.amount),
      ],
  ];
  final inc = list.where((p) => p.isIncome).fold<double>(0, (a, p) => a + p.amount);
  final out = list.where((p) => !p.isIncome).fold<double>(0, (a, p) => a - p.amount);
  rows.add([]);
  rows.add(['', '', '', '', 'Totale', '', '', _num(inc), _num(out)]);
  rows.add(['', '', '', '', 'Saldo', '', '', _num(inc - out), '']);
  final byMethod = <String, double>{};
  for (final p in list) {
    byMethod[p.method] = (byMethod[p.method] ?? 0) + p.amount;
  }
  rows.add([]);
  for (final e in byMethod.entries) {
    rows.add(['', '', '', '', 'Totale ${e.key}', '', '', _num(e.value), '']);
  }
  await _saveCsv('Prima_nota_${_safe(gymName)}_${_safe(period)}.csv', rows);
}

/// Elenco soci con abbonamento e certificato.
Future<void> exportMembers(String gymName, List<Member> list) async {
  await _saveCsv('Soci_${_safe(gymName)}.csv', [
    ['Tessera', 'Cognome', 'Nome', 'Codice fiscale', 'Nascita', 'Luogo nascita', 'Telefono', 'Email', 'Indirizzo', 'CAP', 'Città',
      'Abbonamento', 'Scadenza abbonamento', 'Ingressi residui', 'Scadenza certificato', 'Certificato verificato', 'Da incassare',
      'Privacy', 'Dati sanitari', 'Marketing', 'Archiviato'],
    for (final m in list)
      [
        m.cardNumber, m.lastName, m.firstName, m.taxCode, dmy(m.birthDate), m.birthPlace, m.phone, m.email, m.address, m.zip, m.city,
        m.subName, dmy(m.subEnd), m.subKind == 'entries' ? m.entriesLeft : '', dmy(m.cert.expiry), m.cert.verified ? 'Sì' : 'No',
        m.dueAmount > 0 ? _num(m.dueAmount) : '', m.privacy ? 'Sì' : 'No', m.healthData ? 'Sì' : 'No', m.marketing ? 'Sì' : 'No',
        m.archived ? 'Sì' : 'No',
      ],
  ]);
}
