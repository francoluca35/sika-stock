import "dart:typed_data";

import "save_bytes_file_stub.dart"
	if (dart.library.html) "save_bytes_file_web.dart"
	if (dart.library.io) "save_bytes_file_io.dart";

/// Guarda bytes en el dispositivo (descarga en web, carpeta Descargas en móvil/escritorio).
Future<String?> saveBytesToDevice({
	required Uint8List bytes,
	required String filename,
	String mimeType = "application/octet-stream",
}) =>
		saveBytesToDeviceImpl(bytes: bytes, filename: filename, mimeType: mimeType);
