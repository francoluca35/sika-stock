import "dart:typed_data";

import "package:flutter/material.dart";

import "work_order_embedded_pdf.dart";

/// Contenedor del visor PDF (altura fija en listas, pantalla completa si no hay límite).
class WorkOrderPdfPanel extends StatelessWidget {
	const WorkOrderPdfPanel({
		super.key,
		required this.pdfBytes,
		this.height = 320,
	});

	final Uint8List pdfBytes;
	final double height;

	@override
	Widget build(BuildContext context) {
		if (pdfBytes.isEmpty) {
			return SizedBox(
				height: height.isFinite ? height : 200,
				child: const Center(child: Text("PDF no disponible")),
			);
		}
		final viewer = WorkOrderEmbeddedPdf(
			key: ValueKey("pdf-${pdfBytes.length}-${pdfBytes.hashCode}"),
			pdfBytes: Uint8List.fromList(pdfBytes),
		);
		if (!height.isFinite) {
			return viewer;
		}
		return SizedBox(
			height: height,
			width: double.infinity,
			child: viewer,
		);
	}
}
