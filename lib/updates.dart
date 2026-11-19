import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'theme.dart';
import 'ui/common/widgets.dart';

/// Repo pubblico con le release: l'app controlla qui se c'è una versione nuova.
const publicReleasesRepo = 'dvdsalviato/becoach';

class UpdateInfo {
  final String version;
  final int build;
  final String url;
  final String notes;
  UpdateInfo(this.version, this.build, this.url, this.notes);
}

class Updates {
  static bool _checkedThisRun = false;

  static Future<(String, int)> current() async {
    final p = await PackageInfo.fromPlatform();
    return (p.version, int.tryParse(p.buildNumber) ?? 0);
  }

  /// Ultima versione pubblicata, oppure null se non raggiungibile.
  static Future<UpdateInfo?> latest() async {
    try {
      final r = await http
          .get(Uri.parse('https://api.github.com/repos/$publicReleasesRepo/releases/latest'),
              headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final tag = (j['tag_name'] as String?) ?? '';
      final m = RegExp(r'v?([\d.]+)-(\d+)').firstMatch(tag);
      if (m == null) return null;
      String url = '';
      for (final a in (j['assets'] as List? ?? [])) {
        final u = (a as Map)['browser_download_url'] as String? ?? '';
        if (u.endsWith('.apk')) url = u;
      }
      if (url.isEmpty) return null;
      return UpdateInfo(m.group(1)!, int.parse(m.group(2)!), url, (j['body'] as String?) ?? '');
    } catch (_) {
      return null;
    }
  }

  /// All'avvio: se c'è una versione più nuova propone di aggiornare (una volta per apertura).
  static Future<void> checkOnStart(BuildContext context) async {
    if (_checkedThisRun) return;
    _checkedThisRun = true;
    final info = await latest();
    if (info == null) return;
    final (_, build) = await current();
    if (info.build <= build || !context.mounted) return;
    await showUpdateDialog(context, info);
  }

  /// Controllo manuale dal profilo.
  static Future<void> checkManually(BuildContext context) async {
    final info = await latest();
    if (!context.mounted) return;
    if (info == null) {
      toast(context, 'Impossibile controllare gli aggiornamenti adesso');
      return;
    }
    final (_, build) = await current();
    if (!context.mounted) return;
    if (info.build <= build) {
      toast(context, 'Hai già l\'ultima versione');
    } else {
      await showUpdateDialog(context, info);
    }
  }

  static Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
    final notes = info.notes
        .split('\n')
        .where((l) => l.trim().startsWith('-'))
        .take(6)
        .map((l) => '• ${l.trim().substring(1).trim()}')
        .join('\n');
    return showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('È disponibile una nuova versione dell\'app',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Text(
            'BeCoach ${info.version}${notes.isEmpty ? '' : '\n\n$notes'}',
            style: const TextStyle(color: BC.body, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Più tardi', style: TextStyle(color: BC.muted))),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              openUrl(context, info.url);
            },
            child: const Text('Aggiorna ora'),
          ),
        ],
      ),
    );
  }
}
