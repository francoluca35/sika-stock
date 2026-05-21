import "dart:convert";
import "dart:typed_data";

/// Extrae texto legible de PDFs con fuentes embebidas (sin OCR).
abstract final class WorkOrderPdfTextExtractor {
	/// Texto en una sola línea (búsqueda por regex).
	static String extractFlat(Uint8List bytes) {
		return extractLines(bytes).replaceAll(RegExp(r"\s+"), " ").trim();
	}

	/// Conserva saltos de línea para ubicar sector, planta, etc.
	static String extractLines(Uint8List bytes) {
		final latin = latin1.decode(bytes, allowInvalid: true);
		final buffer = StringBuffer();

		for (final m in RegExp(r"\(([^\\)]{1,800})\)").allMatches(latin)) {
			final chunk = _decodePdfString(m.group(1) ?? "");
			if (chunk.trim().length >= 1) buffer.writeln(chunk);
		}

		for (final m in RegExp(r"<([0-9A-Fa-f\s]{4,})>").allMatches(latin)) {
			final hex = m.group(1)!.replaceAll(RegExp(r"\s+"), "");
			if (hex.length.isEven) {
				try {
					final decoded = String.fromCharCodes(
						List.generate(
							hex.length ~/ 2,
							(i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
						),
					);
					if (decoded.trim().isNotEmpty) buffer.writeln(decoded);
				} catch (_) {}
			}
		}

		return buffer.toString();
	}

	static String _decodePdfString(String raw) {
		return raw
				.replaceAll(r"\(", "(")
				.replaceAll(r"\)", ")")
				.replaceAll(r"\\", r"\")
				.replaceAll(r"\n", "\n")
				.replaceAll(r"\r", "\r")
				.replaceAll(r"\t", "\t");
	}
}
