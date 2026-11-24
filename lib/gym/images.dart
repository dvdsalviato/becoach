import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Foto del socio: immagine (max 640 px) e miniatura per le liste.
Future<(Uint8List, Uint8List)?> pickPhoto(ImageSource source) async {
  final x = await ImagePicker().pickImage(
      source: source, maxWidth: 640, maxHeight: 640, imageQuality: 75, preferredCameraDevice: CameraDevice.front);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final sq = img.copyResizeCropSquare(decoded, size: 120);
  final thumb = Uint8List.fromList(img.encodeJpg(sq, quality: 70));
  final full = img.copyResize(decoded, width: decoded.width > decoded.height ? 640 : null, height: decoded.height >= decoded.width ? 640 : null);
  return (Uint8List.fromList(img.encodeJpg(full, quality: 78)), thumb);
}

/// Foto del certificato medico, compressa per stare sotto il limite del documento (≈ 700 kB).
Future<Uint8List?> pickDocument(ImageSource source) async {
  final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 70);
  if (x == null) return null;
  var bytes = await x.readAsBytes();
  if (bytes.length <= 700 * 1024) return bytes;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var w = decoded.width > 1400 ? 1400 : decoded.width;
  var q = 65;
  for (var i = 0; i < 6; i++) {
    final r = img.copyResize(decoded, width: w);
    bytes = Uint8List.fromList(img.encodeJpg(r, quality: q));
    if (bytes.length <= 700 * 1024) return bytes;
    w = (w * 0.8).round();
    q = q > 45 ? q - 8 : q;
  }
  return bytes;
}
