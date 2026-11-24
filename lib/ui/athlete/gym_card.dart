import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../models.dart';
import '../../theme.dart';
import '../common/widgets.dart';
import '../gym/gym_widgets.dart';

/// Tessera della palestra nell'app del socio: QR da mostrare all'ingresso.
class GymCardPanel extends StatefulWidget {
  final AppUser me;
  final bool compact;
  const GymCardPanel({super.key, required this.me, this.compact = false});

  @override
  State<GymCardPanel> createState() => _GymCardPanelState();
}

class _GymCardPanelState extends State<GymCardPanel> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  Stream<Member?>? _member;

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

  void _showQr(String code, String name, String gymName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(gymName.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 1.6, color: BC.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontFamily: BC.display, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          QrImageView(data: 'BECOACH:$code', size: 260, backgroundColor: Colors.white),
          const SizedBox(height: 8),
          const Text('Mostralo allo scanner all\'ingresso', style: TextStyle(color: BC.muted)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.me.gymCard;
    if (card == null) {
      if (widget.compact) return const SizedBox.shrink();
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Hai la tessera di una palestra che usa BeCoach? Inserisci il codice scritto sulla tessera: '
              'avrai il QR per entrare e vedrai abbonamento e certificato.',
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
    final g = card['gymId'] as String? ?? '';
    final mid = card['memberId'] as String? ?? '';
    final code = card['code'] as String? ?? '';
    final gymName = card['gymName'] as String? ?? 'Palestra';
    _member ??= GymDb.memberStream(g, mid);
    return StreamBuilder<Member?>(
      stream: _member,
      builder: (context, snap) {
        final m = snap.data;
        return Panel(
          onTap: () => _showQr(code, m?.fullName ?? widget.me.name, gymName),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(border: Border.all(color: BC.border), borderRadius: BorderRadius.circular(4)),
              child: QrImageView(data: 'BECOACH:$code', size: widget.compact ? 64 : 84, padding: EdgeInsets.zero),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(gymName.toUpperCase(),
                    style: const TextStyle(fontSize: 11, letterSpacing: 1.4, color: BC.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(m == null ? 'Tessera' : m.cardLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (m != null) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    subTag(m),
                    if (m.cert.present) certTag(m, 30) else const StatusTag.warn('Certificato da consegnare'),
                  ]),
                ] else if (snap.hasError)
                  const Text('Tessera non più valida', style: TextStyle(color: BC.danger, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Tocca per ingrandire il QR', style: TextStyle(fontSize: 12, color: BC.muted)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
