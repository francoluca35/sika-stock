import "package:flutter/material.dart";

import "../../../../core/format/argentina_datetime.dart";
import "../../../../core/theme/app_tokens.dart";
import "../../../supervisor/domain/maintenance_order.dart";
import "retiro_producto_detail_sheet.dart";

/// Muestra el **seguimiento** del pedido (estados y texto operativo).
void showMaintenanceOrderSeguimientoSheet(BuildContext context, MaintenanceOrder o) {
	showModalBottomSheet<void>(
		context: context,
		isScrollControlled: true,
		useSafeArea: true,
		backgroundColor: Colors.white,
		shape: const RoundedRectangleBorder(
			borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
		),
		builder: (ctx) {
			final bottom = MediaQuery.paddingOf(ctx).bottom;
			final lineas = _seguimientoLineas(o);
			return Padding(
				padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
				child: SingleChildScrollView(
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Center(
								child: Container(
									width: 40,
									height: 4,
									decoration: BoxDecoration(
										color: Colors.grey.shade400,
										borderRadius: BorderRadius.circular(40),
									),
								),
							),
							const SizedBox(height: 14),
							Text(
								"Seguimiento",
								textAlign: TextAlign.center,
								style: const TextStyle(
									fontWeight: FontWeight.bold,
									fontSize: 18,
									color: Colors.black87,
								),
							),
							const SizedBox(height: 6),
							Text(
								o.numeroOrden,
								textAlign: TextAlign.center,
								style: TextStyle(
									fontWeight: FontWeight.w700,
									fontSize: 14,
									color: Colors.grey.shade800,
								),
							),
							const SizedBox(height: 16),
							...lineas.map(
								(t) => Padding(
									padding: const EdgeInsets.only(bottom: 10),
									child: Row(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Padding(
												padding: const EdgeInsets.only(top: 2),
												child: Icon(
													Icons.circle,
													size: 8,
													color: AppTokens.blackNav,
												),
											),
											const SizedBox(width: 10),
											Expanded(
												child: Text(
													t,
													style: const TextStyle(
														fontSize: 14,
														height: 1.35,
														color: Colors.black87,
													),
												),
											),
										],
									),
								),
							),
							if (_mostrarVerProducto(o)) ...[
								const SizedBox(height: 4),
								OutlinedButton.icon(
									onPressed: () => showRetiroProductoDetailSheet(ctx, o),
									icon: const Icon(Icons.inventory_2_outlined, size: 20),
									label: const Text("Ver producto"),
									style: OutlinedButton.styleFrom(
										foregroundColor: Colors.black87,
										side: const BorderSide(color: Colors.black54, width: 1.2),
										padding: const EdgeInsets.symmetric(vertical: 12),
									),
								),
							],
							const SizedBox(height: 8),
							FilledButton(
								onPressed: () => Navigator.pop(ctx),
								child: const Text("Cerrar"),
							),
						],
					),
				),
			);
		},
	);
}

bool _mostrarVerProducto(MaintenanceOrder o) {
	if (o.workflowStatus == MaintenanceWorkflowStatus.completed) return true;
	final sid = o.stockItemId?.trim();
	if (sid != null && sid.isNotEmpty) return true;
	final foto = o.imagenUrl?.trim();
	return foto != null && foto.isNotEmpty;
}

List<String> _seguimientoLineas(MaintenanceOrder o) {
	final out = <String>[];
	final alta = ArgentinaDateTime.formatDateTime(o.fechaPedido);
	out.add("Pedido registrado ($alta): ${o.producto} · ${o.quantity} u. · ${o.destination}");

	switch (o.workflowStatus) {
		case MaintenanceWorkflowStatus.pendingSupervisor:
			out.add(
				"Estado actual: pendiente de revisión del supervisor.",
			);
			break;
		case MaintenanceWorkflowStatus.supervisorStockOk:
			out.add(
				"Supervisor confirmó stock disponible para retiro (avisó a pañol y mantenimiento).",
			);
			out.add(
				"Pañol debe registrar el retiro; ahí se descontará ${o.quantity} u. del inventario.",
			);
			break;
		case MaintenanceWorkflowStatus.forwardedToPanol:
			out.add(
				"Supervisor derivó a pañol: sin stock suficiente en depósito según la revisión.",
			);
			out.add(
				"Pañol gestiona la consulta / posible pedido a compras.",
			);
			break;
		case MaintenanceWorkflowStatus.panolRequestedCompras:
			out.add(
				"Pañol registró pedido a compras (sin stock en planta).",
			);
			break;
		case MaintenanceWorkflowStatus.comprasOcNotified:
		case MaintenanceWorkflowStatus.comprasPurchaseDone:
			out.add(
				"Pedido a compras en gestión por pañol.",
			);
			break;
		case MaintenanceWorkflowStatus.comprasArrivedNotified:
			out.add(
				"Pañol avisó que el material está listo para retirar.",
			);
			break;
		case MaintenanceWorkflowStatus.completed:
			out.add(
				"Pedido completado / retiro cerrado en el sistema.",
			);
			if (o.stockItemId != null && o.stockItemId!.isNotEmpty) {
				out.add(
					"Se descontaron ${o.quantity} u. del inventario al registrar el retiro en pañol.",
				);
			}
			break;
		case MaintenanceWorkflowStatus.cancelled:
			out.add("Pedido cancelado.");
			break;
	}
	return out;
}
