import 'package:cloud_firestore/cloud_firestore.dart';

double _d(dynamic v, [double def = 0]) => v is num ? v.toDouble() : def;
int _i(dynamic v, [int def = 0]) => v is num ? v.toInt() : def;
String _s(dynamic v, [String def = '']) => v is String ? v : def;
DateTime? _t(dynamic v) => v is Timestamp ? v.toDate() : null;
Timestamp? _ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Aggiunge mesi mantenendo il giorno (31 gen + 1 mese = 28/29 feb).
DateTime addMonths(DateTime d, int months) {
  final y = d.year + ((d.month - 1 + months) ~/ 12);
  final m = (d.month - 1 + months) % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day > last ? last : d.day);
}

String euro(num v) {
  final neg = v < 0;
  final cents = (v.abs() * 100).round();
  final intPart = (cents ~/ 100).toString();
  final b = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) b.write('.');
    b.write(intPart[i]);
  }
  return '${neg ? '-' : ''}€ $b,${(cents % 100).toString().padLeft(2, '0')}';
}

String dmy(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class Gym {
  final String id;
  final String name;
  final String legalName;
  final String vat;
  final String taxCode;
  final String address;
  final String phone;
  final String email;
  final String owner;
  final List<String> staff;
  final Map<String, String> staffNames;
  final String joinCode;
  final String receiptNote;
  final int certWarnDays;
  final bool requireEnrollment; // per entrare serve l'iscrizione (tessera) valida
  final bool staffSeesCash; // lo staff vede cassa e statistiche

  Gym({
    required this.id,
    required this.name,
    this.legalName = '',
    this.vat = '',
    this.taxCode = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    required this.owner,
    this.staff = const [],
    this.staffNames = const {},
    this.joinCode = '',
    this.receiptNote = '',
    this.certWarnDays = 30,
    this.requireEnrollment = true,
    this.staffSeesCash = true,
  });

  factory Gym.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Gym(
      id: doc.id,
      name: _s(m['name'], 'Palestra'),
      legalName: _s(m['legalName']),
      vat: _s(m['vat']),
      taxCode: _s(m['taxCode']),
      address: _s(m['address']),
      phone: _s(m['phone']),
      email: _s(m['email']),
      owner: _s(m['owner']),
      staff: (m['staff'] as List? ?? []).map((e) => e.toString()).toList(),
      staffNames: (m['staffNames'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
      joinCode: _s(m['joinCode']),
      receiptNote: _s(m['receiptNote']),
      certWarnDays: _i(m['certWarnDays'], 30),
      requireEnrollment: m['requireEnrollment'] != false,
      staffSeesCash: m['staffSeesCash'] != false,
    );
  }

  bool isOwner(String uid) => owner == uid;
  bool isStaff(String uid) => staff.contains(uid);
  bool canSeeCash(String uid) => isOwner(uid) || staffSeesCash;
}

class CertInfo {
  final String type; // 'non agonistico', 'agonistico', 'ludico-motorio'
  final DateTime? issued;
  final DateTime? expiry;
  final bool verified;
  final String verifiedBy;
  final DateTime? verifiedAt;
  final bool hasImage;
  final String doctor;

  const CertInfo({
    this.type = 'non agonistico',
    this.issued,
    this.expiry,
    this.verified = false,
    this.verifiedBy = '',
    this.verifiedAt,
    this.hasImage = false,
    this.doctor = '',
  });

  factory CertInfo.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const CertInfo();
    return CertInfo(
      type: _s(m['type'], 'non agonistico'),
      issued: _t(m['issued']),
      expiry: _t(m['expiry']),
      verified: m['verified'] == true,
      verifiedBy: _s(m['verifiedBy']),
      verifiedAt: _t(m['verifiedAt']),
      hasImage: m['hasImage'] == true,
      doctor: _s(m['doctor']),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'issued': _ts(issued),
        'expiry': _ts(expiry),
        'verified': verified,
        'verifiedBy': verifiedBy,
        'verifiedAt': _ts(verifiedAt),
        'hasImage': hasImage,
        'doctor': doctor,
      };

  bool get present => expiry != null;
  bool get expired => expiry != null && dayOnly(DateTime.now()).isAfter(expiry!);
  int? get daysLeft => expiry == null ? null : dayOnly(expiry!).difference(dayOnly(DateTime.now())).inDays;
}

/// Stato sintetico mostrato in lista, in ingresso e all'atleta.
enum CertState { missing, expired, toVerify, expiring, ok }

class Member {
  final String id;
  String firstName;
  String lastName;
  String gender;
  DateTime? birthDate;
  String birthPlace;
  String taxCode;
  String phone;
  String email;
  String address;
  String zip;
  String city;
  String notes;
  int cardNumber;
  String cardCode;
  String linkedUid;
  bool privacy;
  bool healthData;
  bool marketing;
  bool photoConsent;
  DateTime? consentAt;
  CertInfo cert;
  List<int>? thumb; // miniatura della foto (pochi kB)
  DateTime? createdAt;
  bool archived;
  // riepilogo abbonamenti (ricalcolato a ogni modifica)
  String subName;
  String subKind;
  DateTime? subStart;
  DateTime? subEnd;
  int entriesLeft;
  DateTime? nextDue;
  double dueAmount;
  DateTime? lastCheckin;
  DateTime? enrollStart; // iscrizione / tessera annuale
  DateTime? enrollEnd;
  String accountEmail; // credenziali create dalla segreteria

  Member({
    this.id = '',
    this.firstName = '',
    this.lastName = '',
    this.gender = '',
    this.birthDate,
    this.birthPlace = '',
    this.taxCode = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.zip = '',
    this.city = '',
    this.notes = '',
    this.cardNumber = 0,
    this.cardCode = '',
    this.linkedUid = '',
    this.privacy = false,
    this.healthData = false,
    this.marketing = false,
    this.photoConsent = false,
    this.consentAt,
    this.cert = const CertInfo(),
    this.thumb,
    this.createdAt,
    this.archived = false,
    this.subName = '',
    this.subKind = '',
    this.subStart,
    this.subEnd,
    this.entriesLeft = 0,
    this.nextDue,
    this.dueAmount = 0,
    this.lastCheckin,
    this.enrollStart,
    this.enrollEnd,
    this.accountEmail = '',
  });

  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    final th = m['thumb'];
    return Member(
      id: doc.id,
      firstName: _s(m['firstName']),
      lastName: _s(m['lastName']),
      gender: _s(m['gender']),
      birthDate: _t(m['birthDate']),
      birthPlace: _s(m['birthPlace']),
      taxCode: _s(m['taxCode']),
      phone: _s(m['phone']),
      email: _s(m['email']),
      address: _s(m['address']),
      zip: _s(m['zip']),
      city: _s(m['city']),
      notes: _s(m['notes']),
      cardNumber: _i(m['cardNumber']),
      cardCode: _s(m['cardCode']),
      linkedUid: _s(m['linkedUid']),
      privacy: m['privacy'] == true,
      healthData: m['healthData'] == true,
      marketing: m['marketing'] == true,
      photoConsent: m['photoConsent'] == true,
      consentAt: _t(m['consentAt']),
      cert: CertInfo.fromMap((m['cert'] as Map?)?.cast<String, dynamic>()),
      thumb: th is Blob ? th.bytes : null,
      createdAt: _t(m['createdAt']),
      archived: m['archived'] == true,
      subName: _s(m['subName']),
      subKind: _s(m['subKind']),
      subStart: _t(m['subStart']),
      subEnd: _t(m['subEnd']),
      entriesLeft: _i(m['entriesLeft']),
      nextDue: _t(m['nextDue']),
      dueAmount: _d(m['dueAmount']),
      lastCheckin: _t(m['lastCheckin']),
      enrollStart: _t(m['enrollStart']),
      enrollEnd: _t(m['enrollEnd']),
      accountEmail: _s(m['accountEmail']),
    );
  }

  /// Campi anagrafici modificabili dal modulo (il riepilogo lo aggiorna il db).
  Map<String, dynamic> toProfileMap() => {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'search': '${firstName.trim()} ${lastName.trim()}'.toLowerCase(),
        'gender': gender,
        'birthDate': _ts(birthDate),
        'birthPlace': birthPlace.trim(),
        'taxCode': taxCode.trim().toUpperCase(),
        'phone': phone.trim(),
        'email': email.trim(),
        'address': address.trim(),
        'zip': zip.trim(),
        'city': city.trim(),
        'notes': notes.trim(),
        'privacy': privacy,
        'healthData': healthData,
        'marketing': marketing,
        'photoConsent': photoConsent,
        'consentAt': _ts(consentAt),
        'archived': archived,
      };

  String get fullName => '${firstName.trim()} ${lastName.trim()}'.trim();
  String get sortKey => '${lastName.trim()} ${firstName.trim()}'.toLowerCase();
  String get initials {
    final a = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final b = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    final s = (a + b).toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  String get cardLabel => cardNumber > 0 ? 'Tessera n. $cardNumber' : 'Tessera';

  bool get subActive {
    if (subEnd == null || subStart == null) return false;
    final today = dayOnly(DateTime.now());
    if (today.isBefore(dayOnly(subStart!))) return false;
    if (today.isAfter(dayOnly(subEnd!))) return false;
    if (subKind == 'entries' && entriesLeft <= 0) return false;
    return true;
  }

  bool get enrollActive {
    if (enrollEnd == null) return false;
    final today = dayOnly(DateTime.now());
    if (enrollStart != null && today.isBefore(dayOnly(enrollStart!))) return false;
    return !today.isAfter(dayOnly(enrollEnd!));
  }

  int? get enrollDaysLeft => enrollEnd == null ? null : dayOnly(enrollEnd!).difference(dayOnly(DateTime.now())).inDays;

  int? get subDaysLeft => subEnd == null ? null : dayOnly(subEnd!).difference(dayOnly(DateTime.now())).inDays;

  bool get hasOverdue => nextDue != null && dayOnly(nextDue!).isBefore(dayOnly(DateTime.now()).add(const Duration(days: 1))) && dueAmount > 0;

  CertState certState(int warnDays) {
    if (!cert.present) return CertState.missing;
    if (cert.expired) return CertState.expired;
    if (!cert.verified) return CertState.toVerify;
    if ((cert.daysLeft ?? 999) <= warnDays) return CertState.expiring;
    return CertState.ok;
  }
}

const certTypes = ['non agonistico', 'agonistico', 'ludico-motorio'];
const payMethods = ['Contanti', 'POS / Carta', 'Bonifico', 'Satispay', 'Altro'];

class PriceItem {
  final String id;
  String name;
  String kind; // 'time' (durata), 'entries' (pacchetto ingressi), 'other' (prodotto/servizio)
  int months;
  int days;
  int entries;
  double price;
  bool active;
  String notes;

  PriceItem({
    this.id = '',
    this.name = '',
    this.kind = 'time',
    this.months = 1,
    this.days = 0,
    this.entries = 10,
    this.price = 0,
    this.active = true,
    this.notes = '',
  });

  factory PriceItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return PriceItem(
      id: doc.id,
      name: _s(m['name']),
      kind: _s(m['kind'], 'time'),
      months: _i(m['months'], 1),
      days: _i(m['days']),
      entries: _i(m['entries'], 10),
      price: _d(m['price']),
      active: m['active'] != false,
      notes: _s(m['notes']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'kind': kind,
        'months': months,
        'days': days,
        'entries': entries,
        'price': price,
        'active': active,
        'notes': notes.trim(),
      };

  String get durationLabel {
    if (kind == 'other') return 'Prodotto / servizio';
    if (kind == 'enroll') {
      final p = <String>[if (months > 0) months == 1 ? '1 mese' : '$months mesi', if (days > 0) '$days giorni'];
      return 'Iscrizione · ${p.isEmpty ? '—' : p.join(' e ')}';
    }
    final parts = <String>[];
    if (months > 0) parts.add(months == 1 ? '1 mese' : '$months mesi');
    if (days > 0) parts.add(days == 1 ? '1 giorno' : '$days giorni');
    final dur = parts.isEmpty ? '' : parts.join(' e ');
    if (kind == 'entries') return '$entries ingressi${dur.isEmpty ? '' : ' · validità $dur'}';
    return dur.isEmpty ? '—' : dur;
  }

  DateTime endFrom(DateTime start) {
    var e = addMonths(dayOnly(start), months);
    e = e.add(Duration(days: days));
    return e.subtract(const Duration(days: 1));
  }
}

class Installment {
  double amount;
  DateTime due;
  DateTime? paidAt;
  String method;
  String paymentId;

  Installment({required this.amount, required this.due, this.paidAt, this.method = '', this.paymentId = ''});

  factory Installment.fromMap(Map<String, dynamic> m) => Installment(
        amount: _d(m['amount']),
        due: _t(m['due']) ?? DateTime.now(),
        paidAt: _t(m['paidAt']),
        method: _s(m['method']),
        paymentId: _s(m['paymentId']),
      );

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'due': Timestamp.fromDate(due),
        'paidAt': _ts(paidAt),
        'method': method,
        'paymentId': paymentId,
      };

  bool get paid => paidAt != null;
}

class Subscription {
  final String id;
  String memberId;
  String memberName;
  String itemId;
  String name;
  String kind;
  DateTime start;
  DateTime end;
  int entriesTotal;
  int entriesUsed;
  double listPrice;
  double price; // prezzo finale dopo sconto
  List<Installment> installments;
  String notes;
  bool cancelled;
  DateTime? createdAt;
  String createdBy;

  Subscription({
    this.id = '',
    required this.memberId,
    this.memberName = '',
    this.itemId = '',
    required this.name,
    this.kind = 'time',
    required this.start,
    required this.end,
    this.entriesTotal = 0,
    this.entriesUsed = 0,
    this.listPrice = 0,
    this.price = 0,
    List<Installment>? installments,
    this.notes = '',
    this.cancelled = false,
    this.createdAt,
    this.createdBy = '',
  }) : installments = installments ?? [];

  factory Subscription.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Subscription(
      id: doc.id,
      memberId: _s(m['memberId']),
      memberName: _s(m['memberName']),
      itemId: _s(m['itemId']),
      name: _s(m['name']),
      kind: _s(m['kind'], 'time'),
      start: _t(m['start']) ?? DateTime.now(),
      end: _t(m['end']) ?? DateTime.now(),
      entriesTotal: _i(m['entriesTotal']),
      entriesUsed: _i(m['entriesUsed']),
      listPrice: _d(m['listPrice']),
      price: _d(m['price']),
      installments: (m['installments'] as List? ?? [])
          .map((e) => Installment.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      notes: _s(m['notes']),
      cancelled: m['cancelled'] == true,
      createdAt: _t(m['createdAt']),
      createdBy: _s(m['createdBy']),
    );
  }

  Map<String, dynamic> toMap() {
    final unpaid = installments.where((i) => !i.paid).toList()..sort((a, b) => a.due.compareTo(b.due));
    return {
      'memberId': memberId,
      'memberName': memberName,
      'itemId': itemId,
      'name': name,
      'kind': kind,
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'entriesTotal': entriesTotal,
      'entriesUsed': entriesUsed,
      'listPrice': listPrice,
      'price': price,
      'installments': installments.map((i) => i.toMap()).toList(),
      'paid': paidAmount,
      'nextDue': cancelled || unpaid.isEmpty ? null : Timestamp.fromDate(unpaid.first.due),
      'notes': notes,
      'cancelled': cancelled,
      'createdBy': createdBy,
    };
  }

  double get paidAmount => installments.where((i) => i.paid).fold(0.0, (a, i) => a + i.amount);
  double get dueAmount => cancelled ? 0 : installments.where((i) => !i.paid).fold(0.0, (a, i) => a + i.amount);
  int get entriesLeft => entriesTotal - entriesUsed;
  bool get isAccess => kind == 'time' || kind == 'entries';
  bool get isEnroll => kind == 'enroll';

  bool activeOn(DateTime day) {
    if (cancelled || !isAccess) return false;
    final d = dayOnly(day);
    if (d.isBefore(dayOnly(start)) || d.isAfter(dayOnly(end))) return false;
    if (kind == 'entries' && entriesLeft <= 0) return false;
    return true;
  }
}

class Payment {
  final String id;
  DateTime date;
  double amount; // positivo = entrata, negativo = uscita
  String method;
  String category;
  String description;
  String memberId;
  String memberName;
  String subscriptionId;
  String receiptNo;
  String createdBy;

  Payment({
    this.id = '',
    required this.date,
    required this.amount,
    this.method = 'Contanti',
    this.category = '',
    this.description = '',
    this.memberId = '',
    this.memberName = '',
    this.subscriptionId = '',
    this.receiptNo = '',
    this.createdBy = '',
  });

  factory Payment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Payment(
      id: doc.id,
      date: _t(m['date']) ?? DateTime.now(),
      amount: _d(m['amount']),
      method: _s(m['method'], 'Contanti'),
      category: _s(m['category']),
      description: _s(m['description']),
      memberId: _s(m['memberId']),
      memberName: _s(m['memberName']),
      subscriptionId: _s(m['subscriptionId']),
      receiptNo: _s(m['receiptNo']),
      createdBy: _s(m['createdBy']),
    );
  }

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'amount': amount,
        'method': method,
        'category': category,
        'description': description,
        'memberId': memberId,
        'memberName': memberName,
        'subscriptionId': subscriptionId,
        'receiptNo': receiptNo,
        'createdBy': createdBy,
      };

  bool get isIncome => amount >= 0;
}

const incomeCategories = ['Abbonamenti', 'Iscrizioni', 'Personal training', 'Prodotti', 'Altro'];
const expenseCategories = ['Affitto', 'Utenze', 'Stipendi e collaboratori', 'Attrezzatura', 'Manutenzione', 'Pulizie', 'Pubblicità', 'Tasse e contributi', 'Altro'];

class Checkin {
  final String id;
  final String memberId;
  final String memberName;
  final DateTime at;
  final bool ok;
  final String note;
  final String by;

  Checkin({this.id = '', required this.memberId, this.memberName = '', required this.at, this.ok = true, this.note = '', this.by = ''});

  factory Checkin.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Checkin(
      id: doc.id,
      memberId: _s(m['memberId']),
      memberName: _s(m['memberName']),
      at: _t(m['at']) ?? DateTime.now(),
      ok: m['ok'] != false,
      note: _s(m['note']),
      by: _s(m['by']),
    );
  }
}

/// Risultato del controllo all'ingresso.
class AccessCheck {
  final bool ok;
  final List<String> problems;
  final List<String> warnings;
  AccessCheck(this.ok, this.problems, this.warnings);
}

AccessCheck checkAccess(Member m, Gym g) {
  final problems = <String>[];
  final warnings = <String>[];
  if (m.archived) problems.add('Iscritto archiviato');
  if (g.requireEnrollment) {
    if (m.enrollEnd == null) {
      problems.add('Iscrizione (tessera) mancante');
    } else if (!m.enrollActive) {
      problems.add('Iscrizione scaduta il ${dmy(m.enrollEnd)}');
    } else if ((m.enrollDaysLeft ?? 99) <= 7) {
      warnings.add('Iscrizione scade il ${dmy(m.enrollEnd)}');
    }
  }
  if (!m.subActive) {
    if (m.subEnd == null) {
      problems.add('Nessun abbonamento');
    } else if (m.subKind == 'entries' && m.entriesLeft <= 0 && !dayOnly(DateTime.now()).isAfter(dayOnly(m.subEnd!))) {
      problems.add('Ingressi esauriti');
    } else if (m.subStart != null && dayOnly(DateTime.now()).isBefore(dayOnly(m.subStart!))) {
      problems.add('Abbonamento non ancora iniziato (dal ${dmy(m.subStart)})');
    } else {
      problems.add('Abbonamento scaduto il ${dmy(m.subEnd)}');
    }
  } else {
    final dl = m.subDaysLeft ?? 99;
    if (m.subKind == 'entries' && m.entriesLeft <= 2) warnings.add('Restano ${m.entriesLeft} ingressi');
    if (dl <= 7) warnings.add(dl == 0 ? 'Abbonamento scade oggi' : 'Abbonamento scade tra $dl giorni');
  }
  switch (m.certState(g.certWarnDays)) {
    case CertState.missing:
      problems.add('Certificato medico mancante');
    case CertState.expired:
      problems.add('Certificato medico scaduto il ${dmy(m.cert.expiry)}');
    case CertState.toVerify:
      warnings.add('Certificato da verificare');
    case CertState.expiring:
      warnings.add('Certificato scade il ${dmy(m.cert.expiry)}');
    case CertState.ok:
      break;
  }
  if (m.hasOverdue) warnings.add('Rata da incassare: ${euro(m.dueAmount)}');
  if (m.lastCheckin != null && DateTime.now().difference(m.lastCheckin!).inHours < 3) {
    final t = m.lastCheckin!;
    warnings.add('Già entrato alle ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }
  if (!m.privacy) warnings.add('Manca il consenso privacy');
  return AccessCheck(problems.isEmpty, problems, warnings);
}

// ---------------- corsi e prenotazioni ----------------

const weekdayNames = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];

class Course {
  final String id;
  String name;
  String instructor;
  String room;
  int weekday; // 1 = lunedì
  int hour;
  int minute;
  int minutes;
  int capacity;
  bool active;
  String notes;

  Course({
    this.id = '',
    this.name = '',
    this.instructor = '',
    this.room = '',
    this.weekday = 1,
    this.hour = 18,
    this.minute = 0,
    this.minutes = 60,
    this.capacity = 20,
    this.active = true,
    this.notes = '',
  });

  factory Course.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Course(
      id: doc.id,
      name: _s(m['name']),
      instructor: _s(m['instructor']),
      room: _s(m['room']),
      weekday: _i(m['weekday'], 1),
      hour: _i(m['hour'], 18),
      minute: _i(m['minute']),
      minutes: _i(m['minutes'], 60),
      capacity: _i(m['capacity'], 20),
      active: m['active'] != false,
      notes: _s(m['notes']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name.trim(),
        'instructor': instructor.trim(),
        'room': room.trim(),
        'weekday': weekday,
        'hour': hour,
        'minute': minute,
        'minutes': minutes,
        'capacity': capacity,
        'active': active,
        'notes': notes.trim(),
      };

  String get timeLabel => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Lezioni dei prossimi [days] giorni a partire da oggi.
  List<Lesson> upcoming(int days) {
    final out = <Lesson>[];
    final today = dayOnly(DateTime.now());
    for (var i = 0; i < days; i++) {
      final d = today.add(Duration(days: i));
      if (d.weekday != weekday) continue;
      final start = DateTime(d.year, d.month, d.day, hour, minute);
      if (start.add(Duration(minutes: minutes)).isBefore(DateTime.now())) continue;
      out.add(Lesson(this, start));
    }
    return out;
  }
}

class Lesson {
  final Course course;
  final DateTime start;
  Lesson(this.course, this.start);
  String get id => '${course.id}_${start.year}${start.month.toString().padLeft(2, '0')}${start.day.toString().padLeft(2, '0')}';
  DateTime get end => start.add(Duration(minutes: course.minutes));
}

class Booking {
  final String id;
  final String lessonId;
  final String courseId;
  final String courseName;
  final DateTime start;
  final String memberId;
  final String memberName;
  final String uid;

  Booking({
    this.id = '',
    required this.lessonId,
    required this.courseId,
    required this.courseName,
    required this.start,
    required this.memberId,
    required this.memberName,
    this.uid = '',
  });

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return Booking(
      id: doc.id,
      lessonId: _s(m['lessonId']),
      courseId: _s(m['courseId']),
      courseName: _s(m['courseName']),
      start: _t(m['start']) ?? DateTime.now(),
      memberId: _s(m['memberId']),
      memberName: _s(m['memberName']),
      uid: _s(m['uid']),
    );
  }
}

// ---------------- codice fiscale ----------------

const _oddCf = {
  '0': 1, '1': 0, '2': 5, '3': 7, '4': 9, '5': 13, '6': 15, '7': 17, '8': 19, '9': 21,
  'A': 1, 'B': 0, 'C': 5, 'D': 7, 'E': 9, 'F': 13, 'G': 15, 'H': 17, 'I': 19, 'J': 21, 'K': 2, 'L': 4, 'M': 18,
  'N': 20, 'O': 11, 'P': 3, 'Q': 6, 'R': 8, 'S': 12, 'T': 14, 'U': 16, 'V': 10, 'W': 22, 'X': 25, 'Y': 24, 'Z': 23,
};

/// Controlla il carattere di controllo del codice fiscale.
bool cfValid(String cf) {
  final s = cf.trim().toUpperCase();
  if (!RegExp(r'^[A-Z0-9]{16}$').hasMatch(s)) return false;
  var sum = 0;
  for (var i = 0; i < 15; i++) {
    final c = s[i];
    if (i % 2 == 0) {
      sum += _oddCf[c] ?? 0;
    } else {
      sum += RegExp(r'[0-9]').hasMatch(c) ? int.parse(c) : c.codeUnitAt(0) - 65;
    }
  }
  return String.fromCharCode(65 + sum % 26) == s[15];
}

/// Data di nascita e sesso ricavati dal codice fiscale (gestisce l'omocodia).
(DateTime, String)? cfBirth(String cf) {
  final s = cf.trim().toUpperCase();
  if (s.length != 16) return null;
  const omo = 'LMNPQRSTUV';
  String digits(String x) => x.split('').map((c) => omo.contains(c) ? '${omo.indexOf(c)}' : c).join();
  final yy = int.tryParse(digits(s.substring(6, 8)));
  final mm = 'ABCDEHLMPRST'.indexOf(s[8]) + 1;
  var dd = int.tryParse(digits(s.substring(9, 11)));
  if (yy == null || mm == 0 || dd == null) return null;
  final sex = dd > 40 ? 'F' : 'M';
  if (dd > 40) dd -= 40;
  final nowYy = DateTime.now().year % 100;
  final year = (yy <= nowYy ? 2000 : 1900) + yy;
  if (dd < 1 || dd > 31) return null;
  return (DateTime(year, mm, dd), sex);
}

/// Confronto senza maiuscole e accenti, per la ricerca.
String norm(String s) {
  const from = 'àáâäèéêëìíîïòóôöùúûü';
  const to = 'aaaaeeeeiiiioooouuuu';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

bool memberMatchesQuery(Member m, String q) {
  final n = norm(q.trim());
  if (n.isEmpty) return true;
  final name = norm(m.fullName);
  final rev = norm('${m.lastName} ${m.firstName}');
  return name.contains(n) ||
      rev.contains(n) ||
      m.cardNumber.toString() == n ||
      norm(m.taxCode).contains(n) ||
      (n.length >= 4 && m.phone.replaceAll(' ', '').contains(n.replaceAll(' ', ''))) ||
      norm(m.email).contains(n);
}
