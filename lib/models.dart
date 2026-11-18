import 'package:cloud_firestore/cloud_firestore.dart';

double? _d(dynamic v) => v is num ? v.toDouble() : null;
int? _i(dynamic v) => v is num ? v.toInt() : null;
String _s(dynamic v, [String def = '']) => v is String ? v : def;
DateTime? _t(dynamic v) => v is Timestamp ? v.toDate() : null;

class AppUser {
  final String uid;
  final String name;
  final String email;
  final bool isCoach;
  final bool coachMode;
  final String? coachId;
  final String? coachName;
  final String? coachInviteCode;
  final int? birthYear;
  final double? heightCm;
  final double? weightKg;
  final String goal;
  final DateTime? createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.isCoach,
    required this.coachMode,
    this.coachId,
    this.coachName,
    this.coachInviteCode,
    this.birthYear,
    this.heightCm,
    this.weightKg,
    this.goal = '',
    this.createdAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      name: _s(m['name'], 'Senza nome'),
      email: _s(m['email']),
      isCoach: m['isCoach'] == true,
      coachMode: m['coachMode'] == true,
      coachId: m['coachId'] is String ? m['coachId'] as String : null,
      coachName: m['coachName'] is String ? m['coachName'] as String : null,
      coachInviteCode:
          m['coachInviteCode'] is String ? m['coachInviteCode'] as String : null,
      birthYear: _i(m['birthYear']),
      heightCm: _d(m['heightCm']),
      weightKg: _d(m['weightKg']),
      goal: _s(m['goal']),
      createdAt: _t(m['createdAt']),
    );
  }

  bool get hasCoach => coachId != null && coachId!.isNotEmpty;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;
}

class PlanExercise {
  String exerciseId;
  String name;
  String machine;
  int sets;
  String reps;
  int restSec;
  String notes;
  String videoUrl;

  PlanExercise({
    required this.exerciseId,
    required this.name,
    this.machine = '',
    this.sets = 3,
    this.reps = '10',
    this.restSec = 90,
    this.notes = '',
    this.videoUrl = '',
  });

  factory PlanExercise.fromMap(Map<String, dynamic> m) => PlanExercise(
        exerciseId: _s(m['exerciseId']),
        name: _s(m['name']),
        machine: _s(m['machine']),
        sets: _i(m['sets']) ?? 3,
        reps: _s(m['reps'], '10'),
        restSec: _i(m['restSec']) ?? 90,
        notes: _s(m['notes']),
        videoUrl: _s(m['videoUrl']),
      );

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'name': name,
        'machine': machine,
        'sets': sets,
        'reps': reps,
        'restSec': restSec,
        'notes': notes,
        'videoUrl': videoUrl,
      };

  PlanExercise copy() => PlanExercise.fromMap(toMap());

  String get target => '$sets × $reps';
}

class PlanDay {
  String name;
  List<PlanExercise> exercises;

  PlanDay({required this.name, List<PlanExercise>? exercises})
      : exercises = exercises ?? [];

  factory PlanDay.fromMap(Map<String, dynamic> m) => PlanDay(
        name: _s(m['name'], 'Giorno'),
        exercises: (m['exercises'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PlanExercise.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  PlanDay copy() => PlanDay.fromMap(toMap());
}

/// Usato sia per le schede assegnate (plans) sia per i modelli (templates).
class Plan {
  String id;
  String coachId;
  String athleteId; // vuoto per i modelli
  String name;
  String notes;
  bool active;
  int weeks;
  DateTime? createdAt;
  DateTime? updatedAt;
  List<PlanDay> days;

  Plan({
    this.id = '',
    required this.coachId,
    this.athleteId = '',
    required this.name,
    this.notes = '',
    this.active = true,
    this.weeks = 8,
    this.createdAt,
    this.updatedAt,
    List<PlanDay>? days,
  }) : days = days ?? [];

  factory Plan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Plan(
      id: doc.id,
      coachId: _s(m['coachId']),
      athleteId: _s(m['athleteId']),
      name: _s(m['name'], 'Scheda'),
      notes: _s(m['notes']),
      active: m['active'] == true,
      weeks: _i(m['weeks']) ?? 8,
      createdAt: _t(m['createdAt']),
      updatedAt: _t(m['updatedAt']),
      days: (m['days'] as List? ?? [])
          .whereType<Map>()
          .map((e) => PlanDay.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'coachId': coachId,
        'athleteId': athleteId,
        'name': name,
        'notes': notes,
        'active': active,
        'weeks': weeks,
        'days': days.map((d) => d.toMap()).toList(),
      };

  Plan copy() => Plan(
        id: id,
        coachId: coachId,
        athleteId: athleteId,
        name: name,
        notes: notes,
        active: active,
        weeks: weeks,
        createdAt: createdAt,
        updatedAt: updatedAt,
        days: days.map((d) => d.copy()).toList(),
      );

  int get exerciseCount => days.fold(0, (a, d) => a + d.exercises.length);
}

class SetEntry {
  double? kg;
  int? reps;
  bool done;

  SetEntry({this.kg, this.reps, this.done = false});

  factory SetEntry.fromMap(Map<String, dynamic> m) =>
      SetEntry(kg: _d(m['kg']), reps: _i(m['reps']), done: m['done'] == true);

  Map<String, dynamic> toMap() => {'kg': kg, 'reps': reps, 'done': done};

  String get label => '${fmtKg(kg)} × ${reps ?? '—'}';
}

String fmtKg(double? v) {
  if (v == null) return '—';
  final s = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  return s.replaceAll('.', ',');
}

class SessionExercise {
  String key; // identificativo stabile anche dopo il riordino
  String exerciseId;
  String name;
  String machine;
  int targetSets;
  String targetReps;
  int restSec;
  String notes;
  String videoUrl;
  List<String> prev; // "50 × 8" della volta precedente, per serie
  List<SetEntry> sets;

  SessionExercise({
    required this.key,
    required this.exerciseId,
    required this.name,
    this.machine = '',
    this.targetSets = 3,
    this.targetReps = '10',
    this.restSec = 90,
    this.notes = '',
    this.videoUrl = '',
    List<String>? prev,
    List<SetEntry>? sets,
  })  : prev = prev ?? [],
        sets = sets ?? [];

  factory SessionExercise.fromMap(Map<String, dynamic> m) => SessionExercise(
        key: _s(m['key']),
        exerciseId: _s(m['exerciseId']),
        name: _s(m['name']),
        machine: _s(m['machine']),
        targetSets: _i(m['targetSets']) ?? 3,
        targetReps: _s(m['targetReps'], '10'),
        restSec: _i(m['restSec']) ?? 90,
        notes: _s(m['notes']),
        videoUrl: _s(m['videoUrl']),
        prev: (m['prev'] as List? ?? []).map((e) => e.toString()).toList(),
        sets: (m['sets'] as List? ?? [])
            .whereType<Map>()
            .map((e) => SetEntry.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'key': key,
        'exerciseId': exerciseId,
        'name': name,
        'machine': machine,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'restSec': restSec,
        'notes': notes,
        'videoUrl': videoUrl,
        'prev': prev,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  int get doneSets => sets.where((s) => s.done).length;
  bool get completed => sets.isNotEmpty && sets.every((s) => s.done);

  double? get bestKg {
    double? best;
    for (final s in sets) {
      if (s.done && s.kg != null && (best == null || s.kg! > best)) best = s.kg;
    }
    return best;
  }
}

class Session {
  String id;
  String athleteId;
  String athleteName;
  String coachId;
  String planId;
  String planName;
  int dayIndex;
  String dayName;
  String status; // live | done
  bool reordered;
  DateTime? startedAt;
  DateTime? finishedAt;
  List<SessionExercise> exercises;

  Session({
    this.id = '',
    required this.athleteId,
    this.athleteName = '',
    required this.coachId,
    required this.planId,
    required this.planName,
    required this.dayIndex,
    required this.dayName,
    this.status = 'live',
    this.reordered = false,
    this.startedAt,
    this.finishedAt,
    List<SessionExercise>? exercises,
  }) : exercises = exercises ?? [];

  factory Session.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Session(
      id: doc.id,
      athleteId: _s(m['athleteId']),
      athleteName: _s(m['athleteName']),
      coachId: _s(m['coachId']),
      planId: _s(m['planId']),
      planName: _s(m['planName']),
      dayIndex: _i(m['dayIndex']) ?? 0,
      dayName: _s(m['dayName']),
      status: _s(m['status'], 'done'),
      reordered: m['reordered'] == true,
      startedAt: _t(m['startedAt']),
      finishedAt: _t(m['finishedAt']),
      exercises: (m['exercises'] as List? ?? [])
          .whereType<Map>()
          .map((e) => SessionExercise.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'athleteId': athleteId,
        'athleteName': athleteName,
        'coachId': coachId,
        'planId': planId,
        'planName': planName,
        'dayIndex': dayIndex,
        'dayName': dayName,
        'status': status,
        'reordered': reordered,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  bool get isLive => status == 'live';
  int get doneSets => exercises.fold(0, (a, e) => a + e.doneSets);
  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);

  double get volume {
    double v = 0;
    for (final e in exercises) {
      for (final s in e.sets) {
        if (s.done && s.kg != null && s.reps != null) v += s.kg! * s.reps!;
      }
    }
    return v;
  }

  Duration? get duration => (startedAt != null && finishedAt != null)
      ? finishedAt!.difference(startedAt!)
      : null;
}
