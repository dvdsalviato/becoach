import 'dart:typed_data';

import 'save_file_mobile.dart' if (dart.library.js_interop) 'save_file_web.dart' as impl;

/// Salva/condivide un file generato (CSV, PDF): sul web lo scarica, sul telefono apre "Condividi".
Future<void> saveBytes(String name, Uint8List bytes, String mime) => impl.saveBytes(name, bytes, mime);
