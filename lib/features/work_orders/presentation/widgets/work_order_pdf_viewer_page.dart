import "dart:typed_data";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";
import "work_order_embedded_pdf.dart";
import "work_order_pdf_open.dart" show openPdfExternally, openPdfInBrowserTab;

/// Pantalla para leer el PDF (optimizada para celular).
class WorkOrderPdfViewerPage extends StatefulWidget {
	const WorkOrderPdfViewerPage({
		super.key,
		required this.pdfBytes,
		this.otNumber,
	});

	final Uint8List pdfBytes;
	final String? otNumber;

	@override
	State<WorkOrderPdfViewerPage> createState() => _WorkOrderPdfViewerPageState();
}

class _WorkOrderPdfViewerPageState extends State<WorkOrderPdfViewerPage> {
	late final Uint8List _bytes;

	@override
	void initState() {
		super.initState();
		_bytes = Uint8List.fromList(widget.pdfBytes);
	}

	Future<void> _openExternal() async {
		final ok = await openPdfExternally(_bytes, otNumber: widget.otNumber);
		if (!mounted) return;
		if (!ok) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text("Instalá un visor de PDF (Google PDF, Adobe, etc.)"),
				),
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		final isMobile = !kIsWeb;

		return Scaffold(
			backgroundColor: Colors.grey.shade200,
			appBar: AppBar(
				backgroundColor: AppTokens.yellowHeader,
				foregroundColor: Colors.black87,
				title: Text(
					isMobile ? "PDF — OT" : "PDF — Orden de trabajo",
					style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
				),
				actions: [
					if (kIsWeb)
						IconButton(
							tooltip: "Abrir en pestaña nueva",
							icon: const Icon(Icons.open_in_new),
							onPressed: () => openPdfInBrowserTab(_bytes),
						),
				],
			),
			body: Column(
				children: [
					if (isMobile)
						Material(
							color: Colors.white,
							elevation: 2,
							child: Padding(
								padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
								child: SizedBox(
									width: double.infinity,
									child: FilledButton.icon(
										onPressed: _openExternal,
										icon: const Icon(Icons.phone_android),
										label: const Text(
											"ABRIR PDF EN EL CELULAR",
											style: TextStyle(fontWeight: FontWeight.bold),
										),
										style: FilledButton.styleFrom(
											backgroundColor: AppTokens.redAction,
											padding: const EdgeInsets.symmetric(vertical: 14),
										),
									),
								),
							),
						),
					Expanded(
						child: SafeArea(
							top: !isMobile,
							child: WorkOrderEmbeddedPdf(
								key: ValueKey("pdf-view-${_bytes.hashCode}"),
								pdfBytes: _bytes,
							),
						),
					),
				],
			),
		);
	}
}

void openWorkOrderPdfViewer(
	BuildContext context,
	Uint8List pdfBytes, {
	String? otNumber,
}) {
	Navigator.of(context).push(
		MaterialPageRoute<void>(
			builder: (_) => WorkOrderPdfViewerPage(
				key: UniqueKey(),
				pdfBytes: pdfBytes,
				otNumber: otNumber,
			),
		),
	);
}
