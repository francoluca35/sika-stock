import "dart:typed_data";

import "package:image/image.dart" as img;
import "package:pdf/pdf.dart";
import "package:pdf/widgets.dart" as pw;
import "package:pdfx/pdfx.dart" as pdfx;

import "../domain/work_order_pdf_annotation.dart";

/// Fusiona la plantilla PDF oficial con anotaciones (texto, tilde, firma).
class WorkOrderPdfFlattener {
	static Future<Uint8List> flatten({
		required Uint8List originalPdfBytes,
		required List<WorkOrderPdfAnnotation> annotations,
		Uint8List? signaturePng,
	}) async {
		final doc = await pdfx.PdfDocument.openData(originalPdfBytes);
		final out = pw.Document();
		try {
			for (var pageNum = 1; pageNum <= doc.pagesCount; pageNum++) {
				final page = await doc.getPage(pageNum);
				final renderW = (page.width * 2).roundToDouble();
				final renderH = (page.height * 2).roundToDouble();
				final rendered = await page.render(
					width: renderW,
					height: renderH,
					format: pdfx.PdfPageImageFormat.png,
					backgroundColor: "#FFFFFF",
				);
				await page.close();
				if (rendered == null) continue;

				final decoded = img.decodePng(rendered.bytes);
				if (decoded == null) continue;

				var bitmap = decoded;
				final pageIndex = pageNum - 1;
				for (final a in annotations.where((e) => e.pageIndex == pageIndex)) {
					bitmap = _paintAnnotation(
						bitmap,
						a,
						signaturePng: a.type == "signature" ? signaturePng : null,
					);
				}

				final pageW = bitmap.width.toDouble();
				final pageH = bitmap.height.toDouble();
				final jpg = img.encodeJpg(bitmap, quality: 94);
				out.addPage(
					pw.Page(
						pageFormat: PdfPageFormat(pageW, pageH),
						margin: pw.EdgeInsets.zero,
						build: (_) => pw.Image(
							pw.MemoryImage(jpg),
							width: pageW,
							height: pageH,
							fit: pw.BoxFit.fill,
						),
					),
				);
			}
		} finally {
			await doc.close();
		}
		return out.save();
	}

	static img.Image _paintAnnotation(
		img.Image base,
		WorkOrderPdfAnnotation a, {
		Uint8List? signaturePng,
	}) {
		final px = (a.x * base.width).round().clamp(0, base.width - 1);
		final py = (a.y * base.height).round().clamp(0, base.height - 1);

		switch (a.type) {
			case "check":
				img.drawString(
					base,
					"X",
					font: img.arial48,
					x: px,
					y: py,
					color: img.ColorRgb8(0, 100, 0),
				);
				return base;
			case "signature":
				if (signaturePng == null || signaturePng.isEmpty) return base;
				final sig = img.decodePng(signaturePng);
				if (sig == null) return base;
				final tw = (a.width * base.width).round().clamp(40, base.width);
				final th = (a.height * base.height).round().clamp(20, base.height);
				final resized = img.copyResize(sig, width: tw, height: th);
				img.compositeImage(base, resized, dstX: px, dstY: py);
				return base;
			case "text":
			default:
				final text = (a.text ?? "").trim();
				if (text.isEmpty) return base;
				img.drawString(
					base,
					text,
					font: img.arial24,
					x: px,
					y: py,
					color: img.ColorRgb8(0, 0, 0),
				);
				return base;
		}
	}
}
