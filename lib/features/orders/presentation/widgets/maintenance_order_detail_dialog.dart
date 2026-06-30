import "package:flutter/material.dart";

import "../../../../core/format/argentina_datetime.dart";
import "../../../../core/theme/app_tokens.dart";
import "../../../supervisor/domain/maintenance_order.dart";
import "maintenance_order_photo_dialog.dart";

/// Modal con el detalle completo de un pedido de mantenimiento.
void showMaintenanceOrderDetalleDialog(
	BuildContext context,
	MaintenanceOrder order, {
	int? stockCatalogoCantidad,
}) {
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
							order.numeroOrden,
							style: const TextStyle(
								fontWeight: FontWeight.w800,
								fontSize: 16,
								letterSpacing: 0.3,
							),
						),
						const SizedBox(height: 14),
						_DetalleFila(
							label: "Fecha",
							valor: ArgentinaDateTime.formatDateTime(order.fechaPedido),
						),
						_DetalleFila(label: "Producto", valor: order.producto),
						_DetalleFila(label: "Cantidad", valor: "${order.quantity} u."),
						_DetalleFila(label: "Tipo", valor: order.productType),
						_DetalleFila(label: "Prioridad", valor: order.priority),
						_DetalleFila(label: "Destino", valor: order.destination),
						_DetalleFila(label: "Solicitante", valor: order.solicitante),
						_DetalleFila(label: "Estado", valor: _workflowLabel(order.workflowStatus)),
						if (stockCatalogoCantidad != null)
							_DetalleFila(
								label: "Stock en catálogo (aprox.)",
								valor: stockCatalogoCantidad > 0
										? "$stockCatalogoCantidad u. disponibles"
										: "Sin coincidencia en inventario digital",
							),
						_DetalleFila(label: "Resumen", valor: order.motivo),
						if (order.imagenUrl != null && order.imagenUrl!.trim().isNotEmpty) ...[
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
									imageUrl: order.imagenUrl!,
									height: 140,
									fit: BoxFit.cover,
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
			return "En compras (solicitado por pañol)";
		case MaintenanceWorkflowStatus.comprasOcNotified:
			return "OC emitida por compras";
		case MaintenanceWorkflowStatus.comprasPurchaseDone:
			return "Compra realizada";
		case MaintenanceWorkflowStatus.comprasArrivedNotified:
			return "Material en planta";
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
