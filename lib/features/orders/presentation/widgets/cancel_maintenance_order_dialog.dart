import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../auth/domain/app_role.dart";
import "../../../panol/application/panol_forwarded_orders_provider.dart";
import "../../../supervisor/application/maintenance_orders_provider.dart";
import "../../../supervisor/domain/maintenance_order.dart";

/// Diálogo para anular un pedido de mantenimiento con motivo obligatorio.
Future<String?> showCancelMaintenanceOrderDialog(
	BuildContext context,
	MaintenanceOrder order,
) {
	return showDialog<String?>(
		context: context,
		builder: (ctx) => _CancelMaintenanceOrderDialog(order: order),
	);
}

class _CancelMaintenanceOrderDialog extends StatefulWidget {
	const _CancelMaintenanceOrderDialog({required this.order});

	final MaintenanceOrder order;

	@override
	State<_CancelMaintenanceOrderDialog> createState() =>
			_CancelMaintenanceOrderDialogState();
}

class _CancelMaintenanceOrderDialogState
		extends State<_CancelMaintenanceOrderDialog> {
	late final TextEditingController _ctrl;

	@override
	void initState() {
		super.initState();
		_ctrl = TextEditingController();
	}

	@override
	void dispose() {
		_ctrl.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final obs = _ctrl.text.trim();
		return AlertDialog(
			title: const Text("Anular pedido"),
			content: SingleChildScrollView(
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					mainAxisSize: MainAxisSize.min,
					children: [
						Text(
							"Pedido ${widget.order.numeroOrden} · ${widget.order.producto}",
							style: const TextStyle(
								fontWeight: FontWeight.w700,
								height: 1.35,
							),
						),
						const SizedBox(height: 14),
						const Text(
							"El técnico de mantenimiento recibirá una notificación "
							"con el motivo de anulación.",
							style: TextStyle(fontSize: 13, height: 1.35),
						),
						const SizedBox(height: 14),
						TextField(
							controller: _ctrl,
							maxLines: 4,
							maxLength: 500,
							autofocus: true,
							decoration: const InputDecoration(
								labelText: "Motivo de anulación",
								hintText: "Ej.: material no disponible, pedido duplicado…",
								border: OutlineInputBorder(),
								alignLabelWithHint: true,
							),
							onChanged: (_) => setState(() {}),
						),
					],
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.pop(context),
					child: const Text("Cancelar"),
				),
				FilledButton(
					style: FilledButton.styleFrom(
						backgroundColor: Colors.red.shade800,
					),
					onPressed: obs.isEmpty ? null : () => Navigator.pop(context, obs),
					child: const Text("Anular pedido"),
				),
			],
		);
	}
}

typedef CancelMaintenanceOrderCallback = Future<void> Function({
	required String orderId,
	required String observacion,
});

Future<void> handleCancelMaintenanceOrder({
	required BuildContext context,
	required WidgetRef ref,
	required MaintenanceOrder order,
	required CancelMaintenanceOrderCallback onCancel,
}) async {
	final obs = await showCancelMaintenanceOrderDialog(context, order);
	if (obs == null || !context.mounted) return;
	try {
		await onCancel(orderId: order.id, observacion: obs);
		if (!context.mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					"Pedido ${order.numeroOrden} anulado. El técnico fue notificado.",
				),
			),
		);
	} catch (e) {
		if (!context.mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text("No se pudo anular el pedido: $e")),
		);
	}
}

Future<void> cancelMaintenanceOrderForRole({
	required WidgetRef ref,
	required AppRole? role,
	required String orderId,
	required String observacion,
}) async {
	if (role == AppRole.panol) {
		await ref.read(panolForwardedOrdersProvider.notifier).cancelOrder(
					orderId: orderId,
					observacion: observacion,
				);
		return;
	}
	await ref.read(maintenanceOrdersProvider.notifier).cancelOrder(
				orderId: orderId,
				observacion: observacion,
			);
}

Future<void> handleCancelMaintenanceOrderForRole({
	required BuildContext context,
	required WidgetRef ref,
	required AppRole? role,
	required MaintenanceOrder order,
}) async {
	await handleCancelMaintenanceOrder(
		context: context,
		ref: ref,
		order: order,
		onCancel: ({required orderId, required observacion}) =>
				cancelMaintenanceOrderForRole(
					ref: ref,
					role: role,
					orderId: orderId,
					observacion: observacion,
				),
	);
}
