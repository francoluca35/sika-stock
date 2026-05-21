import "dart:convert";
import "dart:typed_data";

/// Extrae texto de PDFs (varias estrategias; sin OCR).
abstract final class WorkOrderPdfTextExtractor {
	static String extractFlat(Uint8List bytes) {
		return extractLines(bytes).replaceAll(RegExp(r"\s+"), " ").trim();
	}

	static String extractLines(Uint8List bytes) {
		final latin = latin1.decode(bytes, allowInvalid: true);
		final buffer = StringBuffer();

		for (final m in RegExp(r"\(([^\\)]{1,1200})\)\s*Tj").allMatches(latin)) {
			_appendChunk(buffer, _decodePdfString(m.group(1) ?? ""));
		}

		for (final m in RegExp(r"\(([^\\)]{1,1200})\)").allMatches(latin)) {
			_appendChunk(buffer, _decodePdfString(m.group(1) ?? ""));
		}

		for (final m in RegExp(r"<([0-9A-Fa-f\s]{4,})>\s*Tj").allMatches(latin)) {
			_appendChunk(buffer, _decodeHex(m.group(1) ?? ""));
		}

		for (final m in RegExp(r"<([0-9A-Fa-f\s]{4,})>").allMatches(latin)) {
			_appendChunk(buffer, _decodeHex(m.group(1) ?? ""));
		}

		// Arrays TJ: [(texto) 12 (más)] TJ
		for (final m in RegExp(r"\[(.*?)\]\s*TJ", dotAll: true).allMatches(latin)) {
			final inner = m.group(1) ?? "";
			for (final sm in RegExp(r"\(([^\\)]*)\)").allMatches(inner)) {
				_appendChunk(buffer, _decodePdfString(sm.group(1) ?? ""));
			}
			for (final sm in RegExp(r"<([0-9A-Fa-f\s]+)>").allMatches(inner)) {
				_appendChunk(buffer, _decodeHex(sm.group(1) ?? ""));
			}
		}

		return buffer.toString();
	}

	/// Busca streams descomprimidos / texto en flujos del PDF.
	static String extractFromContentStreams(Uint8List bytes) {
		final latin = latin1.decode(bytes, allowInvalid: true);
		final buffer = StringBuffer();
		final streamRe = RegExp(
			r"stream\r?\n([\s\S]*?)\r?\nendstream",
			caseSensitive: false,
		);

		for (final m in streamRe.allMatches(latin)) {
			final chunk = m.group(1) ?? "";
			if (chunk.length < 20) continue;
			for (final tj in RegExp(r"\(([^\\)]{2,500})\)").allMatches(chunk)) {
				_appendChunk(buffer, _decodePdfString(tj.group(1) ?? ""));
			}
			for (final hex in RegExp(r"<([0-9A-Fa-f\s]{6,})>").allMatches(chunk)) {
				_appendChunk(buffer, _decodeHex(hex.group(1) ?? ""));
			}
		}

		return buffer.toString();
	}

	/// Elige el candidato que más se parece a una OT Sika.
	static String mergeCandidates(List<String> candidates) {
		if (candidates.isEmpty) return "";
		if (candidates.length == 1) return candidates.first;

		var best = candidates.first;
		var bestScore = _scoreOtText(best);

		for (var i = 1; i < candidates.length; i++) {
			final c = candidates[i];
			final score = _scoreOtText(c);
			if (score > bestScore) {
				bestScore = score;
				best = c;
			}
		}

		// Fusionar líneas únicas de todos los candidatos con buen puntaje
		if (bestScore < 15) {
			final lines = <String>{};
			final buf = StringBuffer();
			for (final c in candidates) {
				if (_scoreOtText(c) < 5) continue;
				for (final line in c.split(RegExp(r"[\r\n]+"))) {
					final t = line.trim();
					if (t.length < 2) continue;
					if (lines.add(t)) buf.writeln(t);
				}
			}
			final merged = buf.toString();
			if (_scoreOtText(merged) > bestScore) return merged;
		}

		return best;
	}

	static int _scoreOtText(String text) {
		if (text.trim().isEmpty) return 0;
		final u = text.toUpperCase();
		var score = 0;
		if (u.contains("ORDEN") && u.contains("TRABAJO")) score += 12;
		if (u.contains("SIKA")) score += 8;
		if (u.contains("PLANTA")) score += 6;
		if (u.contains("DESCRIPCI") && u.contains("TRABAJO")) score += 8;
		if (u.contains("PROCEDIMIENTO") || RegExp(r"6715|V1").hasMatch(u)) score += 4;
		if (u.contains("PREVENTIVO") || u.contains("CORRECTIVO")) score += 4;
		if (u.contains("FECHA") && u.contains("PROGRAM")) score += 4;
		if (u.contains("RESPONSABLE")) score += 3;
		if (u.contains("UBICACI")) score += 3;
		if (RegExp(r"\d{1,2}/\d{1,2}/\d{2,4}").hasMatch(text)) score += 3;
		if (text.length > 80) score += 2;
		if (text.length > 200) score += 2;
		return score;
	}

	static void _appendChunk(StringBuffer buffer, String chunk) {
		final t = chunk.replaceAll(RegExp(r"[ \t]+"), " ").trim();
		if (t.length < 1) return;
		if (RegExp(r"^[\d\.\s]+$").hasMatch(t) && t.length < 4) return;
		buffer.writeln(t);
	}

	static String _decodeHex(String raw) {
		final hex = raw.replaceAll(RegExp(r"\s+"), "");
		if (hex.length < 4 || !hex.length.isEven) return "";
		try {
			final codes = List.generate(
				hex.length ~/ 2,
				(i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
			);
			// UTF-16 BE con BOM FEFF
			if (codes.length >= 2 && codes[0] == 0xFE && codes[1] == 0xFF) {
				final chars = <int>[];
				for (var i = 2; i + 1 < codes.length; i += 2) {
					chars.add((codes[i] << 8) | codes[i + 1]);
				}
				return String.fromCharCodes(chars);
			}
			return String.fromCharCodes(codes);
		} catch (_) {
			return "";
		}
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
