import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> saveBytes(String name, Uint8List bytes, String mime) async {
  await Share.shareXFiles([XFile.fromData(bytes, name: name, mimeType: mime)], fileNameOverrides: [name]);
}
