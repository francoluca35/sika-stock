import "package:flutter/material.dart";

import "../../domain/work_order_pdf_metadata.dart";
import "ot_form_theme.dart";

class OtOrderInfoSection extends StatelessWidget {
	const OtOrderInfoSection({
		super.key,
		required this.metadata,
		this.otNumberFallback,
	});

	final WorkOrderPdfMetadata metadata;
	final String? otNumberFallback;

	@override
	Widget build(BuildContext context) {
		final nro = metadata.orderNumber.isNotEmpty
				? metadata.orderNumber
				: (otNumberFallback ?? "—");
		final otChip = nro != "—" ? "OT #$nro" : "OT —";

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Wrap(
					spacing: 8,
					runSpacing: 8,
					children: [
						OtFormChip(label: otChip),
						if (metadata.orderType.isNotEmpty)
							OtFormChip(
								label: metadata.orderType,
								variant: OtChipVariant.filledBlue,
							),
						if (metadata.date.isNotEmpty)
							OtFormChip(
								label: metadata.date,
								variant: OtChipVariant.filledMuted,
							),
					],
				),
				const SizedBox(height: 14),
				_infoGrid(),
				if (!metadata.hasAnyData)
					Padding(
						padding: const EdgeInsets.only(top: 10),
						child: Text(
							"Algunos datos no se leyeron del PDF. Usá «Ver PDF original» arriba.",
							style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
						),
					),
			],
		);
	}

	Widget _infoGrid() {
		final rows = <_InfoRow>[
			_InfoRow("Procedimiento", metadata.procedure),
			_InfoRow("Responsable", metadata.responsible),
			_InfoRow("Planta", metadata.plant),
			_InfoRow("Sector", metadata.sector),
			_InfoRow("Ubicación", metadata.location),
			_InfoRow("Solicitado por", metadata.requestedBy),
			_InfoRow("Prioridad", metadata.priority),
			_InfoRow("Tolerancia", metadata.tolerance),
			_InfoRow("Quien recibe", metadata.receiver),
		];

		return Column(
			children: rows.map((r) {
				final v = r.value.trim().isEmpty ? "—" : r.value.trim();
				return Padding(
					padding: const EdgeInsets.only(bottom: 10),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							SizedBox(
								width: 118,
								child: Text(r.label, style: OtFormTheme.label),
							),
							Expanded(child: Text(v, style: OtFormTheme.value)),
						],
					),
				);
			}).toList(),
		);
	}
}

class _InfoRow {
	const _InfoRow(this.label, this.value);
	final String label;
	final String value;
}
