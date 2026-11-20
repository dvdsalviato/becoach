import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../theme.dart';
import 'body_map.dart' show weekStart;

// ---------------- Tachimetro ----------------

/// Tachimetro stile contachilometri: arco di 240°, tacche, ago che sale all'apertura.
class SpeedGauge extends StatelessWidget {
  final double value; // 0..1
  final double width;
  const SpeedGauge({super.key, required this.value, this.width = 300});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return SizedBox(
          width: width,
          height: width * 0.86,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              CustomPaint(size: Size(width, width * 0.86), painter: _GaugePainter(t)),
              Positioned(
                top: width * 0.585,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${(t * 100).round()}',
                        style: TextStyle(
                            fontFamily: BC.display,
                            fontSize: width * 0.22,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -2,
                            color: BC.ink)),
                    const SizedBox(width: 3),
                    Text('%',
                        style: TextStyle(
                            fontFamily: BC.display,
                            fontSize: width * 0.075,
                            fontWeight: FontWeight.w500,
                            color: BC.muted)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double v;
  _GaugePainter(this.v);

  static const _start = 150 * math.pi / 180; // in basso a sinistra
  static const _sweep = 240 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w * 0.50);
    final r = w * 0.40;
    final stroke = w * 0.04;
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawArc(rect, _start, _sweep, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = const Color(0xFFE3E6EA));
    canvas.drawArc(rect, _start, _sweep * v, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = BC.steel);

    final minor = Paint()
      ..color = const Color(0xFF9AA1AA)
      ..strokeWidth = 1.2;
    final major = Paint()
      ..color = BC.ink
      ..strokeWidth = 2.2;
    for (var i = 0; i <= 50; i++) {
      final a = _start + _sweep * i / 50;
      final isMajor = i % 5 == 0;
      final r1 = r - stroke / 2 - (isMajor ? w * 0.05 : w * 0.026);
      final r2 = r - stroke / 2 - 2;
      canvas.drawLine(
        Offset(c.dx + r1 * math.cos(a), c.dy + r1 * math.sin(a)),
        Offset(c.dx + r2 * math.cos(a), c.dy + r2 * math.sin(a)),
        isMajor ? major : minor,
      );
    }
    for (var n = 0; n <= 100; n += 20) {
      final a = _start + _sweep * n / 100;
      final rr = r - stroke / 2 - w * 0.10;
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
              fontFamily: BC.display, fontSize: w * 0.037, fontWeight: FontWeight.w500, color: BC.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(c.dx + rr * math.cos(a) - tp.width / 2, c.dy + rr * math.sin(a) - tp.height / 2));
    }

    final na = _start + _sweep * v;
    final nl = r - w * 0.07;
    canvas.drawLine(
      c,
      Offset(c.dx + nl * math.cos(na), c.dy + nl * math.sin(na)),
      Paint()
        ..color = BC.ink
        ..strokeWidth = w * 0.012
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, w * 0.037, Paint()..color = BC.ink);
    canvas.drawCircle(c, w * 0.013, Paint()..color = BC.steel);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.v != v;
}

// ---------------- Anelli ----------------

/// Anello di progresso stile Apple Watch.
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 52,
    this.stroke = 6,
    this.color = BC.steel,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: Size(size, size), painter: _RingPainter(t, stroke, color)),
            if (center != null) center!,
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final Color color;
  _RingPainter(this.v, this.stroke, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = const Color(0xFFE3E6EA));
    if (v > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}

// ---------------- Progressi dell'allenato ----------------

int isoWeek(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final firstDay = DateTime(thursday.year, 1, 1);
  return 1 + thursday.difference(firstDay).inDays ~/ 7;
}

class WeekStats {
  final DateTime start;
  final int done;
  final double volume;
  WeekStats(this.start, this.done, this.volume);
}

/// Allenamenti e volume per settimana (da lunedì).
WeekStats weekStats(List<Session> sessions, DateTime from) {
  final to = from.add(const Duration(days: 7));
  var done = 0;
  double vol = 0;
  for (final s in sessions) {
    final t = s.startedAt;
    if (s.isLive || t == null || t.isBefore(from) || !t.isBefore(to)) continue;
    if (s.doneSets == 0) continue;
    done++;
    vol += s.volume;
  }
  return WeekStats(from, done, vol);
}

/// Tachimetro della settimana, anelli delle ultime settimane e degli obiettivi.
class AthleteProgressHero extends StatelessWidget {
  final List<Session> sessions;
  final Plan? plan;
  const AthleteProgressHero({super.key, required this.sessions, required this.plan});

  @override
  Widget build(BuildContext context) {
    final planned = (plan?.days.length ?? 0) > 0 ? plan!.days.length : 3;
    final ws = weekStart();
    final weeks = [for (var k = 3; k >= 0; k--) weekStats(sessions, ws.subtract(Duration(days: 7 * k)))];
    final cur = weeks.last;
    final pct = (cur.done / planned).clamp(0.0, 1.0);

    final prev = [for (var k = 1; k <= 4; k++) weekStats(sessions, ws.subtract(Duration(days: 7 * k)))];
    final avgVol = prev.fold<double>(0, (a, w) => a + w.volume) / 4;
    final volRatio = avgVol == 0 ? (cur.volume > 0 ? 1.0 : 0.0) : cur.volume / avgVol;

    var streak = cur.done >= planned ? 1 : 0;
    for (var k = 1; k <= 52; k++) {
      if (weekStats(sessions, ws.subtract(Duration(days: 7 * k))).done >= planned) {
        streak++;
      } else {
        break;
      }
    }

    const line = BorderSide(color: BC.border);
    const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: BC.muted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: line, bottom: line)),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('OBIETTIVO SETTIMANA', style: label)),
                  Text('${cur.done} di $planned allenamenti', style: const TextStyle(fontSize: 12.5, color: BC.muted)),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) => SpeedGauge(value: pct, width: math.min(320, c.maxWidth)),
              ),
              Text(
                cur.volume > 0
                    ? '${_kg(cur.volume)} kg di volume questa settimana'
                    : (cur.done == 0 ? 'Il primo allenamento della settimana fa partire l\'ago' : ''),
                style: const TextStyle(fontSize: 13, color: BC.body),
              ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(bottom: line)),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('ULTIME 4 SETTIMANE', style: label),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < weeks.length; i++)
                    Expanded(
                      child: Column(
                        children: [
                          ProgressRing(
                            value: weeks[i].done / planned,
                            color: i == weeks.length - 1 ? BC.graphite : BC.steel,
                            center: Text('${weeks[i].done}/$planned',
                                style: const TextStyle(
                                    fontFamily: BC.display, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 6),
                          Text('S${isoWeek(weeks[i].start)}',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 0.6,
                                fontWeight: i == weeks.length - 1 ? FontWeight.w700 : FontWeight.w500,
                                color: i == weeks.length - 1 ? BC.ink : BC.muted,
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: line)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _goal('Allenamenti', '${cur.done} di $planned', pct, first: true),
              _goal('Volume', '${(volRatio * 100).round()}%', volRatio.clamp(0.0, 1.0)),
              _goal('Costanza', '$streak sett.', (streak / 8).clamp(0.0, 1.0)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _goal(String name, String value, double v, {bool first = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.fromLTRB(first ? 0 : 10, 12, 4, 12),
        decoration: BoxDecoration(
          border: first ? null : const Border(left: BorderSide(color: BC.border)),
        ),
        child: Row(
          children: [
            ProgressRing(value: v, size: 32, stroke: 4),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9.5, letterSpacing: 0.8, color: BC.muted)),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: BC.display, fontSize: 14.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _kg(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }
}
