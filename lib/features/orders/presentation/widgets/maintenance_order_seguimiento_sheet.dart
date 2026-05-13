import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../../supervisor/domain/maintenance_order.dart";

/// Muestra el **seguimiento** del pedido (estados y texto operativo).
void showMaintenanceOrderSeguimientoSheet(BuildContext context, MaintenanceOrder o) {
	final fmt = DateFormat("dd/MM/yyyy HH:mm");
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
			final lineas = _seguimientoLineas(o, fmt);
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

List<String> _seguimientoLineas(MaintenanceOrder o, DateFormat fmt) {
	final out = <String>[];
	final alta = fmt.format(o.fechaPedido);
	out.add("Pedido registrado ($alta): ${o.producto} · ${o.quantity} u. · ${o.destination}");

	switch (o.workflowStatus) {
		case MaintenanceWorkflowStatus.pendingSupervisor:
			out.add(
				"Estado actual: pendiente de revisión del supervisor.",
			);
			break;
		case MaintenanceWorkflowStatus.supervisorStockOk:
			out.add(
				"Supervisor confirmó stock disponible para retiro.",
			);
			if (o.stockItemId != null && o.stockItemId!.isNotEmpty) {
				out.add(
					"Inventario: se descontaron ${o.quantity} u. del ítem asociado al confirmar el retiro.",
				);
			} else {
				out.add(
					"Coordiná la entrega física con pañol (esta OM no tiene descuento automático en catálogo).",
				);
			}
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
				"Pañol solicitó material a compras (sin stock en planta).",
			);
			break;
		case MaintenanceWorkflowStatus.comprasOcNotified:
			out.add(
				"Compras notificó orden de compra emitida; el pedido queda en consulta organizacional.",
			);
			break;
		case MaintenanceWorkflowStatus.comprasArrivedNotified:
			out.add(
				"Material recibido en planta: coordinar retiro con el sector solicitante.",
			);
			break;
		case MaintenanceWorkflowStatus.completed:
			out.add(
				"Pedido completado / retiro cerrado en el sistema.",
			);
			if (o.stockItemId != null && o.stockItemId!.isNotEmpty) {
				out.add(
					"En su momento se descontaron ${o.quantity} u. del inventario al confirmar stock.",
				);
			}
			break;
		case MaintenanceWorkflowStatus.cancelled:
			out.add("Pedido cancelado.");
			break;
	}
	return out;
}
