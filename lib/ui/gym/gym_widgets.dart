import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../common/widgets.dart';

const okFg = Color(0xFF1F6B3A);
const okBg = Color(0xFFE3F1E7);
const badFg = Color(0xFF9F1F17);
const badBg = Color(0xFFF9E3E1);

class MemberAvatar extends StatelessWidget {
  final Member m;
  final double size;
  const MemberAvatar(this.m, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final t = m.thumb;
    if (t != null && t.isNotEmpty) {
      return ClipOval(
        child: Image.memory(Uint8List.fromList(t), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
      );
    }
    return Avatar(m.initials, size: size);
  }
}

class StatusTag extends StatelessWidget {
  final String text;
  final Color fg, bg;
  const StatusTag(this.text, this.fg, this.bg, {super.key});
  const StatusTag.ok(this.text, {super.key})
      : fg = okFg,
        bg = okBg;
  const StatusTag.bad(this.text, {super.key})
      : fg = badFg,
        bg = badBg;
  const StatusTag.warn(this.text, {super.key})
      : fg = BC.warnFg,
        bg = BC.warnBg;
  const StatusTag.neutral(this.text, {super.key})
      : fg = BC.muted,
        bg = const Color(0xFFEEF0F2);

  @override
  Widget build(BuildContext context) => Tag(text, fg: fg, bg: bg);
}

Widget subTag(Member m) {
  if (m.subEnd == null) return const StatusTag.neutral('Nessun abbonamento');
  if (m.subActive) {
    final dl = m.subDaysLeft ?? 99;
    if (m.subKind == 'entries') {
      return m.entriesLeft <= 2 ? StatusTag.warn('${m.entriesLeft} ingressi') : StatusTag.ok('${m.entriesLeft} ingressi');
    }
    if (dl <= 7) return StatusTag.warn(dl == 0 ? 'Scade oggi' : 'Scade tra $dl gg');
    return StatusTag.ok('Attivo fino al ${dmy(m.subEnd)}');
  }
  if (m.subStart != null && dayOnly(DateTime.now()).isBefore(dayOnly(m.subStart!))) {
    return StatusTag.neutral('Dal ${dmy(m.subStart)}');
  }
  return StatusTag.bad('Scaduto ${dmy(m.subEnd)}');
}

Widget certTag(Member m, int warnDays) {
  switch (m.certState(warnDays)) {
    case CertState.missing:
      return const StatusTag.bad('Certificato mancante');
    case CertState.expired:
      return const StatusTag.bad('Certificato scaduto');
    case CertState.toVerify:
      return const StatusTag.warn('Certificato da verificare');
    case CertState.expiring:
      return StatusTag.warn('Certificato scade ${dmy(m.cert.expiry)}');
    case CertState.ok:
      return const StatusTag.ok('Certificato ok');
  }
}

Future<DateTime?> pickDay(BuildContext context, DateTime? initial, {DateTime? first, DateTime? last}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? DateTime(1920),
    lastDate: last ?? DateTime(now.year + 10),
    locale: const Locale('it'),
  );
}

/// Campo data cliccabile in stile modulo.
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? first;
  final bool clearable;
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.first, this.clearable = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await pickDay(context, value, first: first);
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: clearable && value != null
              ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => onChanged(null))
              : const Icon(Icons.event_outlined, size: 20),
        ),
        child: Text(value == null ? 'Scegli' : dmy(value), style: TextStyle(color: value == null ? BC.muted : BC.ink)),
      ),
    );
  }
}

Future<T?> showSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.9),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: builder(c))),
        ),
      ),
    );

/// Riquadro numerico della Home.
class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final VoidCallback? onTap;
  final Color? color;
  const StatBox({super.key, required this.label, required this.value, this.sub, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: BC.muted)),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: BC.display, fontSize: 24, fontWeight: FontWeight.w700, color: color ?? BC.ink)),
          if (sub != null)
            Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: BC.muted)),
        ],
      ),
    );
  }
}

double? parseEuro(String s) {
  final t = s.replaceAll('€', '').replaceAll(' ', '').trim();
  if (t.isEmpty) return null;
  final norm = t.contains(',') ? t.replaceAll('.', '').replaceAll(',', '.') : t;
  return double.tryParse(norm);
}

String euroInput(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

Widget enrollTag(Member m) {
  if (m.enrollEnd == null) return const StatusTag.neutral('Iscrizione mancante');
  if (!m.enrollActive) return StatusTag.bad('Iscrizione scaduta ${dmy(m.enrollEnd)}');
  final dl = m.enrollDaysLeft ?? 99;
  if (dl <= 15) return StatusTag.warn('Iscrizione scade ${dmy(m.enrollEnd)}');
  return StatusTag.ok('Iscritto fino al ${dmy(m.enrollEnd)}');
}
