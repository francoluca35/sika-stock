import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;

import "../../../../core/files/save_bytes_file.dart";
import "../../../../core/format/argentina_datetime.dart";
import "../../../../core/theme/app_tokens.dart";
import "../../../supervisor/data/maintenance_orders_repository.dart";
import "../../../supervisor/domain/maintenance_order.dart";
import "maintenance_order_timeline.dart";
import "maintenance_order_photo_dialog.dart";

/// Modal con el detalle completo de un pedido de mantenimiento.
Future<void> showMaintenanceOrderDetalleDialog(
	BuildContext context,
	MaintenanceOrder order, {
	int? stockCatalogoCantidad,
	required MaintenanceOrdersRepository repository,
}) async {
	var detail = order;
	String? photoUrl;
	try {
		final fresh = await repository.fetchOrderById(order.id);
		if (fresh != null) {
			detail = fresh;
		}
		photoUrl = await repository.resolveOrderPhotoUrl(detail);
	} catch (_) {
		photoUrl = detail.imagenUrl?.trim();
		if (photoUrl != null && photoUrl.isEmpty) {
			photoUrl = null;
		}
	}

	if (!context.mounted) return;

	await showDialog<void>(
		context: context,
		builder: (ctx) => _DetallePedidoDialog(
			detail: detail,
			photoUrl: photoUrl,
			stockCatalogoCantidad: stockCatalogoCantidad,
		),
	);
}

class _DetallePedidoDialog extends StatefulWidget {
	const _DetallePedidoDialog({
		required this.detail,
		required this.photoUrl,
		this.stockCatalogoCantidad,
	});

	final MaintenanceOrder detail;
	final String? photoUrl;
	final int? stockCatalogoCantidad;

	@override
	State<_DetallePedidoDialog> createState() => _DetallePedidoDialogState();
}

class _DetallePedidoDialogState extends State<_DetallePedidoDialog> {
	bool _copiando = false;
	bool _descargando = false;

	String _textoCompleto() {
		final d = widget.detail;
		final buf = StringBuffer()
			..writeln("Detalle del pedido")
			..writeln(d.numeroOrden)
			..writeln()
			..writeln("Fecha: ${ArgentinaDateTime.formatDateTime(d.fechaPedido)}")
			..writeln("Producto: ${d.producto}")
			..writeln("Cantidad: ${d.quantity} u.")
			..writeln("Tipo: ${d.productType}")
			..writeln("Prioridad: ${d.priority}")
			..writeln("Destino: ${d.destination}");
		if (d.observacion.trim().isNotEmpty) {
			buf.writeln("Observación: ${d.observacion.trim()}");
		}
		if (d.cancellationObservacion.trim().isNotEmpty) {
			buf.writeln("Motivo de anulación: ${d.cancellationObservacion.trim()}");
		}
		buf
			..writeln("Solicitante: ${d.solicitante}")
			..writeln("Estado: ${_workflowLabel(d.workflowStatus)}")
			..writeln()
			..writeln("Línea de tiempo:");
		for (final step in buildMaintenanceTimelineSteps(d)) {
			final ts = step.timestamp?.trim();
			final line = ts != null && ts.isNotEmpty
					? "· ${step.label}: ${step.subtitle} ($ts)"
					: "· ${step.label}: ${step.subtitle}";
			buf.writeln(line);
		}
		if (widget.stockCatalogoCantidad != null) {
			final n = widget.stockCatalogoCantidad!;
			buf.writeln(
				n > 0
						? "Stock en catálogo (aprox.): $n u. disponibles"
						: "Stock en catálogo (aprox.): Sin coincidencia en inventario digital",
			);
		}
		final resumen = d.motivo.trim();
		if (resumen.isNotEmpty) {
			buf.writeln("Resumen: $resumen");
		}
		return buf.toString().trim();
	}

	Future<void> _copiarTexto() async {
		if (_copiando) return;
		setState(() => _copiando = true);
		try {
			await Clipboard.setData(ClipboardData(text: _textoCompleto()));
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Detalle copiado al portapapeles")),
			);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo copiar: $e")),
			);
		} finally {
			if (mounted) setState(() => _copiando = false);
		}
	}

	({String mime, String ext}) _mimeDesdeUrl(String url) {
		final lower = url.toLowerCase();
		if (lower.contains(".png")) return (mime: "image/png", ext: "png");
		if (lower.contains(".webp")) return (mime: "image/webp", ext: "webp");
		if (lower.contains(".gif")) return (mime: "image/gif", ext: "gif");
		return (mime: "image/jpeg", ext: "jpg");
	}

	Future<void> _descargarImagen() async {
		final foto = widget.photoUrl?.trim();
		if (foto == null || foto.isEmpty || _descargando) return;
		setState(() => _descargando = true);
		try {
			final res = await http.get(Uri.parse(foto));
			if (res.statusCode < 200 || res.statusCode >= 300) {
				throw StateError("HTTP ${res.statusCode}");
			}
			final info = _mimeDesdeUrl(foto);
			final name = "${widget.detail.numeroOrden}-foto.${info.ext}";
			await saveBytesToDevice(
				bytes: res.bodyBytes,
				filename: name,
				mimeType: info.mime,
			);
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						kIsWeb ? "Descarga iniciada: $name" : "Imagen guardada: $name",
					),
				),
			);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo descargar la imagen: $e")),
			);
		} finally {
			if (mounted) setState(() => _descargando = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final detail = widget.detail;
		final photoUrl = widget.photoUrl;
		final stockCatalogoCantidad = widget.stockCatalogoCantidad;

		return AlertDialog(
			title: Row(
				children: [
					const Expanded(
						child: Text("Detalle del pedido"),
					),
					IconButton(
						tooltip: "Copiar detalle",
						onPressed: _copiando ? null : _copiarTexto,
						icon: _copiando
								? const SizedBox(
										width: 22,
										height: 22,
										child: CircularProgressIndicator(strokeWidth: 2),
									)
								: const Icon(Icons.copy_all_outlined),
					),
				],
			),
			content: SingleChildScrollView(
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					mainAxisSize: MainAxisSize.min,
					children: [
						Text(
							detail.numeroOrden,
							style: const TextStyle(
								fontWeight: FontWeight.w800,
								fontSize: 16,
								letterSpacing: 0.3,
							),
						),
						const SizedBox(height: 14),
						_DetalleFila(
							label: "Fecha",
							valor: ArgentinaDateTime.formatDateTime(detail.fechaPedido),
						),
						_DetalleFila(label: "Producto", valor: detail.producto),
						_DetalleFila(label: "Cantidad", valor: "${detail.quantity} u."),
						_DetalleFila(label: "Tipo", valor: detail.productType),
						_DetalleFila(label: "Prioridad", valor: detail.priority),
						_DetalleFila(label: "Destino", valor: detail.destination),
						if (detail.observacion.trim().isNotEmpty)
							_DetalleFila(label: "Observación", valor: detail.observacion),
						if (detail.cancellationObservacion.trim().isNotEmpty)
							_DetalleFila(
								label: "Motivo de anulación",
								valor: detail.cancellationObservacion,
							),
						_DetalleFila(label: "Solicitante", valor: detail.solicitante),
						_DetalleFila(
							label: "Estado",
							valor: _workflowLabel(detail.workflowStatus),
						),
						const SizedBox(height: 12),
						const Text(
							"Línea de tiempo",
							style: TextStyle(
								fontWeight: FontWeight.w800,
								fontSize: 13,
							),
						),
						const SizedBox(height: 8),
						MaintenanceOrderTimeline(order: detail, compact: true),
						if (stockCatalogoCantidad != null)
							_DetalleFila(
								label: "Stock en catálogo (aprox.)",
								valor: stockCatalogoCantidad > 0
										? "$stockCatalogoCantidad u. disponibles"
										: "Sin coincidencia en inventario digital",
							),
						_DetalleFila(label: "Resumen", valor: detail.motivo),
						if (photoUrl != null && photoUrl.isNotEmpty) ...[
							const SizedBox(height: 4),
							Text(
								"Imagen adjunta",
								style: TextStyle(
									fontSize: 11,
									fontWeight: FontWeight.w700,
									color: Colors.grey.shade700,
									letterSpacing: 0.2,
								),
							),
							const SizedBox(height: 6),
							ClipRRect(
								borderRadius: BorderRadius.circular(AppTokens.radiusMd),
								child: MaintenanceOrderPhotoView(
									imageUrl: photoUrl,
									height: 140,
									fit: BoxFit.cover,
								),
							),
							const SizedBox(height: 8),
							Wrap(
								spacing: 8,
								runSpacing: 8,
								children: [
									OutlinedButton.icon(
										onPressed: () {
											showMaintenanceOrderPhotoDialog(
												context,
												photoUrl,
												title: "Foto del pedido · ${detail.numeroOrden}",
											);
										},
										icon: const Icon(Icons.image_outlined, size: 20),
										label: const Text(
											"VER IMAGEN",
											style: TextStyle(fontWeight: FontWeight.w700),
										),
									),
									OutlinedButton.icon(
										onPressed: _descargando ? null : _descargarImagen,
										icon: _descargando
												? const SizedBox(
														width: 18,
														height: 18,
														child: CircularProgressIndicator(strokeWidth: 2),
													)
												: const Icon(Icons.download_outlined, size: 20),
										label: const Text(
											"DESCARGAR IMAGEN",
											style: TextStyle(fontWeight: FontWeight.w700),
										),
									),
								],
							),
						],
					],
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(context),
					child: const Text("Cerrar"),
				),
			],
		);
	}
}

String _workflowLabel(MaintenanceWorkflowStatus w) {
	switch (w) {
		case MaintenanceWorkflowStatus.pendingSupervisor:
			return "Pendiente de supervisor";
		case MaintenanceWorkflowStatus.supervisorStockOk:
			return "Stock confirmado por supervisor";
		case MaintenanceWorkflowStatus.forwardedToPanol:
			return "Derivado a pañol";
		case MaintenanceWorkflowStatus.panolRequestedCompras:
			return "Pedido a compras (pañol)";
		case MaintenanceWorkflowStatus.comprasOcNotified:
		case MaintenanceWorkflowStatus.comprasPurchaseDone:
			return "Pedido a compras (en gestión)";
		case MaintenanceWorkflowStatus.comprasArrivedNotified:
			return "Listo para retirar";
		case MaintenanceWorkflowStatus.completed:
			return "Completado";
		case MaintenanceWorkflowStatus.cancelled:
			return "Cancelado";
	}
}

class _DetalleFila extends StatelessWidget {
	const _DetalleFila({required this.label, required this.valor});

	final String label;
	final String valor;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 10),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						label,
						style: TextStyle(
							fontSize: 11,
							fontWeight: FontWeight.w700,
							color: Colors.grey.shade700,
							letterSpacing: 0.2,
						),
					),
					const SizedBox(height: 2),
					Text(
						valor.trim().isEmpty ? "—" : valor,
						style: const TextStyle(
							fontSize: 14,
							height: 1.35,
							color: Colors.black87,
						),
					),
				],
			),
		);
	}
}
