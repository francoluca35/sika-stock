import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../notifications/local_notification_service.dart";
import "../../features/auth/application/auth_providers.dart";
import "../../features/auth/application/auth_session_provider.dart";
import "../../features/auth/domain/app_role.dart";
import "../../features/compras/application/compras_flow_realtime_tick_provider.dart";
import "../../features/compras/application/compras_in_app_notifications_provider.dart";
import "../../features/compras/domain/compras_in_app_notification_row.dart";
import "../../features/orders/application/mantenimiento_notificaciones_provider.dart";
import "../../features/orders/application/mis_pedidos_mantenimiento_provider.dart";
import "../../features/panol/application/panol_forwarded_orders_provider.dart";
import "../../features/supervisor/application/maintenance_orders_provider.dart";
import "../../features/supervisor/application/maintenance_orders_realtime_provider.dart";
import "../../features/supervisor/domain/maintenance_order.dart";
import "../../features/supervisor/domain/maintenance_order_notification_row.dart";
import "stock_realtime_tick_provider.dart";

/// Mantiene activos Realtime y alertas mientras hay sesión.
class AppRealtimeShell extends ConsumerWidget {
	const AppRealtimeShell({super.key, required this.child});

	final Widget child;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final session = ref.watch(authSessionProvider);
		if (session != null) {
			ref.watch(maintenanceOrdersRealtimeTickProvider);
			ref.watch(comprasFlowRealtimeTickProvider);
			ref.watch(stockRealtimeTickProvider);
		}
		return LiveNotificationHost(child: child);
	}
}

/// SnackBar en app + notificación en barra del sistema (móvil).
class LiveNotificationHost extends ConsumerStatefulWidget {
	const LiveNotificationHost({super.key, required this.child});

	final Widget child;

	@override
	ConsumerState<LiveNotificationHost> createState() =>
			_LiveNotificationHostState();
}

class _LiveNotificationHostState extends ConsumerState<LiveNotificationHost> {
	final Set<String> _seenMaintNotifIds = {};
	final Set<String> _seenComprasNotifIds = {};
	final Set<String> _seenSupervisorOrderIds = {};
	final Set<String> _seenPanolOrderIds = {};
	bool _maintNotifPrimed = false;
	bool _comprasNotifPrimed = false;
	bool _supervisorOrdersPrimed = false;
	bool _panolOrdersPrimed = false;

	void _alert({
		required String idKey,
		required String title,
		required String body,
	}) {
		if (mounted) {
			final messenger = ScaffoldMessenger.maybeOf(context);
			if (messenger != null) {
				messenger.clearSnackBars();
				messenger.showSnackBar(
					SnackBar(
						content: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									title,
									style: const TextStyle(fontWeight: FontWeight.bold),
								),
								const SizedBox(height: 4),
								Text(body),
							],
						),
						duration: const Duration(seconds: 6),
						behavior: SnackBarBehavior.floating,
					),
				);
			}
		}
		unawaited(
			LocalNotificationService.showAlert(
				idKey: idKey,
				title: title,
				body: body,
			),
		);
	}

	void _onMaintNotifications(List<MaintenanceOrderNotificationRow> list) {
		if (!_maintNotifPrimed) {
			_seenMaintNotifIds.addAll(list.map((e) => e.id));
			_maintNotifPrimed = true;
			return;
		}
		for (final n in list) {
			if (_seenMaintNotifIds.contains(n.id)) continue;
			_seenMaintNotifIds.add(n.id);
			_alert(idKey: "mon-${n.id}", title: n.title, body: n.body);
		}
	}

	void _onComprasNotifications(List<ComprasInAppNotificationRow> list) {
		if (!_comprasNotifPrimed) {
			_seenComprasNotifIds.addAll(list.map((e) => e.id));
			_comprasNotifPrimed = true;
			return;
		}
		for (final n in list) {
			if (_seenComprasNotifIds.contains(n.id)) continue;
			_seenComprasNotifIds.add(n.id);
			_alert(idKey: "cin-${n.id}", title: n.title, body: n.body);
		}
	}

	bool _puedeRecibirAvisoNuevoPedidoSupervisor() {
		final rol = ref.read(currentProfileProvider).value?.rol;
		return rol == AppRole.supervisor ||
				rol == AppRole.admin ||
				rol == AppRole.superadmin;
	}

	void _onSupervisorOrders(List<MaintenanceOrder> list) {
		if (!_puedeRecibirAvisoNuevoPedidoSupervisor()) return;
		if (!_supervisorOrdersPrimed) {
			_seenSupervisorOrderIds.addAll(list.map((e) => e.id));
			_supervisorOrdersPrimed = true;
			return;
		}
		for (final o in list) {
			if (_seenSupervisorOrderIds.contains(o.id)) continue;
			_seenSupervisorOrderIds.add(o.id);
			if (o.workflowStatus == MaintenanceWorkflowStatus.pendingSupervisor) {
				_alert(
					idKey: "mo-${o.id}",
					title: "Nuevo pedido de mantenimiento",
					body: "${o.numeroOrden}: ${o.producto}",
				);
			}
		}
	}

	void _onPanolOrders(List<MaintenanceOrder> list) {
		if (!_panolOrdersPrimed) {
			_seenPanolOrderIds.addAll(list.map((e) => e.id));
			_panolOrdersPrimed = true;
			return;
		}
		for (final o in list) {
			if (_seenPanolOrderIds.contains(o.id)) continue;
			_seenPanolOrderIds.add(o.id);
			if (o.workflowStatus == MaintenanceWorkflowStatus.forwardedToPanol) {
				_alert(
					idKey: "panol-${o.id}",
					title: "Nuevo pedido en pañol",
					body: "${o.numeroOrden}: ${o.producto}",
				);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		ref.listen(mantenimientoNotificacionesProvider, (prev, next) {
			next.whenData(_onMaintNotifications);
		});
		ref.listen(comprasInAppNotificationsProvider, (prev, next) {
			next.whenData(_onComprasNotifications);
		});
		ref.listen(maintenanceOrdersProvider, (prev, next) {
			if (!_puedeRecibirAvisoNuevoPedidoSupervisor()) return;
			next.whenData(_onSupervisorOrders);
		});
		ref.listen(panolForwardedOrdersProvider, (prev, next) {
			next.whenData(_onPanolOrders);
		});
		ref.watch(mantenimientoNotificacionesProvider);
		ref.watch(comprasInAppNotificationsProvider);
		ref.watch(maintenanceOrdersProvider);
		ref.watch(misPedidosMantenimientoProvider);
		ref.watch(panolForwardedOrdersProvider);
		return widget.child;
	}
}
