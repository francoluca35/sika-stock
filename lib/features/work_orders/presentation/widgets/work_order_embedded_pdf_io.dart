import "dart:typed_data";

import "package:flutter/material.dart";
import "package:pdfx/pdfx.dart";

/// Visor PDF en celular: pinch-zoom, página completa.
class WorkOrderEmbeddedPdf extends StatefulWidget {
	const WorkOrderEmbeddedPdf({super.key, required this.pdfBytes});

	final Uint8List pdfBytes;

	@override
	State<WorkOrderEmbeddedPdf> createState() => _WorkOrderEmbeddedPdfState();
}

class _WorkOrderEmbeddedPdfState extends State<WorkOrderEmbeddedPdf> {
	PdfControllerPinch? _controller;
	bool _failed = false;

	@override
	void initState() {
		super.initState();
		_open();
	}

	void _open() {
		try {
			_controller = PdfControllerPinch(
				document: PdfDocument.openData(widget.pdfBytes),
			);
		} catch (_) {
			_failed = true;
		}
	}

	@override
	void dispose() {
		_controller?.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		if (_failed) {
			return const Center(
				child: Padding(
					padding: EdgeInsets.all(16),
					child: Text(
						"No se pudo mostrar el PDF en la app.\nUsá «Abrir PDF en el celular».",
						textAlign: TextAlign.center,
					),
				),
			);
		}
		final ctrl = _controller;
		if (ctrl == null) {
			return const Center(child: CircularProgressIndicator());
		}
		return PdfViewPinch(
			controller: ctrl,
			padding: 8,
		);
	}
}
