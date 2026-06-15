import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";
import "ot_form_theme.dart";

/// Descripción del PDF: título + bullets (estilo mock).
class OtWorkDescriptionPanel extends StatelessWidget {
	const OtWorkDescriptionPanel({
		super.key,
		required this.fullText,
		this.checklistLabels = const [],
	});

	final String fullText;
	final List<String> checklistLabels;

	@override
	Widget build(BuildContext context) {
		final parsed = _parse(fullText);
		final bullets = checklistLabels.isNotEmpty ? checklistLabels : parsed.bullets;

		if (parsed.summary.isEmpty && bullets.isEmpty) {
			return Text(
				"No hay descripción en el PDF.",
				style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
			);
		}

		return OtInnerPanel(
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					if (parsed.summary.isNotEmpty)
						RichText(
							text: TextSpan(
								style: OtFormTheme.body,
								children: _highlightDays(parsed.summary),
							),
						),
					if (bullets.isNotEmpty) ...[
						if (parsed.summary.isNotEmpty) const SizedBox(height: 12),
						...bullets.map(
							(line) => Padding(
								padding: const EdgeInsets.only(bottom: 8),
								child: Row(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text(
											"•",
											style: TextStyle(
												fontSize: 18,
												fontWeight: FontWeight.bold,
												color: AppTokens.redAction,
												height: 1.2,
											),
										),
										const SizedBox(width: 8),
										Expanded(child: Text(line, style: OtFormTheme.body)),
									],
								),
							),
						),
					],
				],
			),
		);
	}

	static List<TextSpan> _highlightDays(String text) {
		final m = RegExp(r"\((\d+\s*d[ií]as?)\)", caseSensitive: false).firstMatch(text);
		if (m == null) {
			return [TextSpan(text: text)];
		}
		final before = text.substring(0, m.start);
		final days = m.group(1)!;
		final after = text.substring(m.end);
		return [
			if (before.isNotEmpty) TextSpan(text: before),
			TextSpan(
				text: "($days)",
				style: const TextStyle(
					fontWeight: FontWeight.w800,
					color: AppTokens.redAction,
				),
			),
			if (after.isNotEmpty) TextSpan(text: after),
		];
	}

	static _ParsedDesc _parse(String text) {
		final lines = text
				.split(RegExp(r"[\r\n]+"))
				.map((l) => l.trim())
				.where((l) => l.isNotEmpty)
				.toList();
		if (lines.isEmpty) return const _ParsedDesc("", []);

		final bullets = <String>[];
		final summaryParts = <String>[];

		for (final line in lines) {
			final b = RegExp(r"^[\-\u2022–]\s*(.+)$").firstMatch(line);
			if (b != null) {
				bullets.add(b.group(1)!.trim());
			} else if (line.startsWith("-") && line.length > 2) {
				bullets.add(line.substring(1).trim());
			} else {
				summaryParts.add(line);
			}
		}

		return _ParsedDesc(summaryParts.join(" "), bullets);
	}
}

class _ParsedDesc {
	const _ParsedDesc(this.summary, this.bullets);
	final String summary;
	final List<String> bullets;
}
