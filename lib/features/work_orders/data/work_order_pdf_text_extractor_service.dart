import "dart:typed_data";

import "work_order_pdf_syncfusion_impl.dart";
import "work_order_pdf_text_extractor.dart";

/// Extracción unificada: Syncfusion + fallbacks; elige el texto más completo.
abstract final class WorkOrderPdfTextExtractorService {
	static String extractLines(Uint8List bytes) {
		final candidates = <String>[];

		try {
			final sync = extractPdfTextSyncfusion(bytes);
			if (sync.trim().isNotEmpty) candidates.add(sync);
		} catch (_) {}

		final legacy = WorkOrderPdfTextExtractor.extractLines(bytes);
		if (legacy.trim().isNotEmpty) candidates.add(legacy);

		final streams = WorkOrderPdfTextExtractor.extractFromContentStreams(bytes);
		if (streams.trim().isNotEmpty) candidates.add(streams);

		final merged = WorkOrderPdfTextExtractor.mergeCandidates(candidates);
		if (merged.trim().isNotEmpty) return merged;

		return legacy;
	}
}
