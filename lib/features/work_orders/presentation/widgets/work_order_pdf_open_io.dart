import "dart:io";
import "dart:typed_data";

import "package:open_filex/open_filex.dart";
import "package:path_provider/path_provider.dart";

/// Abre el PDF con la app del celular (visor nativo Android/iOS).
Future<bool> openPdfExternally(Uint8List pdfBytes, {String? otNumber}) async {
	final dir = await getTemporaryDirectory();
	final safeOt = (otNumber ?? "").replaceAll(RegExp(r"[^\w-]"), "");
	final name = safeOt.isEmpty
			? "ot-${DateTime.now().millisecondsSinceEpoch}.pdf"
			: "ot-$safeOt.pdf";
	final file = File("${dir.path}/$name");
	await file.writeAsBytes(pdfBytes, flush: true);
	final result = await OpenFilex.open(file.path, type: "application/pdf");
	return result.type == ResultType.done;
}

void openPdfInBrowserTab(Uint8List pdfBytes) {}
