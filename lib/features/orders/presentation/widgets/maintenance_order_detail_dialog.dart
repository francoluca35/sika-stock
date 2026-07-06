import "package:flutter/material.dart";

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

	showDialog<void>(
		context: context,
		builder: (ctx) => AlertDialog(
			title: const Text("Detalle del pedido"),
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
							OutlinedButton.icon(
								onPressed: () {
									showMaintenanceOrderPhotoDialog(
										ctx,
										photoUrl!,
										title: "Foto del pedido · ${detail.numeroOrden}",
									);
								},
								icon: const Icon(Icons.image_outlined, size: 20),
								label: const Text(
									"VER IMAGEN",
									style: TextStyle(fontWeight: FontWeight.w700),
								),
							),
						],
					],
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(ctx),
					child: const Text("Cerrar"),
				),
			],
		),
	);
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
