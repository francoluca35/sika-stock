import "dart:typed_data";

Future<String?> saveBytesToDeviceImpl({
	required Uint8List bytes,
	required String filename,
	required String mimeType,
}) async {
	throw UnsupportedError("saveBytesToDevice no está disponible en esta plataforma.");
}
