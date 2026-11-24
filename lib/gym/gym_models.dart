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
    );
  }

  bool isOwner(String uid) => owner == uid;
  bool isStaff(String uid) => staff.contains(uid);
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
  if (m.archived) problems.add('Socio archiviato');
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
  if (!m.privacy) warnings.add('Manca il consenso privacy');
  return AccessCheck(problems.isEmpty, problems, warnings);
}
