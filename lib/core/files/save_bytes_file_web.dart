import "dart:js_interop";
import "dart:typed_data";

import "package:web/web.dart";

Future<String?> saveBytesToDeviceImpl({
	required Uint8List bytes,
	required String filename,
	required String mimeType,
}) async {
	final blobParts = <JSAny>[bytes.toJS].toJS;
	final blob = Blob(blobParts, BlobPropertyBag(type: mimeType));
	final url = URL.createObjectURL(blob);
	final anchor = document.createElement("a") as HTMLAnchorElement
		..href = url
		..download = filename
		..style.display = "none";
	document.body?.appendChild(anchor);
	anchor.click();
	anchor.remove();
	URL.revokeObjectURL(url);
	return filename;
}
