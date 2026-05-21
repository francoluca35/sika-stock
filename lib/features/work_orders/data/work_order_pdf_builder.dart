import "dart:typed_data";

import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;

import "../../../core/format/argentina_datetime.dart";
import "../domain/work_order.dart";
import "../domain/work_order_check_item.dart";
import "../domain/work_order_form_rows.dart";
import "../domain/work_order_pdf_metadata.dart";

/// PDF de cierre con datos de plantilla + lo completado por mantenimiento.
class WorkOrderPdfBuilder {
	static Future<Uint8List> buildCompletedPdf({
		required WorkOrder order,
		required WorkOrderPdfMetadata metadata,
		required String assigneeName,
		required WorkOrderFormData formData,
		required DateTime startedAt,
		required DateTime finishedAt,
		List<WorkOrderCheckItem> checklist = const [],
		Uint8List? signaturePng,
	}) async {
		final doc = pw.Document();
		final startAr = ArgentinaDateTime.formatDateOnly(startedAt);
		final endAr = ArgentinaDateTime.formatDateOnly(finishedAt);

		doc.addPage(
			pw.MultiPage(
				pageFormat: PdfPageFormat.a4,
				margin: const pw.EdgeInsets.all(36),
				build: (ctx) => [
					pw.Text(
						"ORDEN DE TRABAJO — CIERRE",
						style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
					),
					pw.SizedBox(height: 12),
					..._ro("Empresa", metadata.company),
					..._ro("Planta", metadata.plant),
					..._ro("Sector", metadata.sector),
					..._ro("Ubicación", metadata.location),
					..._ro("Tipo de orden", metadata.orderType),
					..._ro("Fecha (OT)", metadata.date),
					..._ro("Responsable", metadata.responsible),
					..._ro("Nº orden", metadata.orderNumber.isNotEmpty ? metadata.orderNumber : order.otNumber),
					..._ro("Quien recibe", metadata.receiver),
					..._ro("Tolerancia", metadata.tolerance),
					..._ro("Procedimiento", metadata.procedure),
					..._ro("Estado contador", OtCounterStates.label(formData.counterState)),
					pw.SizedBox(height: 8),
					..._ro("Fecha inicio", startAr),
					..._ro("Fecha finalización", endAr),
					..._ro("Técnico", assigneeName),
					if (checklist.isNotEmpty) ...[
						pw.SizedBox(height: 12),
						pw.Text("Checklist / procedimiento", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
						pw.SizedBox(height: 4),
						...checklist.map(
							(item) => pw.Padding(
								padding: const pw.EdgeInsets.only(bottom: 2),
								child: pw.Text(
									"${item.done ? "[x]" : "[ ]"} ${item.label}",
									style: const pw.TextStyle(fontSize: 10),
								),
							),
						),
					],
					pw.SizedBox(height: 12),
					pw.Text("Descripción del trabajo", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
					pw.SizedBox(height: 4),
					pw.Text(_block(formData.workDescription)),
					pw.SizedBox(height: 10),
					pw.Text("Novedades y tareas", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
					pw.SizedBox(height: 4),
					pw.Text(_block(formData.tasksNews)),
					pw.SizedBox(height: 10),
					pw.Text("Observaciones", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
					pw.SizedBox(height: 4),
					pw.Text(_block(formData.observations)),
					..._materialsSection(formData.materials),
					..._laborSection(formData.labor),
					if (signaturePng != null && signaturePng.isNotEmpty) ...[
						pw.SizedBox(height: 16),
						pw.Text("Firma", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
						pw.SizedBox(height: 6),
						pw.Image(pw.MemoryImage(signaturePng), width: 160, height: 64),
					],
				],
			),
		);

		return doc.save();
	}

	static List<pw.Widget> _materialsSection(List<OtMaterialRow> rows) {
		final filled = rows.where((r) => r.description.trim().isNotEmpty || r.code.trim().isNotEmpty).toList();
		if (filled.isEmpty) return [];
		return [
			pw.SizedBox(height: 12),
			pw.Text("Materiales utilizados", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
			pw.SizedBox(height: 4),
			...filled.map(
				(r) => pw.Text(
					"${r.date} · ${r.code} · ${r.quantity} ${r.unit} · ${r.description} · ${r.cost}",
					style: const pw.TextStyle(fontSize: 9),
				),
			),
		];
	}

	static List<pw.Widget> _laborSection(List<OtLaborRow> rows) {
		final filled = rows.where((r) => r.name.trim().isNotEmpty).toList();
		if (filled.isEmpty) return [];
		return [
			pw.SizedBox(height: 12),
			pw.Text("Mano de obra", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
			pw.SizedBox(height: 4),
			...filled.map(
				(r) => pw.Text(
					"${r.date} · ${r.name} · N:${r.normalHours} E:${r.extraHours} 100:${r.hours100} 200:${r.hours200}",
					style: const pw.TextStyle(fontSize: 9),
				),
			),
		];
	}

	static List<pw.Widget> _ro(String label, String? value) {
		final v = (value ?? "").trim();
		if (v.isEmpty) return [];
		return [
			pw.Padding(
				padding: const pw.EdgeInsets.only(bottom: 3),
				child: pw.RichText(
					text: pw.TextSpan(
						children: [
							pw.TextSpan(
								text: "$label: ",
								style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
							),
							pw.TextSpan(text: v, style: const pw.TextStyle(fontSize: 10)),
						],
					),
				),
			),
		];
	}

	static String _block(String s) {
		final t = s.trim();
		return t.isEmpty ? "—" : t;
	}
}
