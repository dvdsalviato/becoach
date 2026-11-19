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
  // dati professionali del coach
  final String businessName;
  final String gyms;
  final String specialties;
  final String phone;
  final bool googleCalendar; // il coach ha collegato Google Calendar
  final String googleCalendarEmail;

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
    this.businessName = '',
    this.gyms = '',
    this.specialties = '',
    this.phone = '',
    this.googleCalendar = false,
    this.googleCalendarEmail = '',
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
      businessName: _s(m['businessName']),
      gyms: _s(m['gyms']),
      specialties: _s(m['specialties']),
      phone: _s(m['phone']),
      googleCalendar: m['googleCalendar'] == true,
      googleCalendarEmail: _s(m['googleCalendarEmail']),
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
  String mode; // 'reps' oppure 'time'
  int sets;
  String reps;
  int seconds; // obiettivo per gli esercizi a tempo
  int restSec;
  String notes;
  String videoUrl;
  String brand; // marca del macchinario
  String model; // modello del macchinario
  String group; // id superset: stesso valore = stesso superset
  String muscle;

  PlanExercise({
    required this.exerciseId,
    required this.name,
    this.machine = '',
    this.muscle = '',
    this.mode = 'reps',
    this.sets = 3,
    this.reps = '10',
    this.seconds = 30,
    this.restSec = 90,
    this.notes = '',
    this.videoUrl = '',
    this.brand = '',
    this.model = '',
    this.group = '',
  });

  bool get isTimed => mode == 'time';

  factory PlanExercise.fromMap(Map<String, dynamic> m) => PlanExercise(
        exerciseId: _s(m['exerciseId']),
        name: _s(m['name']),
        machine: _s(m['machine']),
        mode: _s(m['mode'], 'reps'),
        sets: _i(m['sets']) ?? 3,
        reps: _s(m['reps'], '10'),
        seconds: _i(m['seconds']) ?? 30,
        restSec: _i(m['restSec']) ?? 90,
        notes: _s(m['notes']),
        videoUrl: _s(m['videoUrl']),
        brand: _s(m['brand']),
        model: _s(m['model']),
        group: _s(m['group']),
        muscle: _s(m['muscle']),
      );

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'name': name,
        'machine': machine,
        'muscle': muscle,
        'mode': mode,
        'sets': sets,
        'reps': reps,
        'seconds': seconds,
        'restSec': restSec,
        'notes': notes,
        'videoUrl': videoUrl,
        'brand': brand,
        'model': model,
        'group': group,
      };

  PlanExercise copy() => PlanExercise.fromMap(toMap());

  String get target => isTimed ? '$sets × ${fmtSec(seconds)}' : '$sets × $reps';

  String get machineLabel => [brand, model].where((e) => e.isNotEmpty).join(' · ');
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
  int? sec;
  bool done;

  SetEntry({this.kg, this.reps, this.sec, this.done = false});

  factory SetEntry.fromMap(Map<String, dynamic> m) => SetEntry(
      kg: _d(m['kg']), reps: _i(m['reps']), sec: _i(m['sec']), done: m['done'] == true);

  Map<String, dynamic> toMap() => {'kg': kg, 'reps': reps, 'sec': sec, 'done': done};

  String label(bool timed) {
    if (timed) {
      final t = sec == null ? '—' : fmtSec(sec!);
      return kg == null ? t : '${fmtKg(kg)} kg · $t';
    }
    return '${fmtKg(kg)} × ${reps ?? '—'}';
  }
}

/// 45 -> 45″, 90 -> 1:30
String fmtSec(int s) {
  if (s < 60) return '$s″';
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
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
  String mode;
  int targetSec;
  String brand;
  String model;
  String group;
  String muscle;
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
    this.mode = 'reps',
    this.targetSec = 30,
    this.brand = '',
    this.model = '',
    this.group = '',
    this.muscle = '',
    List<String>? prev,
    List<SetEntry>? sets,
  })  : prev = prev ?? [],
        sets = sets ?? [];

  bool get isTimed => mode == 'time';
  String get target => isTimed ? '$targetSets × ${fmtSec(targetSec)}' : '$targetSets × $targetReps';
  String get machineLabel => [brand, model].where((e) => e.isNotEmpty).join(' · ');

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
        mode: _s(m['mode'], 'reps'),
        targetSec: _i(m['targetSec']) ?? 30,
        brand: _s(m['brand']),
        model: _s(m['model']),
        group: _s(m['group']),
        muscle: _s(m['muscle']),
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
        'mode': mode,
        'targetSec': targetSec,
        'brand': brand,
        'model': model,
        'group': group,
        'muscle': muscle,
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


// ---------------- Agenda ----------------

class Appointment {
  String id;
  String coachId;
  String clientId; // cliente dell'app (facoltativo)
  String clientName;
  String clientEmail;
  String title;
  String notes;
  String category; // vuoto = automatica dal testo
  DateTime start;
  int minutes;
  String googleEventId;

  Appointment({
    this.id = '',
    required this.coachId,
    this.clientId = '',
    this.clientName = '',
    this.clientEmail = '',
    required this.title,
    this.notes = '',
    this.category = '',
    required this.start,
    this.minutes = 60,
    this.googleEventId = '',
  });

  DateTime get end => start.add(Duration(minutes: minutes));

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Appointment(
      id: doc.id,
      coachId: _s(m['coachId']),
      clientId: _s(m['clientId']),
      clientName: _s(m['clientName']),
      clientEmail: _s(m['clientEmail']),
      title: _s(m['title'], 'Appuntamento'),
      notes: _s(m['notes']),
      category: _s(m['category']),
      start: _t(m['start']) ?? DateTime.now(),
      minutes: _i(m['minutes']) ?? 60,
      googleEventId: _s(m['googleEventId']),
    );
  }

  Map<String, dynamic> toMap() => {
        'coachId': coachId,
        'clientId': clientId,
        'clientName': clientName,
        'clientEmail': clientEmail,
        'title': title,
        'notes': notes,
        'category': category,
        'start': Timestamp.fromDate(start),
        'minutes': minutes,
        'googleEventId': googleEventId,
      };
}

// ---------------- Rubrica ----------------

class Contact {
  String id;
  String firstName;
  String lastName;
  String phone;
  String email;
  String notes;

  Contact({
    this.id = '',
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.email = '',
    this.notes = '',
  });

  String get fullName => [firstName, lastName].where((e) => e.trim().isNotEmpty).join(' ');

  String get initials {
    final a = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final b = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    final r = (a + b).toUpperCase();
    return r.isEmpty ? '?' : r;
  }

  factory Contact.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Contact(
      id: doc.id,
      firstName: _s(m['firstName']),
      lastName: _s(m['lastName']),
      phone: _s(m['phone']),
      email: _s(m['email']),
      notes: _s(m['notes']),
    );
  }

  Map<String, dynamic> toMap() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'email': email,
        'notes': notes,
      };
}
