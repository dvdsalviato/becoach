import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../gym/exports.dart';
import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../gym/images.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';
import 'credentials.dart';
import 'gym_widgets.dart';
import 'member_form.dart';
import 'sell_sheet.dart';

class MemberDetailPage extends StatefulWidget {
  final String memberId;
  const MemberDetailPage({super.key, required this.memberId});

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  Stream<Member?>? _member;
  Stream<List<Subscription>>? _subs;
  Stream<List<Payment>>? _pays;
  Stream<List<Checkin>>? _checks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_member == null) {
      final g = GymScope.of(context).gym.id;
      _member = GymDb.memberStream(g, widget.memberId);
      _subs = GymDb.memberSubs(g, widget.memberId);
      _pays = GymDb.memberPayments(g, widget.memberId);
      _checks = GymDb.memberCheckins(g, widget.memberId);
    }
  }

  Future<void> _photo(Member m) async {
    final src = await showSheet<ImageSource>(
      context,
      (c) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Scatta una foto'),
            onTap: () => Navigator.pop(c, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Scegli dalla galleria'),
            onTap: () => Navigator.pop(c, ImageSource.gallery)),
        const SizedBox(height: 12),
      ]),
    );
    if (src == null || !mounted) return;
    final g = GymScope.of(context).gym.id;
    try {
      final r = await pickPhoto(src);
      if (r == null) return;
      await GymDb.setPhoto(g, m.id, r.$1, r.$2);
      if (mounted) toast(context, 'Foto salvata');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  void _showCard(Member m) {
    final gym = GymScope.of(context).gym;
    showSheet(
      context,
      (c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.fullName, style: const TextStyle(fontFamily: BC.display, fontSize: 22, fontWeight: FontWeight.w700)),
            Text(m.cardLabel, style: const TextStyle(color: BC.muted)),
            const SizedBox(height: 16),
            QrImageView(data: 'BECOACH:${m.cardCode}', size: 220, backgroundColor: Colors.white),
            const SizedBox(height: 8),
            SelectableText('Codice tessera: ${m.cardCode}',
                style: const TextStyle(fontFamily: BC.display, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Text(
              m.linkedUid.isNotEmpty
                  ? 'Collegata all\'app BeCoach dell'iscritto.'
                  : 'L'iscritto può inserire questo codice nell\'app BeCoach (Profilo → Tessera palestra) e avere il QR sul telefono.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: BC.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => shareCard(gym, m),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Stampa tessera (PDF)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkin(Member m) async {
    final s = GymScope.of(context);
    final res = checkAccess(m, s.gym);
    var ok = true;
    if (!res.ok) {
      ok = await confirm(context, 'Ingresso non regolare', '${res.problems.join('\n')}\n\nFarlo entrare comunque?',
          ok: 'Fai entrare');
      if (!ok) return;
    }
    try {
      await GymDb.checkin(s.gym.id, m, ok: res.ok, note: res.ok ? '' : 'Forzato: ${res.problems.join(', ')}', by: s.me.name);
      if (mounted) toast(context, 'Ingresso registrato');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = GymScope.of(context);
    final gym = scope.gym;
    return StreamBuilder<Member?>(
      stream: _member,
      builder: (context, snap) {
        if (snap.hasError) return Scaffold(appBar: AppBar(), body: ErrorBox(friendlyError(snap.error!)));
        if (!snap.hasData) {
          return Scaffold(appBar: AppBar(), body: snap.connectionState == ConnectionState.waiting ? const Loading() : const ErrorBox('Iscritto non trovato'));
        }
        final m = snap.data!;
        final access = checkAccess(m, gym);
        return Scaffold(
          appBar: AppBar(
            title: Text(m.cardLabel),
            actions: [
              IconButton(tooltip: 'Tessera e QR', icon: const Icon(Icons.qr_code_2), onPressed: () => _showCard(m)),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await Navigator.push(context, gymRoute(context, (_) => MemberFormPage(member: m)));
                  } else if (v == 'archive') {
                    await GymDb.setArchived(gym.id, m.id, !m.archived);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifica anagrafica')),
                  PopupMenuItem(value: 'archive', child: Text(m.archived ? 'Ripristina iscritto' : 'Archivia iscritto')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _photo(m),
                    child: Stack(
                      children: [
                        MemberAvatar(m, size: 88),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(color: BC.graphite, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.photo_camera, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.fullName,
                            style: const TextStyle(fontFamily: BC.display, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.1)),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (m.birthDate != null) '${DateTime.now().difference(m.birthDate!).inDays ~/ 365} anni',
                            if (m.phone.isNotEmpty) m.phone,
                          ].join(' · '),
                          style: const TextStyle(color: BC.muted, fontSize: 13.5),
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          if (m.archived) const StatusTag.neutral('Archiviato'),
                          enrollTag(m),
                          subTag(m),
                          certTag(m, gym.certWarnDays),
                          if (m.linkedUid.isNotEmpty) const StatusTag.neutral('App collegata'),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: access.ok ? okBg : badBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(access.ok ? Icons.check_circle : Icons.block, color: access.ok ? okFg : badFg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        access.ok
                            ? (access.warnings.isEmpty ? 'Può entrare' : 'Può entrare · ${access.warnings.join(' · ')}')
                            : access.problems.join(' · '),
                        style: TextStyle(color: access.ok ? okFg : badFg, fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => showSellSheet(context, m),
                    icon: const Icon(Icons.add_card, size: 18),
                    label: const Text('Vendi abbonamento / iscrizione'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _checkin(m),
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Registra ingresso'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showCertSheet(context, m),
                    icon: const Icon(Icons.medical_information_outlined, size: 18),
                    label: const Text('Certificato'),
                  ),
                ],
              ),
              SectionLabel('Abbonamenti'),
              StreamBuilder<List<Subscription>>(
                stream: _subs,
                builder: (context, s) {
                  final list = s.data ?? [];
                  if (!s.hasData) return const Padding(padding: EdgeInsets.all(12), child: Loading());
                  if (list.isEmpty) {
                    return const Text('Nessun abbonamento venduto.', style: TextStyle(color: BC.muted));
                  }
                  return Column(children: [for (final x in list) SubscriptionCard(sub: x, member: m)]);
                },
              ),
              const SectionLabel('Certificato medico'),
              CertPanel(m: m),
              const SectionLabel('App dell\'iscritto'),
              AppAccessPanel(m: m),
              const SectionLabel('Pagamenti'),
              StreamBuilder<List<Payment>>(
                stream: _pays,
                builder: (context, s) {
                  final list = s.data ?? [];
                  if (list.isEmpty) return const Text('Nessun pagamento.', style: TextStyle(color: BC.muted));
                  return Panel(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          dense: true,
                          title: Text(list[i].description, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${dmy(list[i].date)} · ${list[i].method} · ric. ${list[i].receiptNo}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(euro(list[i].amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                            IconButton(
                              tooltip: 'Ricevuta PDF',
                              icon: const Icon(Icons.receipt_long_outlined, size: 20),
                              onPressed: () => shareReceipt(gym, list[i], m: m),
                            ),
                          ]),
                        ),
                      ],
                    ]),
                  );
                },
              ),
              const SectionLabel('Ultimi ingressi'),
              StreamBuilder<List<Checkin>>(
                stream: _checks,
                builder: (context, s) {
                  final list = s.data ?? [];
                  if (list.isEmpty) return const Text('Nessun ingresso registrato.', style: TextStyle(color: BC.muted));
                  return Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final c in list)
                      Tag('${dmy(c.at)} ${fmtTime(c.at)}${c.ok ? '' : ' · forzato'}',
                          fg: c.ok ? BC.body : badFg, bg: c.ok ? const Color(0xFFEEF0F2) : badBg),
                  ]);
                },
              ),
              const SectionLabel('Anagrafica'),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _kv('Codice fiscale', m.taxCode),
                  _kv('Nascita', [if (m.birthDate != null) dmy(m.birthDate), m.birthPlace].where((e) => e.isNotEmpty).join(' · ')),
                  _kv('Email', m.email),
                  _kv('Indirizzo', [m.address, [m.zip, m.city].where((e) => e.isNotEmpty).join(' ')].where((e) => e.isNotEmpty).join(', ')),
                  _kv('Consensi', [
                    m.privacy ? 'privacy ✓' : 'privacy ✗',
                    m.healthData ? 'dati sanitari ✓' : 'dati sanitari ✗',
                    m.photoConsent ? 'foto ✓' : 'foto ✗',
                    m.marketing ? 'comunicazioni ✓' : 'comunicazioni ✗',
                  ].join(' · ')),
                  if (m.consentAt != null) _kv('Consensi del', dmy(m.consentAt)),
                  if (m.notes.isNotEmpty) _kv('Note', m.notes),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(k, style: const TextStyle(fontSize: 13, color: BC.muted))),
          Expanded(child: Text(v.isEmpty ? '—' : v, style: const TextStyle(fontSize: 14))),
        ]),
      );
}

// ---------------- abbonamento ----------------

class SubscriptionCard extends StatelessWidget {
  final Subscription sub;
  final Member member;
  const SubscriptionCard({super.key, required this.sub, required this.member});

  Future<void> _pay(BuildContext context, int i) async {
    final scope = GymScope.of(context);
    final method = await pickMethod(context, sub.installments[i].amount);
    if (method == null) return;
    try {
      final p = await GymDb.payInstallment(scope.gym.id, sub, i, method: method, by: scope.me.name);
      if (context.mounted) {
        final r = await confirm(context, 'Incassato ${euro(p.amount)}', 'Ricevuta n. ${p.receiptNo}. Vuoi la ricevuta in PDF?',
            ok: 'Ricevuta PDF');
        if (r) await shareReceipt(scope.gym, p, m: member);
      }
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = GymScope.of(context);
    final today = dayOnly(DateTime.now());
    final active = sub.isEnroll
        ? !sub.cancelled && !today.isBefore(dayOnly(sub.start)) && !today.isAfter(dayOnly(sub.end))
        : sub.activeOn(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        borderColor: active ? BC.steel : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(sub.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              if (sub.cancelled)
                const StatusTag.neutral('Annullato')
              else if (active)
                const StatusTag.ok('In corso')
              else if (dayOnly(sub.start).isAfter(dayOnly(DateTime.now())))
                const StatusTag.neutral('Futuro')
              else if (sub.isAccess || sub.isEnroll)
                const StatusTag.neutral('Concluso'),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'cancel') {
                    if (await confirm(context, 'Annulla abbonamento',
                        'L\'abbonamento non darà più accesso e le rate non pagate non saranno più dovute. I pagamenti già fatti restano in cassa.',
                        ok: 'Annulla abbonamento', danger: true)) {
                      sub.cancelled = true;
                      await GymDb.updateSubscription(scope.gym.id, sub);
                    }
                  } else if (v == 'restore') {
                    sub.cancelled = false;
                    await GymDb.updateSubscription(scope.gym.id, sub);
                  } else if (v == 'delete') {
                    if (sub.paidAmount > 0) {
                      toast(context, 'Ci sono rate incassate: annulla prima gli incassi');
                      return;
                    }
                    if (await confirm(context, 'Elimina', 'Eliminare l\'abbonamento inserito per errore?', ok: 'Elimina', danger: true)) {
                      await GymDb.deleteSubscription(scope.gym.id, sub);
                    }
                  } else if (v == 'entries') {
                    final t = await askText(context,
                        title: 'Ingressi usati', initial: '${sub.entriesUsed}', keyboard: TextInputType.number);
                    final n = int.tryParse(t ?? '');
                    if (n != null) {
                      sub.entriesUsed = n.clamp(0, sub.entriesTotal);
                      await GymDb.updateSubscription(scope.gym.id, sub);
                    }
                  } else if (v == 'end') {
                    if (!context.mounted) return;
                    final d = await pickDay(context, sub.end);
                    if (d != null) {
                      sub.end = d;
                      await GymDb.updateSubscription(scope.gym.id, sub);
                    }
                  }
                },
                itemBuilder: (_) => [
                  if (sub.isAccess || sub.isEnroll) const PopupMenuItem(value: 'end', child: Text('Cambia scadenza')),
                  if (sub.kind == 'entries') const PopupMenuItem(value: 'entries', child: Text('Correggi ingressi usati')),
                  PopupMenuItem(value: sub.cancelled ? 'restore' : 'cancel', child: Text(sub.cancelled ? 'Ripristina' : 'Annulla abbonamento')),
                  const PopupMenuItem(value: 'delete', child: Text('Elimina (inserito per errore)')),
                ],
              ),
            ]),
            Text(
              [
                if (sub.isEnroll) 'Iscrizione',
                if (sub.isAccess || sub.isEnroll) '${dmy(sub.start)} → ${dmy(sub.end)}',
                if (sub.kind == 'entries') '${sub.entriesLeft} di ${sub.entriesTotal} ingressi',
                euro(sub.price) + (sub.listPrice > sub.price ? ' (listino ${euro(sub.listPrice)})' : ''),
              ].join(' · '),
              style: const TextStyle(fontSize: 13, color: BC.muted),
            ),
            if (sub.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(sub.notes, style: const TextStyle(fontSize: 13, color: BC.body)),
            ],
            const SizedBox(height: 8),
            for (var i = 0; i < sub.installments.length; i++) _installmentRow(context, i),
          ],
        ),
      ),
    );
  }

  Widget _installmentRow(BuildContext context, int i) {
    final inst = sub.installments[i];
    final overdue = !inst.paid && dayOnly(inst.due).isBefore(dayOnly(DateTime.now()).add(const Duration(days: 1)));
    final scope = GymScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: BC.border))),
      child: Row(children: [
        Icon(inst.paid ? Icons.check_circle : Icons.schedule, size: 18, color: inst.paid ? okFg : (overdue ? badFg : BC.muted)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            sub.installments.length > 1 ? 'Rata ${i + 1} · ${euro(inst.amount)}' : euro(inst.amount),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        Text(
          inst.paid ? 'pagata ${dmy(inst.paidAt)} · ${inst.method}' : 'scade ${dmy(inst.due)}',
          style: TextStyle(fontSize: 12.5, color: inst.paid ? BC.muted : (overdue ? badFg : BC.muted)),
        ),
        const SizedBox(width: 6),
        if (!inst.paid && !sub.cancelled)
          TextButton(onPressed: () => _pay(context, i), child: const Text('Incassa'))
        else if (inst.paid)
          IconButton(
            tooltip: 'Annulla incasso',
            icon: const Icon(Icons.undo, size: 18, color: BC.muted),
            onPressed: () async {
              if (await confirm(context, 'Annulla incasso', 'Il movimento sarà tolto dalla cassa.', ok: 'Annulla incasso', danger: true)) {
                await GymDb.unpayInstallment(scope.gym.id, sub, i);
              }
            },
          ),
      ]),
    );
  }
}

Future<String?> pickMethod(BuildContext context, double amount) => showSheet<String>(
      context,
      (c) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Incassa ${euro(amount)}', style: const TextStyle(fontFamily: BC.display, fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          for (final m in payMethods)
            ListTile(
              leading: Icon(_methodIcon(m)),
              title: Text(m),
              onTap: () => Navigator.pop(c, m),
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );

IconData _methodIcon(String m) {
  switch (m) {
    case 'Contanti':
      return Icons.payments_outlined;
    case 'POS / Carta':
      return Icons.credit_card;
    case 'Bonifico':
      return Icons.account_balance_outlined;
    case 'Satispay':
      return Icons.phone_iphone;
    default:
      return Icons.more_horiz;
  }
}

// ---------------- certificato ----------------

class CertPanel extends StatelessWidget {
  final Member m;
  const CertPanel({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    final c = m.cert;
    final gym = GymScope.of(context).gym;
    if (!c.present) {
      return Panel(
        onTap: () => showCertSheet(context, m),
        child: const Row(children: [
          Icon(Icons.add_circle_outline, color: BC.steel),
          SizedBox(width: 10),
          Expanded(child: Text('Aggiungi il certificato medico', style: TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
    }
    return Panel(
      onTap: () => showCertSheet(context, m),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Certificato ${c.type}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 3),
            Text(
              'Rilasciato ${dmy(c.issued)} · scade ${dmy(c.expiry)}${c.doctor.isNotEmpty ? ' · ${c.doctor}' : ''}',
              style: const TextStyle(fontSize: 13, color: BC.muted),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              certTag(m, gym.certWarnDays),
              c.verified
                  ? StatusTag.ok('Verificato da ${c.verifiedBy.isEmpty ? 'staff' : c.verifiedBy}')
                  : const StatusTag.warn('Non verificato'),
              if (c.hasImage) const StatusTag.neutral('Copia allegata'),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right, color: BC.disabled),
      ]),
    );
  }
}

Future<void> showCertSheet(BuildContext context, Member m) {
  final scope = GymScope.of(context);
  return showSheet(context, (c) => GymScope(gym: scope.gym, me: scope.me, child: _CertSheet(m: m)));
}

class _CertSheet extends StatefulWidget {
  final Member m;
  const _CertSheet({required this.m});

  @override
  State<_CertSheet> createState() => _CertSheetState();
}

class _CertSheetState extends State<_CertSheet> {
  late String _type = widget.m.cert.type;
  late DateTime? _issued = widget.m.cert.issued;
  late DateTime? _expiry = widget.m.cert.expiry;
  late bool _verified = widget.m.cert.verified;
  late final _doctor = TextEditingController(text: widget.m.cert.doctor);
  Uint8List? _newImage;
  Uint8List? _oldImage;
  bool _loadingImage = false;
  bool _removeImage = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.m.cert.hasImage) _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() => _loadingImage = true);
    try {
      _oldImage = await GymDb.getFile(GymScope.of(context).gym.id, widget.m.id, 'cert');
    } catch (_) {}
    if (mounted) setState(() => _loadingImage = false);
  }

  @override
  void dispose() {
    _doctor.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource s) async {
    try {
      final b = await pickDocument(s);
      if (b != null) {
        setState(() {
          _newImage = b;
          _removeImage = false;
        });
      }
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _save() async {
    if (_expiry == null) {
      setState(() => _error = 'Indica la data di scadenza');
      return;
    }
    final scope = GymScope.of(context);
    final old = widget.m.cert;
    final hasImg = _newImage != null || (old.hasImage && !_removeImage);
    final c = CertInfo(
      type: _type,
      issued: _issued,
      expiry: _expiry,
      verified: _verified,
      verifiedBy: _verified ? (old.verified ? old.verifiedBy : scope.me.name) : '',
      verifiedAt: _verified ? (old.verified ? old.verifiedAt : DateTime.now()) : null,
      hasImage: hasImg,
      doctor: _doctor.text.trim(),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GymDb.setCert(scope.gym.id, widget.m.id, c, image: _newImage, removeImage: _removeImage);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _newImage ?? (_removeImage ? null : _oldImage);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        const Text('Certificato medico', style: TextStyle(fontFamily: BC.display, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: certTypes.contains(_type) ? _type : certTypes.first,
          decoration: const InputDecoration(labelText: 'Tipo'),
          items: [for (final t in certTypes) DropdownMenuItem(value: t, child: Text(t))],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DateField(
              label: 'Rilasciato il',
              value: _issued,
              onChanged: (d) => setState(() {
                _issued = d;
                if (d != null) _expiry = addMonths(d, 12).subtract(const Duration(days: 1));
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: DateField(label: 'Scade il', value: _expiry, onChanged: (d) => setState(() => _expiry = d))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _doctor, decoration: const InputDecoration(labelText: 'Medico / struttura (facoltativo)')),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _verified,
          onChanged: (v) => setState(() => _verified = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('Verificato', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Ho controllato l\'originale: dati, firma e timbro del medico.', style: TextStyle(fontSize: 12.5)),
        ),
        const SectionLabel('Copia del certificato'),
        if (_loadingImage)
          const Padding(padding: EdgeInsets.all(16), child: Loading())
        else if (img != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: InteractiveViewer(child: Image.memory(img, fit: BoxFit.contain)),
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              _newImage = null;
              _removeImage = true;
            }),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Rimuovi la copia'),
          ),
        ],
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Fotografa'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Carica'),
            ),
          ),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: BC.danger)),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Salva certificato')),
      ],
    );
  }
}
