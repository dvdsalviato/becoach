import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'data/exercise_library.dart';
import 'google.dart';
import 'models.dart';

class Db {
  static FirebaseFirestore get fs => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get users => fs.collection('users');
  static CollectionReference<Map<String, dynamic>> get plans => fs.collection('plans');
  static CollectionReference<Map<String, dynamic>> get sessions => fs.collection('sessions');
  static CollectionReference<Map<String, dynamic>> get invites => fs.collection('invites');
  static CollectionReference<Map<String, dynamic>> get coachVideos => fs.collection('coachVideos');

  static String get uid => FirebaseAuth.instance.currentUser!.uid;

  // ---------- Accesso ----------

  /// Accesso con Google. Restituisce false se l'utente annulla.
  static Future<bool> signInWithGoogle() async {
    final account = await Google.signIn.signIn();
    if (account == null) return false;
    final auth = await account.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(cred);
    return true;
  }

  static Future<void> signOut() async {
    try {
      await Google.signIn.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  // ---------- Utenti ----------

  static Stream<AppUser?> userStream(String uid) => users
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  static Future<void> createUser({
    required String uid,
    required String name,
    required String email,
    required bool isCoach,
  }) {
    return users.doc(uid).set({
      'name': name,
      'email': email,
      'isCoach': isCoach,
      'coachMode': isCoach,
      'goal': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      users.doc(uid).update(data);

  /// Restituisce (creandolo se serve) il codice invito del coach.
  static Future<String> ensureInviteCode(AppUser coach) async {
    if (coach.coachInviteCode != null && coach.coachInviteCode!.isNotEmpty) {
      return coach.coachInviteCode!;
    }
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
      final ref = invites.doc(code);
      final existing = await ref.get();
      if (existing.exists) continue;
      await ref.set({
        'coachId': coach.uid,
        'coachName': coach.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await users.doc(coach.uid).update({'coachInviteCode': code});
      return code;
    }
    throw Exception('Impossibile generare il codice, riprova.');
  }

  /// Collega l'allenato al coach tramite codice. Restituisce un messaggio d'errore o null.
  static Future<String?> joinCoach(AppUser me, String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length < 4) return 'Codice non valido';
    final inv = await invites.doc(code).get();
    if (!inv.exists) return 'Codice non trovato';
    final coachId = inv.data()?['coachId'] as String?;
    if (coachId == null) return 'Codice non valido';
    if (coachId == me.uid) return 'Non puoi essere il coach di te stesso';
    await users.doc(me.uid).update({
      'coachId': coachId,
      'coachName': inv.data()?['coachName'] ?? 'Coach',
      'joinedWithCode': code,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return null;
  }

  static Stream<List<AppUser>> clientsStream(String coachId) => users
      .where('coachId', isEqualTo: coachId)
      .snapshots()
      .map((q) => q.docs.map(AppUser.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

  // ---------- Schede ----------

  static Stream<List<Plan>> plansForAthlete(String athleteId) => plans
      .where('athleteId', isEqualTo: athleteId)
      .snapshots()
      .map((q) => _sortPlans(q.docs.map(Plan.fromDoc).toList()));

  static Stream<List<Plan>> plansForClient(String coachId, String athleteId) => plans
      .where('coachId', isEqualTo: coachId)
      .where('athleteId', isEqualTo: athleteId)
      .snapshots()
      .map((q) => _sortPlans(q.docs.map(Plan.fromDoc).toList()));

  static List<Plan> _sortPlans(List<Plan> l) {
    l.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      final ad = a.updatedAt ?? a.createdAt ?? DateTime(2000);
      final bd = b.updatedAt ?? b.createdAt ?? DateTime(2000);
      return bd.compareTo(ad);
    });
    return l;
  }

  static Future<void> savePlan(Plan p) async {
    final data = p.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
    final batch = fs.batch();
    DocumentReference<Map<String, dynamic>> ref;
    if (p.id.isEmpty) {
      ref = plans.doc();
      data['createdAt'] = FieldValue.serverTimestamp();
      batch.set(ref, data);
      p.id = ref.id;
    } else {
      ref = plans.doc(p.id);
      batch.update(ref, data);
    }
    if (p.active) {
      final others = await plans
          .where('coachId', isEqualTo: p.coachId)
          .where('athleteId', isEqualTo: p.athleteId)
          .get();
      for (final d in others.docs) {
        if (d.id != ref.id && d.data()['active'] == true) {
          batch.update(d.reference, {'active': false});
        }
      }
    }
    await batch.commit();
  }

  static Future<void> setPlanActive(Plan p) async {
    final copy = p.copy()..active = true;
    await savePlan(copy);
  }

  static Future<void> deletePlan(String id) => plans.doc(id).delete();

  // ---------- Area riservata del coach ----------

  static CollectionReference<Map<String, dynamic>> templatesRef(String coachId) =>
      users.doc(coachId).collection('templates');

  static Stream<List<Plan>> templatesStream(String coachId) =>
      templatesRef(coachId).snapshots().map((q) {
        final l = q.docs.map(Plan.fromDoc).toList();
        l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return l;
      });

  static Future<void> saveTemplate(Plan t) async {
    final data = t.toMap()
      ..['athleteId'] = ''
      ..['active'] = false
      ..['updatedAt'] = FieldValue.serverTimestamp();
    if (t.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = await templatesRef(t.coachId).add(data);
      t.id = ref.id;
    } else {
      await templatesRef(t.coachId).doc(t.id).set(data);
    }
  }

  static Future<void> deleteTemplate(String coachId, String id) =>
      templatesRef(coachId).doc(id).delete();

  static DocumentReference<Map<String, dynamic>> noteRef(String coachId, String athleteId) =>
      users.doc(coachId).collection('clientNotes').doc(athleteId);

  static Stream<String> noteStream(String coachId, String athleteId) =>
      noteRef(coachId, athleteId).snapshots().map((d) => (d.data()?['text'] as String?) ?? '');

  static Future<void> saveNote(String coachId, String athleteId, String text) =>
      noteRef(coachId, athleteId).set({
        'text': text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ---------- Esercizi personalizzati del coach ----------

  static CollectionReference<Map<String, dynamic>> customExRef(String coachId) =>
      users.doc(coachId).collection('customExercises');

  static Stream<List<Exercise>> customExercisesStream(String coachId) =>
      customExRef(coachId).snapshots().map((q) {
        final l = q.docs.map((d) => Exercise.fromMap('custom_${d.id}', d.data())).toList();
        l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return l;
      });

  static Future<Exercise> addCustomExercise(String coachId, Exercise e) async {
    final ref = await customExRef(coachId).add(e.toMap()..['createdAt'] = FieldValue.serverTimestamp());
    return Exercise('custom_${ref.id}', e.name, e.muscle, e.machine, timed: e.timed, custom: true);
  }

  static Future<void> deleteCustomExercise(String coachId, String exerciseId) =>
      customExRef(coachId).doc(exerciseId.replaceFirst('custom_', '')).delete();

  // ---------- Video del coach ----------

  static String _videoId(String coachId, String exerciseId) => '${coachId}_$exerciseId';

  static Stream<String?> coachVideoStream(String coachId, String exerciseId) => coachVideos
      .doc(_videoId(coachId, exerciseId))
      .snapshots()
      .map((d) => d.data()?['url'] as String?);

  static Future<Map<String, String>> coachVideosMap(String coachId) async {
    final q = await coachVideos.where('coachId', isEqualTo: coachId).get();
    final m = <String, String>{};
    for (final d in q.docs) {
      final ex = d.data()['exerciseId'] as String?;
      final url = d.data()['url'] as String?;
      if (ex != null && url != null && url.isNotEmpty) m[ex] = url;
    }
    return m;
  }

  static Future<void> setCoachVideo(String coachId, String exerciseId, String url) {
    final ref = coachVideos.doc(_videoId(coachId, exerciseId));
    if (url.trim().isEmpty) return ref.delete();
    return ref.set({
      'coachId': coachId,
      'exerciseId': exerciseId,
      'url': url.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Allenamenti ----------

  static Stream<List<Session>> sessionsForAthlete(String athleteId) => sessions
      .where('athleteId', isEqualTo: athleteId)
      .snapshots()
      .map((q) => _sortSessions(q.docs.map(Session.fromDoc).toList()));

  static Stream<List<Session>> sessionsForClient(String coachId, String athleteId) => sessions
      .where('coachId', isEqualTo: coachId)
      .where('athleteId', isEqualTo: athleteId)
      .snapshots()
      .map((q) => _sortSessions(q.docs.map(Session.fromDoc).toList()));

  static Stream<List<Session>> sessionsForCoach(String coachId) => sessions
      .where('coachId', isEqualTo: coachId)
      .snapshots()
      .map((q) => _sortSessions(q.docs.map(Session.fromDoc).toList()));

  static Stream<List<Plan>> plansForCoach(String coachId) => plans
      .where('coachId', isEqualTo: coachId)
      .snapshots()
      .map((q) => q.docs.map(Plan.fromDoc).toList());

  static Stream<List<Session>> liveSessionsForCoach(String coachId) => sessions
      .where('coachId', isEqualTo: coachId)
      .where('status', isEqualTo: 'live')
      .snapshots()
      .map((q) => q.docs.map(Session.fromDoc).toList());

  static Stream<Session?> sessionStream(String id) => sessions
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? Session.fromDoc(d) : null);

  static List<Session> _sortSessions(List<Session> l) {
    l.sort((a, b) => (b.startedAt ?? DateTime.now()).compareTo(a.startedAt ?? DateTime.now()));
    return l;
  }

  /// Crea una sessione dal giorno della scheda, con i valori della volta precedente.
  static Future<String> startSession({
    required AppUser me,
    required Plan plan,
    required int dayIndex,
  }) async {
    final day = plan.days[dayIndex];
    final past = await sessions.where('athleteId', isEqualTo: me.uid).get();
    final previous = _sortSessions(past.docs.map(Session.fromDoc).toList())
        .where((s) => !s.isLive && s.planId == plan.id && s.dayIndex == dayIndex)
        .toList();
    final last = previous.isEmpty ? null : previous.first;

    final exercises = <SessionExercise>[];
    for (var i = 0; i < day.exercises.length; i++) {
      final pe = day.exercises[i];
      SessionExercise? lastEx;
      if (last != null) {
        for (final e in last.exercises) {
          if (e.exerciseId == pe.exerciseId) {
            lastEx = e;
            break;
          }
        }
      }
      final prev = lastEx == null
          ? <String>[]
          : lastEx.sets.where((s) => s.done).map((s) => s.label(pe.isTimed)).toList();
      final sets = List.generate(pe.sets, (k) {
        final ls = (lastEx != null && k < lastEx.sets.length) ? lastEx.sets[k] : null;
        return SetEntry(kg: ls?.kg, sec: pe.isTimed ? pe.seconds : null);
      });
      exercises.add(SessionExercise(
        key: '$i-${pe.exerciseId}',
        exerciseId: pe.exerciseId,
        name: pe.name,
        machine: pe.machine,
        targetSets: pe.sets,
        targetReps: pe.reps,
        restSec: pe.restSec,
        notes: pe.notes,
        videoUrl: pe.videoUrl,
        mode: pe.mode,
        targetSec: pe.seconds,
        // se l'allenato aveva indicato un altro macchinario, lo ripropone
        brand: (lastEx != null && lastEx.brand.isNotEmpty) ? lastEx.brand : pe.brand,
        model: (lastEx != null && lastEx.brand.isNotEmpty) ? lastEx.model : pe.model,
        group: pe.group,
        muscle: pe.muscle.isNotEmpty ? pe.muscle : (exerciseById(pe.exerciseId)?.muscle ?? ''),
        prev: prev,
        sets: sets,
      ));
    }

    final s = Session(
      athleteId: me.uid,
      athleteName: me.name,
      coachId: me.coachId ?? '',
      planId: plan.id,
      planName: plan.name,
      dayIndex: dayIndex,
      dayName: day.name,
      exercises: exercises,
    );
    final data = s.toMap()..['startedAt'] = FieldValue.serverTimestamp();
    final ref = await sessions.add(data);
    return ref.id;
  }

  static Future<void> saveSessionExercises(Session s) => sessions.doc(s.id).update({
        'exercises': s.exercises.map((e) => e.toMap()).toList(),
        'reordered': s.reordered,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> finishSession(Session s) => sessions.doc(s.id).update({
        'exercises': s.exercises.map((e) => e.toMap()).toList(),
        'reordered': s.reordered,
        'status': 'done',
        'finishedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> deleteSession(String id) => sessions.doc(id).delete();

  // ---------- Agenda ----------

  // Gli appuntamenti stanno nell'area riservata del coach (users/{coach}/appointments).
  static CollectionReference<Map<String, dynamic>> appointmentsRef(String coachId) =>
      users.doc(coachId).collection('appointments');

  static Stream<List<Appointment>> appointmentsStream(String coachId) => appointmentsRef(coachId)
      .snapshots()
      .map((q) => q.docs.map(Appointment.fromDoc).toList()..sort((a, b) => a.start.compareTo(b.start)));

  static Future<void> saveAppointment(Appointment a) async {
    final data = a.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
    if (a.id.isEmpty) {
      final ref = await appointmentsRef(a.coachId).add(data);
      a.id = ref.id;
    } else {
      await appointmentsRef(a.coachId).doc(a.id).set(data);
    }
  }

  static Future<void> deleteAppointment(Appointment a) => appointmentsRef(a.coachId).doc(a.id).delete();

  // ---------- Rubrica ----------

  static CollectionReference<Map<String, dynamic>> contactsRef(String coachId) =>
      users.doc(coachId).collection('contacts');

  static Stream<List<Contact>> contactsStream(String coachId) => contactsRef(coachId).snapshots().map((q) {
        final l = q.docs.map(Contact.fromDoc).toList();
        l.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        return l;
      });

  static Future<void> saveContact(String coachId, Contact c) async {
    if (c.id.isEmpty) {
      final ref = await contactsRef(coachId).add(c.toMap());
      c.id = ref.id;
    } else {
      await contactsRef(coachId).doc(c.id).set(c.toMap());
    }
  }

  static Future<void> deleteContact(String coachId, String id) => contactsRef(coachId).doc(id).delete();
}
