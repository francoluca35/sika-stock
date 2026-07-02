import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../panol/application/panol_forwarded_orders_provider.dart";
import "../../panol/application/panol_order_history_provider.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../supervisor/application/maintenance_orders_provider.dart";
import "../../supervisor/domain/maintenance_order.dart";

/// Registra retiro en pañol (descuenta inventario si hay `stock_item_id`).
Future<void> panolMarcarRetiro({
	required WidgetRef ref,
	required BuildContext context,
	required MaintenanceOrder order,
}) async {
	if (order.workflowStatus != MaintenanceWorkflowStatus.supervisorStockOk &&
			order.workflowStatus != MaintenanceWorkflowStatus.comprasArrivedNotified) {
		throw Exception("Este pedido aún no está listo para retiro.");
	}

	await ref.read(maintenanceOrdersRepositoryProvider).markCompleted(order.id);
	await ref.read(panolForwardedOrdersProvider.notifier).refresh(silent: true);
	ref.invalidate(panolOrderHistoryProvider);
	ref.read(panolOrderHistoryProvider);

	if (order.stockItemId != null && order.stockItemId!.isNotEmpty) {
		await ref.read(supervisorStockCatalogProvider.notifier).refresh();
	}

	if (!context.mounted) return;

	final desconto =
			order.stockItemId != null && order.stockItemId!.isNotEmpty;
	ScaffoldMessenger.of(context).showSnackBar(
		SnackBar(
			content: Text(
				desconto
						? "Retiro registrado: ${order.numeroOrden} · "
								"se descontaron ${order.quantity} u. del inventario."
						: "Retiro registrado: ${order.numeroOrden}.",
			),
		),
	);
}

Future<bool> confirmPanolMarcarRetiro(
	BuildContext context,
	MaintenanceOrder order,
) async {
	final ok = await showDialog<bool>(
		context: context,
		builder: (ctx) => AlertDialog(
			title: const Text("Registrar retiro"),
			content: Text(
				"¿Confirmás el retiro de ${order.numeroOrden}?\n"
				"${order.producto} · ${order.quantity} u.",
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(ctx, false),
					child: const Text("Cancelar"),
				),
				FilledButton(
					onPressed: () => Navigator.pop(ctx, true),
					child: const Text("Marcar retiro"),
				),
			],
		),
	);
	return ok == true;
}
