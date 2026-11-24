import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';
import 'gym_models.dart';

/// Accesso ai dati del gestionale palestra.
///
/// gyms/{gymId}                       dati palestra, staff, contatori
///   staffRequests/{uid}              richieste di accesso dello staff
///   members/{id}                     soci (con riepilogo abbonamento)
///     files/photo, files/cert        foto e immagine del certificato
///   priceList/{id}                   listino
///   subscriptions/{id}               abbonamenti venduti (con rate)
///   payments/{id}                    prima nota (entrate e uscite)
///   checkins/{id}                    ingressi
/// gymCodes/{code}                    codice per lo staff -> palestra
/// cardLinks/{code}                   codice tessera -> socio (per l'app del socio e il QR)
class GymDb {
  static final _fs = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get gyms => _fs.collection('gyms');
  static DocumentReference<Map<String, dynamic>> gym(String g) => gyms.doc(g);
  static CollectionReference<Map<String, dynamic>> members(String g) => gym(g).collection('members');
  static CollectionReference<Map<String, dynamic>> priceList(String g) => gym(g).collection('priceList');
  static CollectionReference<Map<String, dynamic>> subs(String g) => gym(g).collection('subscriptions');
  static CollectionReference<Map<String, dynamic>> payments(String g) => gym(g).collection('payments');
  static CollectionReference<Map<String, dynamic>> checkins(String g) => gym(g).collection('checkins');
  static CollectionReference<Map<String, dynamic>> staffRequests(String g) => gym(g).collection('staffRequests');

  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static String _code(int n) {
    final r = Random.secure();
    return List.generate(n, (_) => _chars[r.nextInt(_chars.length)]).join();
  }

  // ---------------- palestra e staff ----------------

  static Stream<Gym?> gymStream(String g) =>
      gym(g).snapshots().map((d) => d.exists ? Gym.fromDoc(d) : null);

  static Future<String> createGym(AppUser me, String name) async {
    final ref = gyms.doc();
    String code = _code(6);
    for (var i = 0; i < 5; i++) {
      if (!(await _fs.collection('gymCodes').doc(code).get()).exists) break;
      code = _code(6);
    }
    await ref.set({
      'name': name.trim(),
      'owner': me.uid,
      'staff': [me.uid],
      'staffNames': {me.uid: me.name},
      'joinCode': code,
      'receiptYear': DateTime.now().year,
      'receiptSeq': 0,
      'cardSeq': 0,
      'certWarnDays': 30,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _fs.collection('gymCodes').doc(code).set({'gymId': ref.id, 'name': name.trim(), 'owner': me.uid});
    await _fs.collection('users').doc(me.uid).update({'gymId': ref.id, 'gymMode': true, 'coachMode': false});
    return ref.id;
  }

  static Future<void> updateGym(String g, Map<String, dynamic> data) => gym(g).update(data);

  /// Lo staff inserisce il codice: crea una richiesta che il titolare approva.
  static Future<String?> requestJoin(AppUser me, String code) async {
    final c = await _fs.collection('gymCodes').doc(code.trim().toUpperCase()).get();
    if (!c.exists) return null;
    final g = c.data()!['gymId'] as String;
    await staffRequests(g).doc(me.uid).set({
      'name': me.name,
      'email': me.email,
      'at': FieldValue.serverTimestamp(),
    });
    await _fs.collection('users').doc(me.uid).update({'gymId': g, 'gymMode': true, 'coachMode': false});
    return c.data()!['name'] as String? ?? 'Palestra';
  }

  static Stream<List<Map<String, dynamic>>> staffRequestsStream(String g) =>
      staffRequests(g).snapshots().map((s) => s.docs.map((d) => {'uid': d.id, ...d.data()}).toList());

  static Future<void> approveStaff(String g, String uid, String name) async {
    await gym(g).update({
      'staff': FieldValue.arrayUnion([uid]),
      'staffNames.$uid': name,
    });
    await staffRequests(g).doc(uid).delete();
  }

  static Future<void> rejectStaff(String g, String uid) => staffRequests(g).doc(uid).delete();

  static Future<void> removeStaff(String g, String uid) => gym(g).update({
        'staff': FieldValue.arrayRemove([uid]),
        'staffNames.$uid': FieldValue.delete(),
      });

  static Future<void> leaveGym(AppUser me) =>
      _fs.collection('users').doc(me.uid).update({'gymId': null, 'gymMode': false});

  // ---------------- soci ----------------

  static Stream<List<Member>> membersStream(String g) => members(g).snapshots().map((s) {
        final list = s.docs.map(Member.fromDoc).toList();
        list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
        return list;
      });

  static Stream<Member?> memberStream(String g, String id) =>
      members(g).doc(id).snapshots().map((d) => d.exists ? Member.fromDoc(d) : null);

  /// Nuovo socio: numero tessera progressivo e codice per QR/app.
  static Future<String> createMember(String g, Member m) async {
    final ref = members(g).doc();
    String code = _code(8);
    for (var i = 0; i < 5; i++) {
      if (!(await _fs.collection('cardLinks').doc(code).get()).exists) break;
      code = _code(8);
    }
    await _fs.runTransaction((tx) async {
      final gs = await tx.get(gym(g));
      final seq = ((gs.data()?['cardSeq'] as num?)?.toInt() ?? 0) + 1;
      tx.update(gym(g), {'cardSeq': seq});
      tx.set(ref, {
        ...m.toProfileMap(),
        'cardNumber': seq,
        'cardCode': code,
        'linkedUid': '',
        'cert': const CertInfo().toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'subName': '',
        'entriesLeft': 0,
        'dueAmount': 0,
      });
      tx.set(_fs.collection('cardLinks').doc(code),
          {'gymId': g, 'memberId': ref.id, 'gymName': gs.data()?['name'] ?? 'Palestra'});
    });
    return ref.id;
  }

  static Future<void> updateMember(String g, Member m) => members(g).doc(m.id).update(m.toProfileMap());

  static Future<void> setPhoto(String g, String memberId, Uint8List photo, Uint8List thumb) async {
    await members(g).doc(memberId).collection('files').doc('photo').set({'data': Blob(photo)});
    await members(g).doc(memberId).update({'thumb': Blob(thumb)});
  }

  static Future<Uint8List?> getFile(String g, String memberId, String name) async {
    final d = await members(g).doc(memberId).collection('files').doc(name).get();
    final b = d.data()?['data'];
    return b is Blob ? b.bytes : null;
  }

  static Future<void> setCert(String g, String memberId, CertInfo c, {Uint8List? image, bool removeImage = false}) async {
    if (image != null) {
      await members(g).doc(memberId).collection('files').doc('cert').set({'data': Blob(image)});
    } else if (removeImage) {
      await members(g).doc(memberId).collection('files').doc('cert').delete();
    }
    await members(g).doc(memberId).update({
      'cert': c.toMap(),
      'certExpiry': c.expiry == null ? null : Timestamp.fromDate(c.expiry!),
    });
  }

  static Future<void> setArchived(String g, String memberId, bool v) =>
      members(g).doc(memberId).update({'archived': v});

  static Future<Member?> findByCode(String g, String code) async {
    final raw = code.trim().toUpperCase().replaceFirst('BECOACH:', '');
    final link = await _fs.collection('cardLinks').doc(raw).get();
    if (link.exists && link.data()?['gymId'] == g) {
      final d = await members(g).doc(link.data()!['memberId'] as String).get();
      if (d.exists) return Member.fromDoc(d);
    }
    final n = int.tryParse(raw);
    if (n != null) {
      final q = await members(g).where('cardNumber', isEqualTo: n).limit(1).get();
      if (q.docs.isNotEmpty) return Member.fromDoc(q.docs.first);
    }
    return null;
  }

  // ---------------- listino ----------------

  static Stream<List<PriceItem>> priceStream(String g) => priceList(g).snapshots().map((s) {
        final l = s.docs.map(PriceItem.fromDoc).toList();
        l.sort((a, b) {
          if (a.active != b.active) return a.active ? -1 : 1;
          return a.price.compareTo(b.price);
        });
        return l;
      });

  static Future<void> savePrice(String g, PriceItem p) =>
      p.id.isEmpty ? priceList(g).add(p.toMap()) : priceList(g).doc(p.id).set(p.toMap());

  static Future<void> deletePrice(String g, String id) => priceList(g).doc(id).delete();

  // ---------------- abbonamenti ----------------

  static Stream<List<Subscription>> memberSubs(String g, String memberId) =>
      subs(g).where('memberId', isEqualTo: memberId).snapshots().map((s) {
        final l = s.docs.map(Subscription.fromDoc).toList();
        l.sort((a, b) => b.start.compareTo(a.start));
        return l;
      });

  static Stream<List<Subscription>> overdueSubs(String g) => subs(g)
      .where('nextDue', isLessThanOrEqualTo: Timestamp.fromDate(dayOnly(DateTime.now()).add(const Duration(days: 1))))
      .snapshots()
      .map((s) => s.docs.map(Subscription.fromDoc).where((x) => !x.cancelled).toList()..sort((a, b) => a.start.compareTo(b.start)));

  /// Vende un abbonamento. Le rate già pagate (paidNow) diventano subito movimenti di cassa.
  static Future<String> sellSubscription(String g, Subscription s, {required String by, required String byName}) async {
    final ref = subs(g).doc();
    s.createdBy = by;
    final data = s.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    await ref.set(data);
    final sub = Subscription.fromDoc(await ref.get());
    for (var i = 0; i < sub.installments.length; i++) {
      final inst = sub.installments[i];
      if (inst.paid) {
        await payInstallment(g, sub, i, method: inst.method, by: by, date: inst.paidAt);
        final fresh = await ref.get();
        sub.installments
          ..clear()
          ..addAll(Subscription.fromDoc(fresh).installments);
      }
    }
    await refreshSummary(g, s.memberId);
    return ref.id;
  }

  static Future<void> updateSubscription(String g, Subscription s) async {
    await subs(g).doc(s.id).update(s.toMap());
    await refreshSummary(g, s.memberId);
  }

  static Future<void> deleteSubscription(String g, Subscription s) async {
    await subs(g).doc(s.id).delete();
    await refreshSummary(g, s.memberId);
  }

  /// Incassa una rata: numero ricevuta progressivo per anno, movimento in prima nota.
  static Future<Payment> payInstallment(String g, Subscription s, int index,
      {required String method, required String by, DateTime? date}) async {
    final when = date ?? DateTime.now();
    final payRef = payments(g).doc();
    late Payment pay;
    await _fs.runTransaction((tx) async {
      final gs = await tx.get(gym(g));
      final ss = await tx.get(subs(g).doc(s.id));
      final cur = Subscription.fromDoc(ss);
      final inst = cur.installments[index];
      final year = when.year;
      final gy = (gs.data()?['receiptYear'] as num?)?.toInt() ?? year;
      final seq = (gy == year ? ((gs.data()?['receiptSeq'] as num?)?.toInt() ?? 0) : 0) + 1;
      tx.update(gym(g), {'receiptYear': year, 'receiptSeq': seq});
      pay = Payment(
        date: when,
        amount: inst.amount,
        method: method,
        category: cur.kind == 'other' ? 'Prodotti' : 'Abbonamenti',
        description: '${cur.name}${cur.installments.length > 1 ? ' · rata ${index + 1}/${cur.installments.length}' : ''}',
        memberId: cur.memberId,
        memberName: cur.memberName,
        subscriptionId: cur.id,
        receiptNo: '$seq/$year',
        createdBy: by,
      );
      tx.set(payRef, pay.toMap());
      inst.paidAt = when;
      inst.method = method;
      inst.paymentId = payRef.id;
      tx.update(subs(g).doc(s.id), cur.toMap());
    });
    await refreshSummary(g, s.memberId);
    return Payment.fromDoc(await payRef.get());
  }

  /// Annulla l'incasso di una rata (elimina il movimento di cassa).
  static Future<void> unpayInstallment(String g, Subscription s, int index) async {
    final inst = s.installments[index];
    if (inst.paymentId.isNotEmpty) await payments(g).doc(inst.paymentId).delete();
    inst.paidAt = null;
    inst.method = '';
    inst.paymentId = '';
    await subs(g).doc(s.id).update(s.toMap());
    await refreshSummary(g, s.memberId);
  }

  /// Ricalcola il riepilogo sul socio: abbonamento in corso, ingressi, rate da incassare.
  static Future<void> refreshSummary(String g, String memberId) async {
    final q = await subs(g).where('memberId', isEqualTo: memberId).get();
    final all = q.docs.map(Subscription.fromDoc).where((s) => !s.cancelled).toList();
    final today = dayOnly(DateTime.now());
    final access = all.where((s) => s.isAccess).toList()..sort((a, b) => a.start.compareTo(b.start));
    Subscription? cur = access.where((s) => s.activeOn(today)).lastOrNull;
    // se non c'è un abbonamento in corso, mostriamo il prossimo o l'ultimo scaduto
    cur ??= access.where((s) => dayOnly(s.start).isAfter(today)).firstOrNull;
    cur ??= access.isEmpty ? null : (access..sort((a, b) => a.end.compareTo(b.end))).last;
    // fine effettiva: abbonamenti a durata consecutivi si sommano
    DateTime? end = cur?.end;
    if (cur != null && cur.kind == 'time') {
      for (final s in access.where((s) => s.kind == 'time' && s.id != cur!.id)) {
        if (end != null && !dayOnly(s.start).isAfter(dayOnly(end).add(const Duration(days: 1))) && s.end.isAfter(end)) {
          end = s.end;
        }
      }
    }
    final unpaid = <Installment>[];
    for (final s in all) {
      unpaid.addAll(s.installments.where((i) => !i.paid));
    }
    unpaid.sort((a, b) => a.due.compareTo(b.due));
    await members(g).doc(memberId).update({
      'subName': cur?.name ?? '',
      'subKind': cur?.kind ?? '',
      'subStart': cur == null ? null : Timestamp.fromDate(cur.start),
      'subEnd': end == null ? null : Timestamp.fromDate(end),
      'entriesLeft': cur?.kind == 'entries' ? cur!.entriesLeft : 0,
      'nextDue': unpaid.isEmpty ? null : Timestamp.fromDate(unpaid.first.due),
      'dueAmount': unpaid.fold<double>(0, (a, i) => a + i.amount),
    });
  }

  // ---------------- cassa ----------------

  static Stream<List<Payment>> paymentsBetween(String g, DateTime from, DateTime to) => payments(g)
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('date', isLessThan: Timestamp.fromDate(to))
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Payment.fromDoc).toList());

  static Stream<List<Payment>> memberPayments(String g, String memberId) =>
      payments(g).where('memberId', isEqualTo: memberId).snapshots().map((s) {
        final l = s.docs.map(Payment.fromDoc).toList();
        l.sort((a, b) => b.date.compareTo(a.date));
        return l;
      });

  /// Movimento manuale (entrata o uscita). Le entrate ricevono un numero di ricevuta.
  static Future<void> addMovement(String g, Payment p) async {
    if (p.amount <= 0) {
      await payments(g).add(p.toMap());
      return;
    }
    final ref = payments(g).doc();
    await _fs.runTransaction((tx) async {
      final gs = await tx.get(gym(g));
      final year = p.date.year;
      final gy = (gs.data()?['receiptYear'] as num?)?.toInt() ?? year;
      final seq = (gy == year ? ((gs.data()?['receiptSeq'] as num?)?.toInt() ?? 0) : 0) + 1;
      tx.update(gym(g), {'receiptYear': year, 'receiptSeq': seq});
      p.receiptNo = '$seq/$year';
      tx.set(ref, p.toMap());
    });
  }

  static Future<void> deleteMovement(String g, Payment p) async {
    if (p.subscriptionId.isNotEmpty) {
      final sd = await subs(g).doc(p.subscriptionId).get();
      if (sd.exists) {
        final s = Subscription.fromDoc(sd);
        final i = s.installments.indexWhere((x) => x.paymentId == p.id);
        if (i >= 0) {
          await unpayInstallment(g, s, i);
          return;
        }
      }
    }
    await payments(g).doc(p.id).delete();
  }

  // ---------------- ingressi ----------------

  static Stream<List<Checkin>> checkinsSince(String g, DateTime from) => checkins(g)
      .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .orderBy('at', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Checkin.fromDoc).toList());

  static Stream<List<Checkin>> memberCheckins(String g, String memberId) =>
      checkins(g).where('memberId', isEqualTo: memberId).snapshots().map((s) {
        final l = s.docs.map(Checkin.fromDoc).toList();
        l.sort((a, b) => b.at.compareTo(a.at));
        return l.take(30).toList();
      });

  /// Registra l'ingresso; per i pacchetti scala un ingresso.
  static Future<void> checkin(String g, Member m, {required bool ok, String note = '', required String by}) async {
    if (ok && m.subKind == 'entries') {
      final q = await subs(g).where('memberId', isEqualTo: m.id).get();
      final today = DateTime.now();
      final s = q.docs.map(Subscription.fromDoc).where((s) => s.kind == 'entries' && s.activeOn(today)).toList()
        ..sort((a, b) => a.end.compareTo(b.end));
      if (s.isNotEmpty) {
        await subs(g).doc(s.first.id).update({'entriesUsed': FieldValue.increment(1)});
      }
    }
    await checkins(g).add({
      'memberId': m.id,
      'memberName': m.fullName,
      'at': FieldValue.serverTimestamp(),
      'ok': ok,
      'note': note,
      'by': by,
    });
    await members(g).doc(m.id).update({'lastCheckin': FieldValue.serverTimestamp()});
    if (ok && m.subKind == 'entries') await refreshSummary(g, m.id);
  }

  // ---------------- lato socio (app dell'atleta) ----------------

  /// Il socio inserisce il codice della tessera e la collega al suo account.
  static Future<bool> linkCard(AppUser me, String code) async {
    final raw = code.trim().toUpperCase().replaceFirst('BECOACH:', '');
    final link = await _fs.collection('cardLinks').doc(raw).get();
    if (!link.exists) return false;
    final g = link.data()!['gymId'] as String;
    final mid = link.data()!['memberId'] as String;
    await members(g).doc(mid).update({'linkedUid': me.uid});
    final gname = link.data()!['gymName'];
    await _fs.collection('users').doc(me.uid).update({
      'gymCard': {'gymId': g, 'memberId': mid, 'code': raw, 'gymName': gname ?? 'Palestra'},
    });
    return true;
  }

  static Future<void> unlinkCard(AppUser me) =>
      _fs.collection('users').doc(me.uid).update({'gymCard': null});
}
