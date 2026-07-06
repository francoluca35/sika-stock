import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../../auth/application/auth_providers.dart";
import "../../../auth/domain/app_role.dart";
import "../../../supervisor/application/maintenance_orders_provider.dart";
import "../../application/mantenimiento_notificaciones_provider.dart";
import "../../../supervisor/domain/maintenance_order_notification_row.dart";
import "order_notification_actions.dart";

/// Avisos del flujo de pedidos con acciones directas (ver pedido, retiro, aprobar stock).
class MaintenanceNotificationsBlock extends ConsumerWidget {
	const MaintenanceNotificationsBlock({super.key});

	Future<void> _borrarTodas(BuildContext context, WidgetRef ref) async {
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text("Borrar todos los avisos"),
				content: const Text(
					"¿Querés eliminar todos los avisos? Esta acción no se puede deshacer.",
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text("Cancelar"),
					),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text("Borrar todas"),
					),
				],
			),
		);
		if (ok != true) return;
		try {
			await ref
					.read(maintenanceOrdersRepositoryProvider)
					.dismissAllMyNotifications();
			ref.read(mantenimientoNotificacionesProvider.notifier).refresh();
		} catch (e) {
			if (!context.mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudieron borrar los avisos: $e")),
			);
		}
	}

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final async = ref.watch(mantenimientoNotificacionesProvider);
		final role = ref.watch(currentProfileProvider).value?.rol;

		return async.when(
			data: (list) {
				if (list.isEmpty) return const SizedBox.shrink();
				return Material(
					color: const Color(0xFFE3F2FD),
					borderRadius: BorderRadius.circular(AppTokens.radiusMd),
					elevation: 0,
					child: Container(
						decoration: BoxDecoration(
							borderRadius: BorderRadius.circular(AppTokens.radiusMd),
							border: Border.all(color: Colors.blue.shade200),
						),
						padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Row(
									children: [
										Icon(
											Icons.notifications_active_outlined,
											size: 20,
											color: Colors.blue.shade900,
										),
										const SizedBox(width: 8),
										Expanded(
											child: Text(
												"Avisos",
												style: TextStyle(
													fontWeight: FontWeight.bold,
													fontSize: 14,
													color: Colors.blue.shade900,
												),
											),
										),
										TextButton(
											onPressed: () => _borrarTodas(context, ref),
											style: TextButton.styleFrom(
												padding: const EdgeInsets.symmetric(horizontal: 8),
												minimumSize: Size.zero,
												tapTargetSize: MaterialTapTargetSize.shrinkWrap,
											),
											child: Text(
												"Borrar todas",
												style: TextStyle(
													fontSize: 12,
													fontWeight: FontWeight.w700,
													color: Colors.blue.shade800,
												),
											),
										),
									],
								),
								const SizedBox(height: 8),
								for (final n in list.take(8))
									Padding(
										padding: const EdgeInsets.only(bottom: 8),
										child: _NotificationCard(
											notification: n,
											role: role,
										),
									),
							],
						),
					),
				);
			},
			loading: () => const SizedBox.shrink(),
			error: (_, __) => const SizedBox.shrink(),
		);
	}
}

class _NotificationCard extends ConsumerWidget {
	const _NotificationCard({
		required this.notification,
		required this.role,
	});

	final MaintenanceOrderNotificationRow notification;
	final AppRole? role;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final n = notification;
		final quickActions = _quickActions(role: role, kind: n.kind);

		return Material(
			color: AppTokens.whiteSurface,
			borderRadius: BorderRadius.circular(8),
			child: Padding(
				padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												n.title,
												style: TextStyle(
													fontWeight: FontWeight.w800,
													fontSize: 13,
													color: _titleColor(n.kind),
												),
											),
											const SizedBox(height: 4),
											Text(
												n.body,
												style: TextStyle(
													fontSize: 12.5,
													height: 1.25,
													color: Colors.grey.shade800,
												),
											),
										],
									),
								),
								IconButton(
									tooltip: "Descartar aviso",
									icon: Icon(
										Icons.close,
										size: 20,
										color: Colors.grey.shade600,
									),
									padding: EdgeInsets.zero,
									constraints: const BoxConstraints(
										minWidth: 36,
										minHeight: 36,
									),
									onPressed: () async {
										await ref
												.read(maintenanceOrdersRepositoryProvider)
												.dismissNotification(n.id);
										ref
												.read(mantenimientoNotificacionesProvider.notifier)
												.refresh(silent: true);
									},
								),
							],
						),
						if (quickActions.isNotEmpty) ...[
							const SizedBox(height: 6),
							Wrap(
								spacing: 6,
								runSpacing: 6,
								children: [
									for (final action in quickActions)
										_ActionChip(
											label: action.label,
											filled: action.kind ==
													OrderNotificationActionKind.verPedido,
											onPressed: () async {
												await handleOrderNotificationAction(
													context: context,
													ref: ref,
													action: action,
													orderId: n.orderId,
												);
												await ref
														.read(maintenanceOrdersRepositoryProvider)
														.dismissNotification(n.id);
												ref
														.read(
															mantenimientoNotificacionesProvider
																	.notifier,
														)
														.refresh(silent: true);
											},
										),
								],
							),
						],
					],
				),
			),
		);
	}

	static Color _titleColor(String kind) {
		return switch (kind) {
			"stock_ok_retiro" => const Color(0xFF1B5E20),
			"panol_atento_retiro" => const Color(0xFF1B5E20),
			"panol_stock_externo" => const Color(0xFF1B5E20),
			"enviado_a_compras" => Colors.orange.shade900,
			"sin_stock_pendiente" => Colors.orange.shade900,
			"compra_realizada" => Colors.deepOrange.shade900,
			"oc_emitida_compras" => Colors.indigo.shade900,
			"material_llego_planta" => const Color(0xFF1B5E20),
			"pedido_anulado" => Colors.red.shade900,
			_ => Colors.orange.shade900,
		};
	}
}

List<OrderNotificationAction> _quickActions({
	required AppRole? role,
	required String kind,
}) {
	final actions = <OrderNotificationAction>[
		const OrderNotificationAction(
			kind: OrderNotificationActionKind.verPedido,
			label: "Ver pedido",
		),
	];

	final esPanol = role == AppRole.panol ||
			role == AppRole.admin ||
			role == AppRole.superadmin;
	if (esPanol &&
			(kind == "panol_atento_retiro" || kind == "material_llego_planta")) {
		actions.add(
			const OrderNotificationAction(
				kind: OrderNotificationActionKind.marcarRetiro,
				label: "Marcar retiro",
			),
		);
	}

	final esSupervisor = role == AppRole.supervisor ||
			role == AppRole.admin ||
			role == AppRole.superadmin;
	if (esSupervisor) {
		actions.add(
			const OrderNotificationAction(
				kind: OrderNotificationActionKind.aprobarStock,
				label: "Aprobar stock",
			),
		);
	}

	return actions;
}

class _ActionChip extends StatelessWidget {
	const _ActionChip({
		required this.label,
		required this.onPressed,
		this.filled = false,
	});

	final String label;
	final VoidCallback onPressed;
	final bool filled;

	@override
	Widget build(BuildContext context) {
		if (filled) {
			return FilledButton(
				onPressed: onPressed,
				style: FilledButton.styleFrom(
					padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
					minimumSize: Size.zero,
					tapTargetSize: MaterialTapTargetSize.shrinkWrap,
					textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
				),
				child: Text(label),
			);
		}
		return OutlinedButton(
			onPressed: onPressed,
			style: OutlinedButton.styleFrom(
				padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
				minimumSize: Size.zero,
				tapTargetSize: MaterialTapTargetSize.shrinkWrap,
				textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
				side: const BorderSide(color: Colors.black54),
			),
			child: Text(label),
		);
	}
}
