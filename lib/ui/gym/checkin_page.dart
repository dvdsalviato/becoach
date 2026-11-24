import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../gym/gym_db.dart';
import '../../gym/gym_models.dart';
import '../../theme.dart';
import '../../util.dart';
import '../common/widgets.dart';
import 'gym_shell.dart';
import 'gym_widgets.dart';
import 'members_page.dart';

/// Ingressi: scansione della tessera (QR) o ricerca, controllo abbonamento e certificato.
class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key});

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  MobileScannerController? _cam;
  String _q = '';
  final _search = TextEditingController();
  Stream<List<Member>>? _members;
  Stream<List<Checkin>>? _today;
  String? _gid;

  Member? _member;
  AccessCheck? _check;
  Uint8List? _photo;
  bool _registered = false;
  bool _busy = false;
  String? _error;
  String _lastCode = '';
  DateTime _lastAt = DateTime(2000);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final g = GymScope.of(context).gym.id;
    if (g != _gid) {
      _gid = g;
      _members = GymDb.membersStream(g);
      _today = GymDb.checkinsSince(g, dayOnly(DateTime.now()));
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    _search.dispose();
    super.dispose();
  }

  void _toggleCam() {
    setState(() {
      if (_cam == null) {
        _cam = MobileScannerController(detectionSpeed: DetectionSpeed.normal, formats: const [BarcodeFormat.qrCode]);
      } else {
        _cam!.dispose();
        _cam = null;
      }
    });
  }

  Future<void> _onCode(String raw) async {
    final now = DateTime.now();
    if (raw == _lastCode && now.difference(_lastAt).inSeconds < 6) return;
    _lastCode = raw;
    _lastAt = now;
    if (_busy) return;
    final g = GymScope.of(context).gym.id;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final m = await GymDb.findByCode(g, raw);
      if (m == null) {
        HapticFeedback.heavyImpact();
        setState(() {
          _member = null;
          _error = 'Tessera non riconosciuta';
        });
      } else {
        await _show(m);
      }
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _show(Member m) async {
    final scope = GymScope.of(context);
    final check = checkAccess(m, scope.gym);
    setState(() {
      _member = m;
      _check = check;
      _photo = null;
      _registered = false;
      _error = null;
    });
    if (check.ok) {
      HapticFeedback.mediumImpact();
      await GymDb.checkin(scope.gym.id, m, ok: true, by: scope.me.name);
      if (mounted) setState(() => _registered = true);
    } else {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
    try {
      final p = await GymDb.getFile(scope.gym.id, m.id, 'photo');
      if (mounted && _member?.id == m.id) setState(() => _photo = p);
    } catch (_) {}
  }

  Future<void> _force() async {
    final m = _member, c = _check;
    if (m == null || c == null) return;
    final scope = GymScope.of(context);
    await GymDb.checkin(scope.gym.id, m, ok: false, note: 'Forzato: ${c.problems.join(', ')}', by: scope.me.name);
    if (mounted) setState(() => _registered = true);
  }

  Widget _scanner() {
    final cam = _cam;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cam != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(fit: StackFit.expand, children: [
                  MobileScanner(
                    controller: cam,
                    onDetect: (cap) {
                      final v = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
                      if (v != null && v.isNotEmpty) _onCode(v);
                    },
                  ),
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(border: Border.all(color: Colors.white70, width: 3), borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (_busy) const ColoredBox(color: Color(0x55000000), child: Loading()),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggleCam,
                  icon: Icon(cam == null ? Icons.qr_code_scanner : Icons.videocam_off_outlined, size: 18),
                  label: Text(cam == null ? 'Avvia scanner tessere' : 'Spegni fotocamera'),
                ),
              ),
              if (cam != null) ...[
                const SizedBox(width: 8),
                IconButton(tooltip: 'Cambia fotocamera', onPressed: () => cam.switchCamera(), icon: const Icon(Icons.cameraswitch_outlined)),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _manual(List<Member> all) {
    final q = _q.trim().toLowerCase();
    final res = q.isEmpty
        ? <Member>[]
        : all
            .where((m) =>
                !m.archived &&
                (m.fullName.toLowerCase().contains(q) ||
                    '${m.lastName} ${m.firstName}'.toLowerCase().contains(q) ||
                    m.cardNumber.toString() == q ||
                    m.cardCode.toLowerCase() == q))
            .take(6)
            .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _search,
        onChanged: (v) => setState(() => _q = v),
        onSubmitted: (v) {
          if (res.length == 1) {
            _show(res.first);
          } else if (v.trim().length >= 6) {
            _onCode(v.trim());
          }
        },
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Nome, n. tessera o codice',
          suffixIcon: _q.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() {
                    _q = '';
                    _search.clear();
                  })),
        ),
      ),
      for (final m in res)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: MemberAvatar(m, size: 36),
          title: Text(m.fullName),
          subtitle: Text('n. ${m.cardNumber}'),
          onTap: () {
            setState(() {
              _q = '';
              _search.clear();
            });
            _show(m);
          },
        ),
    ]);
  }

  Widget _result() {
    final gym = GymScope.of(context).gym;
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: badBg, borderRadius: BorderRadius.circular(4)),
        child: Row(children: [
          const Icon(Icons.error_outline, color: badFg, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text(_error!, style: const TextStyle(color: badFg, fontSize: 17, fontWeight: FontWeight.w700))),
        ]),
      );
    }
    final m = _member, c = _check;
    if (m == null || c == null) {
      return Panel(
        color: BC.subtle,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Column(children: [
            Icon(Icons.badge_outlined, size: 36, color: BC.steelLight),
            SizedBox(height: 8),
            Text('Scansiona una tessera o cerca un socio', style: TextStyle(color: BC.muted)),
          ]),
        ),
      );
    }
    final fg = c.ok ? okFg : badFg, bg = c.ok ? okBg : badBg;
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: fg.withValues(alpha: 0.4), width: 2)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _photo != null
                ? Image.memory(_photo!, width: 110, height: 110, fit: BoxFit.cover)
                : SizedBox(width: 110, height: 110, child: Center(child: MemberAvatar(m, size: 90))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.ok ? 'INGRESSO OK' : 'NON PUÒ ENTRARE',
                  style: TextStyle(color: fg, fontFamily: BC.display, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(m.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              Text('${m.cardLabel}${m.subName.isNotEmpty ? ' · ${m.subName}' : ''}', style: const TextStyle(color: BC.body)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [subTag(m), certTag(m, gym.certWarnDays)]),
            ]),
          ),
        ]),
        if (c.problems.isNotEmpty || c.warnings.isNotEmpty) const SizedBox(height: 12),
        for (final p in c.problems)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Icon(Icons.block, size: 18, color: badFg),
              const SizedBox(width: 8),
              Expanded(child: Text(p, style: const TextStyle(color: badFg, fontWeight: FontWeight.w600))),
            ]),
          ),
        for (final w in c.warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: BC.warnFg),
              const SizedBox(width: 8),
              Expanded(child: Text(w, style: const TextStyle(color: BC.warnFg, fontWeight: FontWeight.w600))),
            ]),
          ),
        const SizedBox(height: 10),
        Row(children: [
          if (_registered)
            Expanded(
              child: Text(c.ok ? 'Ingresso registrato alle ${fmtTime(DateTime.now())}' : 'Ingresso forzato registrato',
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
            )
          else if (!c.ok)
            Expanded(child: OutlinedButton(onPressed: _force, child: const Text('Fai entrare comunque'))),
          if (!_registered && c.ok) const Spacer(),
          const SizedBox(width: 8),
          TextButton(onPressed: () => openMember(context, m.id), child: const Text('Scheda socio')),
        ]),
      ]),
    );
  }

  Widget _log() {
    return StreamBuilder<List<Checkin>>(
      stream: _today,
      builder: (context, snap) {
        final list = snap.data ?? [];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionLabel('Ingressi di oggi · ${list.where((c) => c.ok).length}'),
          if (list.isEmpty)
            const Text('Ancora nessun ingresso oggi.', style: TextStyle(color: BC.muted))
          else
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < list.length && i < 60; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    dense: true,
                    onTap: () => openMember(context, list[i].memberId),
                    leading: Icon(list[i].ok ? Icons.login : Icons.warning_amber_rounded, color: list[i].ok ? okFg : badFg, size: 20),
                    title: Text(list[i].memberName),
                    subtitle: list[i].note.isEmpty ? null : Text(list[i].note, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(fmtTime(list[i].at), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
            ),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Member>>(
        stream: _members,
        builder: (context, snap) {
          final all = snap.data ?? [];
          final left = [_scanner(), const SizedBox(height: 12), _manual(all)];
          final right = [_result(), _log()];
          return LayoutBuilder(builder: (context, cons) {
            final wide = cons.maxWidth >= 900;
            if (!wide) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  const PageHeader(overline: 'Reception', title: 'Ingressi'),
                  ...left,
                  const SizedBox(height: 16),
                  ...right,
                ],
              );
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const PageHeader(overline: 'Reception', title: 'Ingressi'),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 420,
                    child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 10, 32), children: left),
                  ),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.fromLTRB(10, 0, 20, 32), children: right),
                  ),
                ]),
              ),
            ]);
          });
        },
      ),
    );
  }
}
