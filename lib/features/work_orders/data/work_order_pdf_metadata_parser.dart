import "dart:typed_data";

import "../domain/work_order_pdf_metadata.dart";
import "work_order_pdf_text_extractor_service.dart";

/// Parser plantilla OT Sika (ORDEN DE TRABAJO N°, PLANTA_VIRREY, tabla superior, etc.).
class WorkOrderPdfMetadataParser {
	static WorkOrderPdfMetadata parseFromPdfBytes(List<int> bytes) {
		final raw = WorkOrderPdfTextExtractorService.extractLines(
			Uint8List.fromList(bytes),
		);
		final normalized = _normalizeLabelBreaks(raw);
		final flat = normalized.replaceAll(RegExp(r"[ \t]+"), " ").replaceAll(RegExp(r"\n+"), " ").trim();
		return parseFromText(normalized, flat);
	}

	/// Inserta saltos de línea antes de etiquetas cuando el PDF viene en una sola línea.
	static String _normalizeLabelBreaks(String text) {
		const labels = [
			"ORDEN DE TRABAJO",
			"Fecha Programación",
			"Fecha Programacion",
			"Procedimiento N°",
			"Procedimiento N",
			"Procedimiento",
			"Responsable",
			"Tipo",
			"Solicitado",
			"Prioridad",
			"Recibe",
			"Ubicación",
			"Ubicacion",
			"Tolerancia",
			"Descripción del Trabajo",
			"Descripcion del Trabajo",
			"NOVEDADES",
			"MATERIALES",
			"MANO DE OBRA",
		];
		var s = text;
		for (final label in labels) {
			s = s.replaceAllMapped(
				RegExp("(?<![\\n\\r])$label", caseSensitive: false),
				(m) => "\n${m.group(0)}",
			);
		}
		// Separar bloque izquierdo (líneas sueltas tras SIKA / PLANTA)
		s = s.replaceAllMapped(
			RegExp(r"(PLANTA[_\s-]*VIRREY)", caseSensitive: false),
			(m) => "\n${m.group(1)}",
		);
		s = s.replaceAllMapped(
			RegExp(r"(SIKA\s+S\.?\s*A\.?\s*I\.?\s*C\.?)", caseSensitive: false),
			(m) => "\n${m.group(1)}",
		);
		return s;
	}

	static WorkOrderPdfMetadata parseFromText(String lineText, [String? flatText]) {
		final flat = flatText ?? lineText.replaceAll(RegExp(r"\s+"), " ").trim();
		final lines = _lines(lineText);
		final upperFlat = flat.toUpperCase();

		final procedureNum = _procedureNumber(lines, flat);
		final workDesc = _workDescription(lineText, flat);
		final steps = _procedureStepsFromDescription(workDesc, lineText, procedureNum);

		return WorkOrderPdfMetadata(
			company: _company(flat, upperFlat, lines),
			plant: _plant(lines, flat),
			sector: _sector(lines),
			location: _labelFromLines(lines, flat, [
				RegExp(r"UBICACI[OÓ]N\s*:?\s*([^\n:]+?)(?=\s+TOLERANCIA|\s+DESCRIPCI|$)", caseSensitive: false),
				RegExp(r"UBICACI[OÓ]N\s*:?\s*(\S+)", caseSensitive: false),
			]),
			orderType: _labelFromLines(lines, flat, [
				RegExp(r"(?<!DE\s)TIPO\s*:?\s*([A-ZÁÉÍÓÚÑ]+)", caseSensitive: false),
			]),
			date: _labelFromLines(lines, flat, [
				RegExp(
					r"FECHA\s*PROGRAMACI[OÓ]N\s*:?\s*([0-9]{1,2}[/.\-][0-9]{1,2}[/.\-][0-9]{2,4})",
					caseSensitive: false,
				),
				RegExp(r"FECHA\s*:?\s*([0-9]{1,2}[/.\-][0-9]{1,2}[/.\-][0-9]{2,4})", caseSensitive: false),
			]),
			responsible: _labelFromLines(lines, flat, [
				RegExp(
					r"RESPONSABLE\s*:?\s*([^:\n]+?)(?=\s+TIPO|\s+SOLICITADO|\s+RECIBE|\s+UBICACI|\s+DESCRIPCI|$)",
					caseSensitive: false,
				),
			]),
			orderNumber: _orderNumber(flat, upperFlat, lines),
			receiver: _labelFromLines(lines, flat, [
				RegExp(r"RECIBE\s*:?\s*([^:\n]+?)(?=\s+UBICACI|\s+DESCRIPCI|$)", caseSensitive: false),
			]),
			tolerance: _labelFromLines(lines, flat, [
				RegExp(
					r"TOLERANCIA\s*:?\s*([0-9]{1,2}[/.\-][0-9]{1,2}[/.\-][0-9]{2,4}|[A-ZÁÉÍÓÚÑ0-9\s\-]+?)(?=\s+DESCRIPCI|$)",
					caseSensitive: false,
				),
			]),
			workDescription: workDesc,
			procedure: procedureNum,
			requestedBy: _labelFromLines(lines, flat, [
				RegExp(r"SOLICITADO\s*:?\s*([^:\n]*?)(?=\s+PRIORIDAD|\s+RECIBE|\s+UBICACI|$)", caseSensitive: false),
				RegExp(r"SOLICITADO\s+POR\s*:?\s*([^:\n]+?)(?=\s+PRIORIDAD|$)", caseSensitive: false),
			]),
			priority: _labelFromLines(lines, flat, [
				RegExp(r"PRIORIDAD\s*:?\s*([A-ZÁÉÍÓÚÑ0-9]+)", caseSensitive: false),
			]),
			procedureSteps: steps,
		);
	}

	static List<String> _lines(String text) {
		return text
				.split(RegExp(r"[\r\n]+"))
				.map((l) => l.trim())
				.where((l) => l.isNotEmpty)
				.toList();
	}

	static String _labelFromLines(List<String> lines, String flat, List<RegExp> patterns) {
		for (final line in lines) {
			for (final p in patterns) {
				final m = p.firstMatch(line);
				if (m != null && m.groupCount >= 1) {
					final v = m.group(1)!.trim();
					if (v.isNotEmpty) return v;
				}
			}
		}
		for (final p in patterns) {
			final m = p.firstMatch(flat);
			if (m != null && m.groupCount >= 1) {
				return m.group(1)!.replaceAll(RegExp(r"\s+"), " ").trim();
			}
		}
		return "";
	}

	static String _company(String flat, String upper, List<String> lines) {
		for (final line in lines) {
			if (RegExp(r"SIKA\s+S", caseSensitive: false).hasMatch(line)) {
				return "SIKA S.A.I.C";
			}
		}
		if (RegExp(r"SIKA\s+S\.?\s*A\.?\s*I\.?\s*C\.?", caseSensitive: false).hasMatch(flat)) {
			return "SIKA S.A.I.C";
		}
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
		if (RegExp(r"PLANTA[_\s-]*VIRREY", caseSensitive: false).hasMatch(flat)) {
			return "PLANTA_VIRREY";
		}
		return "";
	}

	static String _sector(List<String> lines) {
		final stop = RegExp(
			r"^(FECHA|Fecha|RESPONSABLE|Procedimiento|PROCEDIMIENTO|TIPO\s|Solicitado|SOLICITADO|PRIORIDAD|RECIBE|UBICACI|TOLERANCIA|DESCRIPCI|ORDEN\s+DE|0200\d+|NOVEDAD|MATERIALES|MANO\s+DE)",
			caseSensitive: false,
		);
		var plantIdx = -1;
		var sikaIdx = -1;
		for (var i = 0; i < lines.length; i++) {
			if (sikaIdx < 0 && RegExp(r"SIKA\s", caseSensitive: false).hasMatch(lines[i])) {
				sikaIdx = i;
			}
			if (plantIdx < 0 && RegExp(r"PLANTA[_\s]", caseSensitive: false).hasMatch(lines[i])) {
				plantIdx = i;
			}
		}

		final start = plantIdx >= 0 ? plantIdx + 1 : (sikaIdx >= 0 ? sikaIdx + 1 : -1);
		if (start < 0) return "";

		final parts = <String>[];
		for (var i = start; i < lines.length; i++) {
			final line = lines[i];
			if (stop.hasMatch(line)) break;
			if (RegExp(r"^SIKA\s", caseSensitive: false).hasMatch(line)) continue;
			if (RegExp(r"^PLANTA[_\s]", caseSensitive: false).hasMatch(line)) continue;
			if (RegExp(r"^\d{7,}$").hasMatch(line)) continue;
			parts.add(line);
		}
		return parts.join("\n");
	}

	static String _orderNumber(String flat, String upper, List<String> lines) {
		final patterns = [
			RegExp(
				r"ORDEN\s+DE\s+TRABAJO\s+N[°ºo\.#]*\s*(\d{3,6})",
				caseSensitive: false,
			),
			RegExp(r"ORDEN\s+DE\s+TRABAJO\s+N[°ºo\.#]*(\d{3,6})", caseSensitive: false),
		];
		for (final line in lines) {
			for (final p in patterns) {
				final m = p.firstMatch(line);
				if (m != null) return m.group(1)!.trim();
			}
		}
		for (final p in patterns) {
			final m = p.firstMatch(flat);
			if (m != null) return m.group(1)!.trim();
		}
		final m = RegExp(r"OT-?\s*(\d{3,6})", caseSensitive: false).firstMatch(flat);
		if (m != null) return m.group(1)!.trim();
		return "";
	}

	static String _procedureNumber(List<String> lines, String flat) {
		final patterns = [
			RegExp(
				r"PROCEDIMIENTO\s*N[°ºo\.#]*\s*:?\s*(\d+\s*v?\s*\d*)",
				caseSensitive: false,
			),
			RegExp(r"PROCEDIMIENTO\s*:?\s*(\d+\s*v?\s*\d*)", caseSensitive: false),
		];
		for (final line in lines) {
			for (final p in patterns) {
				final m = p.firstMatch(line);
				if (m != null) return m.group(1)!.trim();
			}
		}
		for (final p in patterns) {
			final m = p.firstMatch(flat);
			if (m != null) return m.group(1)!.trim();
		}
		return "";
	}

	static String _workDescription(String lineText, String flat) {
		final mLine = RegExp(
			r"DESCRIPCI[OÓ]N\s*(?:DEL\s*)?TRABAJO\s*:?\s*([\s\S]*?)(?:NOVEDADES|TAREAS\s+FUERA|MATERIALES|MANO\s+DE\s+OBRA|FECHA\s+INICIO|$)",
			caseSensitive: false,
		).firstMatch(lineText);
		if (mLine != null) {
			return _cleanDesc(mLine.group(1) ?? "");
		}
		final mFlat = RegExp(
			r"DESCRIPCI[OÓ]N\s*(?:DEL\s*)?TRABAJO\s*:?\s*(.*?)(?:NOVEDADES|MATERIALES|MANO\s+DE\s+OBRA|$)",
			caseSensitive: false,
		).firstMatch(flat);
		if (mFlat != null) return _cleanDesc(mFlat.group(1) ?? "");
		return "";
	}

	static List<String> _procedureStepsFromDescription(
		String workDesc,
		String lineText,
		String procedureNum,
	) {
		final steps = <String>[];

		for (final line in workDesc.split(RegExp(r"[\r\n]+"))) {
			final t = line.trim();
			if (t.isEmpty) continue;
			final bullet = RegExp(r"^[\-\u2022–]\s*(.+)$").firstMatch(t);
			if (bullet != null) {
				steps.add(bullet.group(1)!.trim());
				continue;
			}
			if (t.startsWith("-") && t.length > 2) {
				steps.add(t.substring(1).trim());
			}
		}

		if (steps.isEmpty) {
			for (final line in _lines(lineText)) {
				final t = line.trim();
				final bullet = RegExp(r"^[\-\u2022–]\s*(.+)$").firstMatch(t);
				if (bullet != null) {
					steps.add(bullet.group(1)!.trim());
				} else if (t.startsWith("-") && t.length > 3) {
					steps.add(t.substring(1).trim());
				}
			}
		}

		if (steps.isEmpty && workDesc.isNotEmpty) {
			final lines = workDesc.split(RegExp(r"[\r\n]+")).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
			if (lines.length > 1) {
				steps.addAll(lines.skip(1));
			} else if (lines.isNotEmpty) {
				steps.add(lines.first);
			}
		}

		if (procedureNum.isNotEmpty && steps.isEmpty) {
			steps.add("Ejecutar procedimiento $procedureNum");
		}

		return steps.take(40).toList();
	}

	static String _cleanDesc(String s) {
		return s
				.replaceAll(RegExp(r"[ \t]+"), " ")
				.replaceAll(RegExp(r"\n{3,}"), "\n\n")
				.trim();
	}
}
