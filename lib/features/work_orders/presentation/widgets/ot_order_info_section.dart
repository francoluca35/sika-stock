import "package:flutter/material.dart";

import "../../domain/work_order_pdf_metadata.dart";

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

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
						_infoTile("Nº orden", nro, highlight: true),
						_infoTile("Tipo", metadata.orderType),
						_infoTile("Fecha programación", metadata.date),
						if (metadata.procedure.isNotEmpty)
							_infoTile("Procedimiento N°", metadata.procedure),
				_infoTile("Planta", metadata.plant),
				_infoTile("Sector", metadata.sector, multiline: true),
				_infoTile("Ubicación", metadata.location),
				_infoTile("Responsable", metadata.responsible),
				_infoTile("Solicitado por", metadata.requestedBy),
				_infoTile("Prioridad", metadata.priority),
				_infoTile("Tolerancia", metadata.tolerance),
				_infoTile("Quien recibe", metadata.receiver),
				if (!metadata.hasAnyData)
					Padding(
						padding: const EdgeInsets.only(top: 8),
						child: Text(
							"Algunos datos no se leyeron del PDF. Usá «Ver PDF original» arriba.",
							style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
						),
					),
			],
		);
	}

	Widget _infoTile(String label, String value, {bool multiline = false, bool highlight = false}) {
		final v = value.trim().isEmpty ? "—" : value.trim();
		return Padding(
			padding: const EdgeInsets.only(bottom: 10),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
					const SizedBox(height: 2),
					Text(
						v,
						style: TextStyle(
							fontSize: highlight ? 16 : 14,
							fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
							color: Colors.black87,
							height: 1.25,
						),
						maxLines: multiline ? 20 : 3,
						overflow: multiline ? null : TextOverflow.ellipsis,
					),
				],
			),
		);
	}
}
