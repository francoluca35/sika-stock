import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../auth/application/auth_providers.dart";
import "../../../auth/domain/app_role.dart";
import "../../application/order_navigation_target_provider.dart";
import "../../application/order_retiro_actions.dart";
import "../../../supervisor/application/maintenance_orders_provider.dart";
import "../../../supervisor/domain/maintenance_order.dart";
import "../../../supervisor/domain/maintenance_order_notification_row.dart";
import "maintenance_order_seguimiento_sheet.dart";

enum OrderNotificationActionKind {
	verPedido,
	marcarRetiro,
	aprobarStock,
}

class OrderNotificationAction {
	const OrderNotificationAction({
		required this.kind,
		required this.label,
	});

	final OrderNotificationActionKind kind;
	final String label;
}

List<OrderNotificationAction> orderNotificationActions({
	required AppRole? role,
	required MaintenanceOrder? order,
	MaintenanceOrderNotificationRow? notification,
}) {
	final actions = <OrderNotificationAction>[];

	if (order != null) {
		actions.add(
			const OrderNotificationAction(
				kind: OrderNotificationActionKind.verPedido,
				label: "Ver pedido",
			),
		);

		final puedeRetiro = role == AppRole.panol ||
				role == AppRole.admin ||
				role == AppRole.superadmin;
		if (puedeRetiro &&
				(order.workflowStatus == MaintenanceWorkflowStatus.supervisorStockOk ||
						order.workflowStatus ==
								MaintenanceWorkflowStatus.comprasArrivedNotified)) {
			actions.add(
				const OrderNotificationAction(
					kind: OrderNotificationActionKind.marcarRetiro,
					label: "Marcar retiro",
				),
			);
		}

		final puedeSupervisor = role == AppRole.supervisor ||
				role == AppRole.admin ||
				role == AppRole.superadmin;
		if (puedeSupervisor &&
				order.workflowStatus == MaintenanceWorkflowStatus.pendingSupervisor) {
			actions.add(
				const OrderNotificationAction(
					kind: OrderNotificationActionKind.aprobarStock,
					label: "Aprobar stock",
				),
			);
		}
	} else if (notification != null) {
		actions.add(
			const OrderNotificationAction(
				kind: OrderNotificationActionKind.verPedido,
				label: "Ver pedido",
			),
		);
	}

	return actions;
}

Future<void> handleOrderNotificationAction({
	required BuildContext context,
	required WidgetRef ref,
	required OrderNotificationAction action,
	required String orderId,
	MaintenanceOrder? order,
}) async {
	switch (action.kind) {
		case OrderNotificationActionKind.verPedido:
			await _openOrderSeguimiento(context, ref, orderId, order);
			break;
		case OrderNotificationActionKind.marcarRetiro:
			final o = order ?? await _fetchOrder(ref, orderId);
			if (o == null) {
				if (!context.mounted) return;
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text("No se encontró el pedido.")),
				);
				return;
			}
			if (!context.mounted) return;
			final ok = await confirmPanolMarcarRetiro(context, o);
			if (!ok || !context.mounted) return;
			try {
				await panolMarcarRetiro(ref: ref, context: context, order: o);
			} catch (e) {
				if (!context.mounted) return;
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text("No se pudo registrar el retiro: $e")),
				);
			}
			break;
		case OrderNotificationActionKind.aprobarStock:
			ref.read(orderNavigationTargetProvider.notifier).setTarget(orderId);
			if (!context.mounted) return;
			context.push("/supervisor/pedidos-mantenimiento");
			break;
	}
}

Future<void> _openOrderSeguimiento(
	BuildContext context,
	WidgetRef ref,
	String orderId,
	MaintenanceOrder? order,
) async {
	final o = order ?? await _fetchOrder(ref, orderId);
	if (!context.mounted) return;
	if (o == null) {
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text("No se encontró el pedido.")),
		);
		return;
	}
	showMaintenanceOrderSeguimientoSheet(context, o, ref: ref);
}

Future<MaintenanceOrder?> _fetchOrder(WidgetRef ref, String orderId) async {
	try {
		return await ref
				.read(maintenanceOrdersRepositoryProvider)
				.fetchOrderById(orderId);
	} catch (_) {
		return null;
	}
}

Future<List<OrderNotificationAction>> loadNotificationActions(
	WidgetRef ref,
	MaintenanceOrderNotificationRow notification,
) async {
	final role = ref.read(currentProfileProvider).value?.rol;
	final order = await _fetchOrder(ref, notification.orderId);
	return orderNotificationActions(
		role: role,
		order: order,
		notification: notification,
	);
}
