import 'package:flutter/material.dart';

import '../../data/exercise_library.dart';
import '../../models.dart';
import '../../theme.dart';
import 'widgets.dart';

// Disegno del corpo in uno spazio 200 x 420: ogni muscolo è una forma morbida
// costruita da pochi punti; le forme "a coppia" vengono specchiate.

class _Region {
  final String? muscle; // null = parte neutra (testa, mani…)
  final Path path;
  const _Region(this.muscle, this.path);
}

Offset _mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

Path _shape(List<Offset> p) {
  final path = Path();
  final start = _mid(p.last, p.first);
  path.moveTo(start.dx, start.dy);
  for (var i = 0; i < p.length; i++) {
    final cur = p[i];
    final next = p[(i + 1) % p.length];
    final m = _mid(cur, next);
    path.quadraticBezierTo(cur.dx, cur.dy, m.dx, m.dy);
  }
  path.close();
  return path;
}

List<Offset> _pts(List<double> xy) => [for (var i = 0; i < xy.length; i += 2) Offset(xy[i], xy[i + 1])];

List<Offset> _mirror(List<Offset> p) => p.map((o) => Offset(200 - o.dx, o.dy)).toList().reversed.toList();

void _pair(List<_Region> out, String? muscle, List<double> xy) {
  final l = _pts(xy);
  out.add(_Region(muscle, _shape(l)));
  out.add(_Region(muscle, _shape(_mirror(l))));
}

Path _rr(double l, double t, double r, double b, double rad) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(rad)));

List<_Region> _regions(bool back) {
  final r = <_Region>[];
  r.add(_Region(null, Path()..addOval(const Rect.fromLTRB(80, 4, 120, 52))));
  r.add(_Region(null, _rr(91, 50, 109, 70, 6)));
  _pair(r, 'Avambracci', [34, 164, 52, 160, 56, 190, 46, 222, 36, 222, 30, 192]);
  _pair(r, null, [36, 224, 50, 224, 52, 238, 43, 247, 34, 238]); // mani
  _pair(r, null, [70, 396, 94, 396, 96, 410, 88, 417, 68, 414]); // piedi

  if (!back) {
    _pair(r, 'Dorso', [100, 66, 86, 68, 64, 80, 74, 87, 100, 85]); // trapezio
    _pair(r, 'Petto', [100, 84, 72, 84, 62, 100, 68, 120, 86, 128, 100, 124]);
    _pair(r, 'Addome', [66, 124, 82, 132, 82, 206, 74, 204, 66, 170]); // obliqui
    for (var i = 0; i < 4; i++) {
      final y = 130.0 + i * 21;
      r.add(_Region('Addome', _rr(84, y, 99, y + 18, 6)));
      r.add(_Region('Addome', _rr(101, y, 116, y + 18, 6)));
    }
    _pair(r, 'Spalle', [62, 76, 46, 80, 36, 96, 40, 116, 54, 114, 64, 96]);
    _pair(r, 'Bicipiti', [41, 114, 56, 112, 58, 140, 53, 160, 42, 158, 38, 136]);
    _pair(r, 'Quadricipiti', [68, 208, 92, 206, 90, 262, 86, 302, 76, 302, 70, 262, 65, 232]);
    _pair(r, 'Adduttori', [93, 210, 99, 210, 99, 262, 92, 270]);
    _pair(r, 'Polpacci', [73, 310, 92, 310, 91, 372, 83, 396, 76, 374]);
  } else {
    _pair(r, 'Dorso', [100, 62, 84, 68, 62, 80, 80, 96, 100, 118]); // trapezio
    _pair(r, 'Dorso', [100, 118, 82, 100, 68, 104, 66, 128, 78, 160, 100, 172]); // dorsali
    _pair(r, 'Dorso', [100, 174, 86, 166, 82, 192, 100, 200]); // lombari
    _pair(r, 'Spalle', [62, 76, 46, 80, 36, 96, 40, 116, 54, 114, 64, 96]);
    _pair(r, 'Tricipiti', [41, 114, 56, 112, 58, 140, 53, 160, 42, 158, 38, 136]);
    _pair(r, 'Glutei', [100, 200, 74, 198, 66, 222, 80, 242, 100, 238]);
    _pair(r, 'Femorali', [68, 246, 99, 242, 98, 300, 80, 304, 70, 272]);
    _pair(r, 'Polpacci', [70, 308, 94, 308, 92, 372, 84, 396, 74, 374]);
  }
  return r;
}

final _front = _regions(false);
final _back = _regions(true);

const _cRest = Color(0xFFE6E9ED);
const _cNeutral = Color(0xFFF1F2F4);

/// Colore in base alle serie fatte nella settimana.
Color volumeColor(int sets) {
  if (sets <= 0) return _cRest;
  if (sets <= 5) return const Color(0xFFC6D3E0);
  if (sets <= 10) return const Color(0xFF8DA6BF);
  if (sets <= 16) return BC.steel;
  return const Color(0xFFB4532A);
}

class _BodyPainter extends CustomPainter {
  final List<_Region> regions;
  final Map<String, int> volume;
  _BodyPainter(this.regions, this.volume);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    canvas.save();
    canvas.scale(s, s);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white;
    for (final reg in regions) {
      final m = reg.muscle;
      final color = m == null ? _cNeutral : volumeColor(volume[m] ?? 0);
      canvas.drawPath(reg.path, Paint()..color = color);
      canvas.drawPath(reg.path, outline);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.volume != volume || old.regions != regions;
}

/// Inizio della settimana corrente: lunedì alle 00:00 (si azzera domenica alle 23:59).
DateTime weekStart([DateTime? now]) {
  final n = now ?? DateTime.now();
  final d = DateTime(n.year, n.month, n.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// Serie completate per gruppo muscolare negli allenamenti della settimana in corso.
Map<String, int> weeklySetsByMuscle(List<Session> sessions) {
  final from = weekStart();
  final out = <String, int>{};
  for (final s in sessions) {
    if (s.startedAt == null || s.startedAt!.isBefore(from)) continue;
    for (final e in s.exercises) {
      final muscle = e.muscle.isNotEmpty ? e.muscle : (exerciseById(e.exerciseId)?.muscle ?? '');
      if (muscle.isEmpty || muscle == 'Cardio') continue;
      final n = e.doneSets;
      if (n == 0) continue;
      if (muscle == 'Total body') {
        for (final m in ['Quadricipiti', 'Glutei', 'Dorso', 'Spalle']) {
          out[m] = (out[m] ?? 0) + n;
        }
      } else {
        out[muscle] = (out[muscle] ?? 0) + n;
      }
    }
  }
  return out;
}

/// Mappa del corpo (fronte e retro) colorata in base al volume della settimana.
class WeeklyBodyMap extends StatelessWidget {
  final List<Session> sessions;
  const WeeklyBodyMap({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final vol = weeklySetsByMuscle(sessions);
    final total = vol.values.fold(0, (a, b) => a + b);
    final sorted = vol.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Volume della settimana',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Text('$total serie', style: const TextStyle(fontSize: 13, color: BC.muted)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _figure(_front, vol, 'Fronte')),
              const SizedBox(width: 12),
              Expanded(child: _figure(_back, vol, 'Retro')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legend(volumeColor(0), 'Riposo'),
              _legend(volumeColor(3), '1–5'),
              _legend(volumeColor(8), '6–10'),
              _legend(volumeColor(12), '11–16'),
              _legend(volumeColor(20), 'Oltre 16'),
            ],
          ),
          if (sorted.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in sorted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BC.subtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: BC.border),
                    ),
                    child: Text('${e.key} · ${e.value}',
                        style: const TextStyle(fontSize: 12, color: BC.body)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _figure(List<_Region> regions, Map<String, int> vol, String label) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 200 / 420,
          child: CustomPaint(painter: _BodyPainter(regions, vol)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11.5, color: BC.muted)),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5, color: BC.muted)),
        ],
      );
}
