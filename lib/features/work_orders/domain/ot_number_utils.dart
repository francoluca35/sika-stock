/// Normaliza códigos de barras / OT (ej. `02004783` → `4783`).
abstract final class OtNumberUtils {
	/// Variantes para comparar contra `ot_number` o metadata.
	static List<String> normalizeCandidates(String raw) {
		final trimmed = raw.trim();
		if (trimmed.isEmpty) return [];

		final set = <String>{trimmed};

		final digitsOnly = trimmed.replaceAll(RegExp(r"\D"), "");
		if (digitsOnly.isNotEmpty) {
			set.add(digitsOnly);
			final noLeadingZeros = digitsOnly.replaceFirst(RegExp(r"^0+"), "");
			if (noLeadingZeros.isNotEmpty) {
				set.add(noLeadingZeros);
			}
			// Código EAN del PDF Sika: prefijo 02 + número OT rellenado.
			if (digitsOnly.length >= 6 && digitsOnly.startsWith("02")) {
				final tail = digitsOnly.substring(2).replaceFirst(RegExp(r"^0+"), "");
				if (tail.isNotEmpty) set.add(tail);
			}
		}

		final otMatch = RegExp(r"OT[-\s#]*(\d+)", caseSensitive: false).firstMatch(trimmed);
		if (otMatch != null) {
			final n = otMatch.group(1)!;
			set.add(n);
			final stripped = n.replaceFirst(RegExp(r"^0+"), "");
			if (stripped.isNotEmpty) set.add(stripped);
		}

		return set.where((s) => s.isNotEmpty).toList();
	}

	static bool matchesStored(String stored, String candidate) {
		final a = normalizeCandidates(stored);
		final b = normalizeCandidates(candidate);
		if (a.isEmpty || b.isEmpty) return false;
		for (final x in a) {
			for (final y in b) {
				if (x == y) return true;
			}
		}
		return false;
	}

	static bool workOrderMatches(WorkOrderOtFields wo, String raw) {
		final candidates = normalizeCandidates(raw);
		if (candidates.isEmpty) return false;
		for (final c in candidates) {
			if (wo.otNumber != null && matchesStored(wo.otNumber!, c)) return true;
			if (wo.pdfOrderNumber.isNotEmpty && matchesStored(wo.pdfOrderNumber, c)) {
				return true;
			}
		}
		return false;
	}
}

/// Campos mínimos para comparar número de OT.
class WorkOrderOtFields {
	const WorkOrderOtFields({this.otNumber, this.pdfOrderNumber = ""});

	final String? otNumber;
	final String pdfOrderNumber;
}
