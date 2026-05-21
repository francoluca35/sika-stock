import "dart:typed_data";

import "package:syncfusion_flutter_pdf/pdf.dart";

import "work_order_pdf_text_extractor.dart";

/// Syncfusion (web, Android, iOS, desktop).
String extractPdfText(Uint8List bytes) => extractPdfTextSyncfusion(bytes);

String extractPdfTextSyncfusion(Uint8List bytes) {
	final document = PdfDocument(inputBytes: bytes);
	try {
		final extractor = PdfTextExtractor(document);
		final buffer = StringBuffer();

		for (var i = 0; i < document.pages.count; i++) {
			final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
			if (pageText.trim().isNotEmpty) {
				buffer.writeln(pageText);
			}
		}

		final perPage = buffer.toString();
		if (perPage.trim().length >= 30) return perPage;

		final all = extractor.extractText();
		if (all.trim().length >= 30) return all;

		return WorkOrderPdfTextExtractor.extractLines(bytes);
	} finally {
		document.dispose();
	}
}
