import "dart:convert";
import "dart:typed_data";
import "dart:ui_web" as ui_web;

import "package:flutter/material.dart";
import "package:web/web.dart" as web;

/// Visor PDF en web: iframe con visor nativo del navegador (sin pdfx).
class WorkOrderEmbeddedPdf extends StatefulWidget {
	const WorkOrderEmbeddedPdf({super.key, required this.pdfBytes});

	final Uint8List pdfBytes;

	@override
	State<WorkOrderEmbeddedPdf> createState() => _WorkOrderEmbeddedPdfState();
}

class _WorkOrderEmbeddedPdfState extends State<WorkOrderEmbeddedPdf> {
	late final String _viewType;
	late final String _dataUrl;

	@override
	void initState() {
		super.initState();
		_viewType = "ot-pdf-${DateTime.now().microsecondsSinceEpoch}";
		_dataUrl = _buildDataUrl(widget.pdfBytes);
		ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
			final iframe = web.document.createElement("iframe") as web.HTMLIFrameElement
				..src = _dataUrl
				..style.border = "none"
				..style.width = "100%"
				..style.height = "100%"
				..setAttribute("title", "PDF Orden de trabajo");
			return iframe;
		});
	}

	@override
	Widget build(BuildContext context) {
		return HtmlElementView(viewType: _viewType);
	}
}

String _buildDataUrl(Uint8List bytes) {
	final b64 = base64Encode(bytes);
	return "data:application/pdf;base64,$b64";
}

