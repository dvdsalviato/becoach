import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import '../gym/gym_widgets.dart';

/// QR d'ingresso: si rigenera a ogni apertura e ogni minuto, vale pochi minuti.
class DynamicQr extends StatefulWidget {
  final String gymId;
  final String memberId;
  final String staticCode;
  final double size;
  const DynamicQr({super.key, required this.gymId, required this.memberId, required this.staticCode, this.size = 220});

  @override
  State<DynamicQr> createState() => _DynamicQrState();
}

class _DynamicQrState extends State<DynamicQr> with WidgetsBindingObserver {
  String? _token;
  Timer? _timer;
  DateTime _at = DateTime.now();
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().difference(_at).inSeconds >= 60) {
        _refresh();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    _at = DateTime.now();
    try {
      final t = await GymDb.refreshQrToken(widget.gymId, widget.memberId);
      if (mounted) setState(() {
        _token = t;
        _offline = false;
      });
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _token != null && !_offline ? 'BECOACH:T:$_token' : 'BECOACH:${widget.staticCode}';
    final left = (60 - DateTime.now().difference(_at).inSeconds).clamp(0, 60);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      QrImageView(data: data, size: widget.size, backgroundColor: Colors.white, padding: const EdgeInsets.all(8)),
      SizedBox(
        width: widget.size * 0.8,
        child: LinearProgressIndicator(
          value: left / 60,
          minHeight: 3,
          color: BC.steel,
          backgroundColor: BC.border,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _offline ? 'Senza connessione: QR fisso della tessera' : 'Si rinnova da solo · avvicinalo al lettore',
        style: const TextStyle(fontSize: 12, color: BC.muted),
      ),
    ]);
  }
}

/// In cima alla Home dell'iscritto: QR grande pronto per il tornello.
class GymEntryCard extends StatefulWidget {
  final AppUser me;
  const GymEntryCard({super.key, required this.me});

  @override
  State<GymEntryCard> createState() => _GymEntryCardState();
}

class _GymEntryCardState extends State<GymEntryCard> {
  Stream<Member?>? _member;

  @override
  Widget build(BuildContext context) {
    final card = widget.me.gymCard!;
    final g = card['gymId'] as String? ?? '';
    final mid = card['memberId'] as String? ?? '';
    final code = card['code'] as String? ?? '';
    final gymName = card['gymName'] as String? ?? 'Palestra';
    _member ??= GymDb.memberStream(g, mid);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: StreamBuilder<Member?>(
        stream: _member,
        builder: (context, snap) {
          final m = snap.data;
          return Column(children: [
            Text(gymName.toUpperCase(),
                style: const TextStyle(fontSize: 11, letterSpacing: 1.6, color: BC.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            DynamicQr(gymId: g, memberId: mid, staticCode: code, size: 230),
            if (m != null) ...[
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 4, children: [
                subTag(m),
                enrollTag(m),
                if (m.cert.present) certTag(m, 30) else const StatusTag.warn('Certificato da consegnare'),
              ]),
            ],
          ]);
        },
      ),
    );
  }
}

/// Nel Profilo: collega la tessera con il codice, oppure mostra la tessera collegata.
class GymCardPanel extends StatefulWidget {
  final AppUser me;
  const GymCardPanel({super.key, required this.me});

  @override
  State<GymCardPanel> createState() => _GymCardPanelState();
}

class _GymCardPanelState extends State<GymCardPanel> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await GymDb.linkCard(widget.me, _code.text);
      if (!ok) setState(() => _error = 'Codice tessera non trovato');
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.me.gymCard;
    if (card == null) {
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Sei iscritto a una palestra che usa BeCoach? Inserisci il codice della tessera: '
              'in Home avrai il QR per il tornello.',
              style: TextStyle(fontSize: 13, color: BC.muted, height: 1.4)),
          const SizedBox(height: 10),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Codice tessera'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: BC.danger, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _busy ? null : _link, child: const Text('Collega tessera')),
        ]),
      );
    }
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${card['gymName'] ?? 'Palestra'} · codice ${card['code'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Il QR per entrare è in cima alla Home.', style: TextStyle(fontSize: 13, color: BC.muted)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final email = FirebaseAuth.instance.currentUser?.email ?? widget.me.email;
            try {
              await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
              if (context.mounted) toast(context, 'Ti abbiamo mandato un\'email a $email per scegliere una nuova password');
            } catch (e) {
              if (context.mounted) toast(context, friendlyError(e));
            }
          },
          icon: const Icon(Icons.lock_reset, size: 18),
          label: const Text('Cambia password'),
        ),
      ]),
    );
  }
}
