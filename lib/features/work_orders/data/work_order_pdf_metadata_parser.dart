import "dart:typed_data";

import "../domain/work_order_pdf_metadata.dart";
import "work_order_pdf_text_extractor.dart";

/// Parser para plantilla OT Sika (ORDEN DE TRABAJO N°, PLANTA_VIRREY, sector, etc.).
class WorkOrderPdfMetadataParser {
	static WorkOrderPdfMetadata parseFromPdfBytes(List<int> bytes) {
		final lineText = WorkOrderPdfTextExtractor.extractLines(Uint8List.fromList(bytes));
		final flat = lineText.replaceAll(RegExp(r"[ \t]+"), " ").replaceAll(RegExp(r"\n+"), " ").trim();
		return parseFromText(lineText, flat);
	}

	static WorkOrderPdfMetadata parseFromText(String lineText, [String? flatText]) {
		final flat = flatText ?? lineText.replaceAll(RegExp(r"\s+"), " ").trim();
		final lines = _lines(lineText);
		final upperFlat = flat.toUpperCase();

		return WorkOrderPdfMetadata(
			company: _company(flat, upperFlat),
			plant: _plant(lines, flat),
			sector: _sector(lines),
			location: _labelValue(flat, [
				RegExp(r"UBICACI[OÓ]N\s*:?\s*([A-ZÁÉÍÓÚÑ0-9\s\-]+?)(?=\s+TOLERANCIA|\s+DESCRIPCI|$)", caseSensitive: false),
			]),
			orderType: _labelValue(flat, [
				RegExp(r"(?<!DE\s)TIPO\s*:?\s*([A-ZÁÉÍÓÚÑ]+)", caseSensitive: false),
			]),
			date: _labelValue(flat, [
				RegExp(
					r"FECHA\s*PROGRAMACI[OÓ]N\s*:?\s*([0-9]{1,2}[/.\-][0-9]{1,2}[/.\-][0-9]{2,4})",
					caseSensitive: false,
				),
				RegExp(r"FECHA\s*:?\s*([0-9]{1,2}[/.\-][0-9]{1,2}[/.\-][0-9]{2,4})", caseSensitive: false),
			]),
			responsible: _labelValue(flat, [
				RegExp(r"RESPONSABLE\s*:?\s*([^:]+?)(?=\s+TIPO|\s+SOLICITADO|\s+RECIBE|\s+UBICACI|$)", caseSensitive: false),
			]),
			orderNumber: _orderNumber(flat, upperFlat),
			receiver: "",
			tolerance: _labelValue(flat, [
				RegExp(
					r"TOLERANCIA\s*:?\s*([0-9]{1,2}[/.\-][0-9]{1,2}[/.\-][0-9]{2,4})",
					caseSensitive: false,
				),
			]),
			workDescription: _workDescription(lineText, flat),
		);
	}

	static List<String> _lines(String text) {
		return text
				.split(RegExp(r"[\r\n]+"))
				.map((l) => l.trim())
				.where((l) => l.isNotEmpty)
				.toList();
	}

	static String _company(String flat, String upper) {
		final m = RegExp(
			r"SIKA\s+S\.?\s*A\.?\s*I\.?\s*C\.?",
			caseSensitive: false,
		).firstMatch(flat);
		if (m != null) return "SIKA S.A.I.C";
		if (upper.contains("SIKA")) return "SIKA S.A.I.C";
		return "";
	}

	static String _plant(List<String> lines, String flat) {
		for (final line in lines) {
			if (RegExp(r"PLANTA[_\s-]+VIRREY", caseSensitive: false).hasMatch(line)) {
				return "PLANTA_VIRREY";
			}
			if (RegExp(r"^PLANTA[_\s]", caseSensitive: false).hasMatch(line)) {
				return line.replaceAll(" ", "_").toUpperCase();
			}
		}
		final m = RegExp(r"PLANTA[_\s-]*VIRREY", caseSensitive: false).firstMatch(flat);
		if (m != null) return "PLANTA_VIRREY";
		return "";
	}

	static String _sector(List<String> lines) {
		final stop = RegExp(
			r"^(UBICACI|TOLERANCIA|TIPO\s|FECHA|RESPONSABLE|DESCRIPCI|NOVEDAD|PROCEDIMIENTO|SOLICITADO|PRIORIDAD|RECIBE|ORDEN\s+DE)",
			caseSensitive: false,
		);
		var plantIdx = -1;
		for (var i = 0; i < lines.length; i++) {
			if (RegExp(r"PLANTA[_\s]", caseSensitive: false).hasMatch(lines[i])) {
				plantIdx = i;
				break;
			}
		}
		if (plantIdx < 0) return "";

		final parts = <String>[];
		for (var i = plantIdx + 1; i < lines.length; i++) {
			final line = lines[i];
			if (stop.hasMatch(line)) break;
			if (RegExp(r"^SIKA\s", caseSensitive: false).hasMatch(line)) continue;
			parts.add(line);
		}
		return parts.join("\n");
	}

	static String _orderNumber(String flat, String upper) {
		final patterns = [
			RegExp(
				r"ORDEN\s+DE\s+TRABAJO\s+N[°ºo\.#]*\s*(\d{1,8})",
				caseSensitive: false,
			),
			RegExp(r"ORDEN\s+DE\s+TRABAJO\s+N[°ºo\.#]*(\d{1,8})", caseSensitive: false),
			RegExp(r"N[°ºo\.#]+\s*(\d{1,8})(?=\s|$)", caseSensitive: false),
		];
		for (final p in patterns) {
			final m = p.firstMatch(flat);
			if (m != null) return m.group(1)!.trim();
		}
		final m = RegExp(r"OT-?\s*(\d+)", caseSensitive: false).firstMatch(flat);
		if (m != null) return m.group(1)!.trim();
		return "";
	}

	static String _workDescription(String lineText, String flat) {
		final mLine = RegExp(
			r"DESCRIPCI[OÓ]N\s*(?:DEL\s*)?TRABAJO\s*:?\s*([\s\S]*?)(?:NOVEDADES|TAREAS\s+FUERA|MATERIALES|MANO\s+DE\s+OBRA|$)",
			caseSensitive: false,
		).firstMatch(lineText);
		if (mLine != null) {
			return _cleanDesc(mLine.group(1) ?? "");
		}
		final mFlat = RegExp(
			r"DESCRIPCI[OÓ]N\s*(?:DEL\s*)?TRABAJO\s*:?\s*(.*?)(?:NOVEDADES|MATERIALES|$)",
			caseSensitive: false,
		).firstMatch(flat);
		if (mFlat != null) return _cleanDesc(mFlat.group(1) ?? "");
		return "";
	}

	static String _cleanDesc(String s) {
		return s
				.replaceAll(RegExp(r"[ \t]+"), " ")
				.replaceAll(RegExp(r"\n{3,}"), "\n\n")
				.trim();
	}

	static String _labelValue(String flat, List<RegExp> patterns) {
		for (final p in patterns) {
			final m = p.firstMatch(flat);
			if (m != null && m.groupCount >= 1) {
				return m.group(1)!.replaceAll(RegExp(r"\s+"), " ").trim();
			}
		}
		return "";
	}
}
