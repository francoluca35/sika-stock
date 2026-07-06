import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../auth/application/auth_providers.dart";
import "../../../supervisor/domain/maintenance_order.dart";
import "../../../auth/domain/app_role.dart";
import "cancel_maintenance_order_dialog.dart";
import "maintenance_order_timeline.dart";
import "order_notification_actions.dart";
import "retiro_producto_detail_sheet.dart";

/// Muestra el **seguimiento** del pedido con línea de tiempo unificada y acciones según rol.
void showMaintenanceOrderSeguimientoSheet(
	BuildContext context,
	MaintenanceOrder o, {
	WidgetRef? ref,
}) {
	showModalBottomSheet<void>(
		context: context,
		isScrollControlled: true,
		useSafeArea: true,
		backgroundColor: Colors.white,
		shape: const RoundedRectangleBorder(
			borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
		),
		builder: (sheetContext) => _SeguimientoSheetBody(
			sheetContext: sheetContext,
			order: o,
			parentRef: ref,
		),
	);
}

class _SeguimientoSheetBody extends ConsumerWidget {
	const _SeguimientoSheetBody({
		required this.sheetContext,
		required this.order,
		this.parentRef,
	});

	final BuildContext sheetContext;
	final MaintenanceOrder order;
	final WidgetRef? parentRef;

	@override
	Widget build(BuildContext context, WidgetRef sheetRef) {
		final effectiveRef = parentRef ?? sheetRef;
		final role = effectiveRef.watch(currentProfileProvider).value?.rol;
		final actions = orderNotificationActions(role: role, order: order);
		final bottom = MediaQuery.paddingOf(sheetContext).bottom;

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
						const Text(
							"Seguimiento",
							textAlign: TextAlign.center,
							style: TextStyle(
								fontWeight: FontWeight.bold,
								fontSize: 18,
								color: Colors.black87,
							),
						),
						const SizedBox(height: 6),
						Text(
							order.numeroOrden,
							textAlign: TextAlign.center,
							style: TextStyle(
								fontWeight: FontWeight.w700,
								fontSize: 14,
								color: Colors.grey.shade800,
							),
						),
						const SizedBox(height: 14),
						MaintenanceOrderProgressBar(status: order.workflowStatus),
						const SizedBox(height: 16),
						MaintenanceOrderTimeline(order: order),
						if (_mostrarVerProducto(order)) ...[
							const SizedBox(height: 8),
							OutlinedButton.icon(
								onPressed: () =>
										showRetiroProductoDetailSheet(sheetContext, order),
								icon: const Icon(Icons.inventory_2_outlined, size: 20),
								label: const Text("Ver producto"),
								style: OutlinedButton.styleFrom(
									foregroundColor: Colors.black87,
									side: const BorderSide(color: Colors.black54, width: 1.2),
									padding: const EdgeInsets.symmetric(vertical: 12),
								),
							),
						],
						if (actions.length > 1) ...[
							const SizedBox(height: 12),
							...actions
									.where((a) => a.kind != OrderNotificationActionKind.verPedido)
									.map(
										(action) => Padding(
											padding: const EdgeInsets.only(bottom: 8),
											child: FilledButton(
												onPressed: () async {
													await handleOrderNotificationAction(
														context: sheetContext,
														ref: effectiveRef,
														action: action,
														orderId: order.id,
														order: order,
													);
												},
												child: Text(action.label),
											),
										),
									),
						],
						if (appRolePuedeAnularPedidoMantenimiento(role) && order.puedeAnular) ...[
							const SizedBox(height: 4),
							OutlinedButton.icon(
								onPressed: () async {
									Navigator.pop(sheetContext);
									await handleCancelMaintenanceOrderForRole(
										context: context,
										ref: effectiveRef,
										role: role,
										order: order,
									);
								},
								icon: Icon(Icons.cancel_outlined, color: Colors.red.shade800),
								label: Text(
									"Anular pedido",
									style: TextStyle(
										fontWeight: FontWeight.w700,
										color: Colors.red.shade800,
									),
								),
								style: OutlinedButton.styleFrom(
									side: BorderSide(color: Colors.red.shade800, width: 1.2),
									padding: const EdgeInsets.symmetric(vertical: 12),
								),
							),
						],
						if (order.cancellationObservacion.trim().isNotEmpty) ...[
							const SizedBox(height: 10),
							Container(
								padding: const EdgeInsets.all(10),
								decoration: BoxDecoration(
									color: Colors.red.shade50,
									borderRadius: BorderRadius.circular(8),
									border: Border.all(color: Colors.red.shade200),
								),
								child: Text(
									"Motivo de anulación: ${order.cancellationObservacion.trim()}",
									style: TextStyle(
										fontSize: 13,
										height: 1.35,
										color: Colors.red.shade900,
									),
								),
							),
						],
						const SizedBox(height: 8),
						OutlinedButton(
							onPressed: () => Navigator.pop(sheetContext),
							child: const Text("Cerrar"),
						),
					],
				),
			),
		);
	}
}

bool _mostrarVerProducto(MaintenanceOrder o) {
	if (o.workflowStatus == MaintenanceWorkflowStatus.completed) return true;
	final sid = o.stockItemId?.trim();
	if (sid != null && sid.isNotEmpty) return true;
	final foto = o.imagenUrl?.trim();
	return foto != null && foto.isNotEmpty;
}
