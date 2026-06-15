import "dart:io";
import "dart:typed_data";

import "package:path_provider/path_provider.dart";

Future<String?> saveBytesToDeviceImpl({
	required Uint8List bytes,
	required String filename,
	required String mimeType,
}) async {
	final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), "_");
	Directory? dir = await getDownloadsDirectory();
	dir ??= await getApplicationDocumentsDirectory();
	final file = File("${dir.path}/$safeName");
	await file.writeAsBytes(bytes, flush: true);
	return file.path;
}
