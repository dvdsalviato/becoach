import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/exercise_images.dart';
import '../../theme.dart';

/// Mostra come si esegue l'esercizio alternando due fotogrammi, come una gif.
class ExerciseAnimation extends StatefulWidget {
  final String exerciseId;
  final double? height;
  final double radius;
  final bool compact; // miniatura senza scritte

  const ExerciseAnimation({
    super.key,
    required this.exerciseId,
    this.height,
    this.radius = 10,
    this.compact = false,
  });

  static bool hasImage(String exerciseId) => exerciseFrames(exerciseId) != null;

  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation> {
  Timer? _timer;
  int _frame = 0;
  List<String>? _frames;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant ExerciseAnimation old) {
    super.didUpdateWidget(old);
    if (old.exerciseId != widget.exerciseId) {
      _setup();
      _precache();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache();
  }

  void _setup() {
    _timer?.cancel();
    _frame = 0;
    _frames = exerciseFrames(widget.exerciseId);
    if (_frames != null) {
      _timer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
        if (mounted) setState(() => _frame = 1 - _frame);
      });
    }
  }

  void _precache() {
    final f = _frames;
    if (f == null) return;
    for (final p in f) {
      precacheImage(AssetImage(p), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames;
    final radius = BorderRadius.circular(widget.radius);
    if (f == null) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(color: BC.graphite, borderRadius: radius),
        alignment: Alignment.center,
        child: Icon(Icons.fitness_center,
            color: Colors.white70, size: widget.compact ? 18 : 32),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: widget.height,
        color: Colors.white,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Image.asset(
            f[_frame],
            key: ValueKey(f[_frame]),
            fit: BoxFit.cover,
            width: double.infinity,
            height: widget.height,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
