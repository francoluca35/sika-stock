import "dart:convert";
import "dart:typed_data";

import "package:web/web.dart" as web;

Future<bool> openPdfExternally(Uint8List pdfBytes, {String? otNumber}) async {
	openPdfInBrowserTab(pdfBytes);
	return true;
}

void openPdfInBrowserTab(Uint8List pdfBytes) {
	final b64 = base64Encode(pdfBytes);
	web.window.open("data:application/pdf;base64,$b64", "_blank");
}
