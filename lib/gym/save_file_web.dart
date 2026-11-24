import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> saveBytes(String name, Uint8List bytes, String mime) async {
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = 'data:$mime;base64,${base64Encode(bytes)}';
  a.download = name;
  web.document.body?.append(a);
  a.click();
  a.remove();
}
