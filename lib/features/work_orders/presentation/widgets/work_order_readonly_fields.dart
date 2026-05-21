import "package:flutter/material.dart";

import "../../domain/work_order_pdf_metadata.dart";

class WorkOrderReadonlyFields extends StatelessWidget {
	const WorkOrderReadonlyFields({
		super.key,
		required this.metadata,
		this.receiverName,
	});

	final WorkOrderPdfMetadata metadata;
	final String? receiverName;

	@override
	Widget build(BuildContext context) {
		final m = metadata.withReceiver(receiverName ?? metadata.receiver);

		return Card(
			child: Padding(
				padding: const EdgeInsets.all(14),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Row(
							children: [
								Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade700),
								const SizedBox(width: 6),
								Text(
									"Datos de la OT (solo lectura)",
									style: TextStyle(
										fontWeight: FontWeight.bold,
										color: Colors.grey.shade800,
									),
								),
							],
						),
						const SizedBox(height: 10),
						_ro("Empresa", m.company),
						_ro("Planta", m.plant),
						_ro("Sector", m.sector, multiline: true),
						_ro("Ubicación", m.location),
						_ro("Tipo de orden", m.orderType),
						if (m.date.isNotEmpty) _ro("Fecha programación", m.date),
						_ro("Responsable", m.responsible),
						_ro("Nº orden", m.orderNumber),
						_ro("Quien recibe", m.receiver),
						_ro("Tolerancia", m.tolerance),
						if (m.workDescription.isNotEmpty) ...[
							const SizedBox(height: 8),
							_ro("Descripción del trabajo (PDF)", m.workDescription, multiline: true),
						],
						if (!m.hasAnyData)
							Padding(
								padding: const EdgeInsets.only(top: 8),
								child: Text(
									"No se pudieron leer todos los campos. Usá «VER PDF» o pedí al admin que vuelva a subir la OT.",
									style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
								),
							),
					],
				),
			),
		);
	}

	Widget _ro(String label, String value, {bool multiline = false}) {
		final v = value.trim().isEmpty ? "—" : value.trim();
		return Padding(
			padding: const EdgeInsets.only(bottom: 6),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
					Text(
						v,
						style: TextStyle(
							fontSize: 14,
							fontWeight: FontWeight.w600,
							color: Colors.grey.shade900,
						),
						maxLines: multiline ? 12 : 2,
						overflow: multiline ? null : TextOverflow.ellipsis,
					),
				],
			),
		);
	}
}
