const _wd = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
const _mo = [
  'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
  'lug', 'ago', 'set', 'ott', 'nov', 'dic'
];

String fmtDate(DateTime d) => '${_wd[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';

String fmtDateYear(DateTime d) => '${d.day} ${_mo[d.month - 1]} ${d.year}';

String fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String relDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Oggi';
  if (diff == 1) return 'Ieri';
  return fmtDate(d);
}

/// 52.5 -> "52,5", 50.0 -> "50"
String fmtNum(num? v) {
  if (v == null) return '—';
  final s = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  return s.replaceAll('.', ',');
}

double? parseNum(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

int? parseInt(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  return int.tryParse(t);
}

String fmtDuration(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';
}

/// Primo numero in un testo: "8-10" -> 8, "12" -> 12.
int? firstInt(String s) {
  final m = RegExp(r'\d+').firstMatch(s);
  return m == null ? null : int.tryParse(m.group(0)!);
}
