import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../pwa/pwa_install_banner.dart";
import "../notifications/desktop_alert_service.dart";
import "../notifications/desktop_notification_permission_gate.dart";
import "../notifications/desktop_toast_controller.dart";
import "../notifications/desktop_toast_overlay.dart";
import "../../features/auth/application/auth_providers.dart";
import "../../features/auth/application/auth_session_provider.dart";
import "../../features/auth/domain/app_role.dart";
import "../../features/compras/application/compras_in_app_notifications_provider.dart";
import "../../features/compras/domain/compras_in_app_notification_row.dart";
import "../../features/orders/application/mantenimiento_notificaciones_provider.dart";
import "../../features/orders/application/order_navigation_target_provider.dart";
import "../../features/orders/presentation/widgets/maintenance_order_seguimiento_sheet.dart";
import "../../features/orders/presentation/widgets/order_notification_actions.dart";
import "../../features/panol/application/panol_forwarded_orders_provider.dart";
import "../../features/supervisor/application/maintenance_orders_provider.dart";
import "../../features/supervisor/domain/maintenance_order.dart";
import "../../features/supervisor/domain/maintenance_order_notification_row.dart";
import "app_realtime_sync_provider.dart";

/// Envuelve la app: un canal Realtime opcional + avisos. Sin polling periódico.
class AppRealtimeShell extends ConsumerWidget {
	const AppRealtimeShell({super.key, required this.child});

	final Widget child;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final session = ref.watch(authSessionProvider);
		if (session != null) {
			ref.watch(appRealtimeSyncProvider);
		}
		return Stack(
			fit: StackFit.expand,
			children: [
				child,
				const _LiveNotificationListener(),
				const DesktopNotificationPermissionGate(),
				const DesktopToastOverlay(),
				const PwaInstallBanner(),
			],
		);
	}
}

/// Escucha notificaciones sin reconstruir el árbol principal de la app.
class _LiveNotificationListener extends ConsumerStatefulWidget {
	const _LiveNotificationListener();

	@override
	ConsumerState<_LiveNotificationListener> createState() =>
			_LiveNotificationListenerState();
}

class _LiveNotificationListenerState
		extends ConsumerState<_LiveNotificationListener> {
	final Set<String> _seenMaintNotifIds = {};
	final Set<String> _seenComprasNotifIds = {};
	final Set<String> _seenSupervisorOrderIds = {};
	final Set<String> _seenPanolOrderIds = {};
	bool _maintNotifPrimed = false;
	bool _comprasNotifPrimed = false;
	bool _supervisorOrdersPrimed = false;
	bool _panolOrdersPrimed = false;
	String? _sessionUserId;

	void _resetPriming() {
		_seenMaintNotifIds.clear();
		_seenComprasNotifIds.clear();
		_seenSupervisorOrderIds.clear();
		_seenPanolOrderIds.clear();
		_maintNotifPrimed = false;
		_comprasNotifPrimed = false;
		_supervisorOrdersPrimed = false;
		_panolOrdersPrimed = false;
	}

	String? get _userId => ref.read(authSessionProvider)?.user.id;

	Future<void> _alert({
		required String idKey,
		required String title,
		required String message,
		String? subtitle,
		String? actionLabel,
		VoidCallback? onAction,
	}) async {
		final userId = _userId;
		if (userId == null) return;

		await DesktopAlertService.show(
			userId: userId,
			toastNotifier: ref.read(desktopToastProvider.notifier),
			idKey: idKey,
			title: title,
			message: message,
			subtitle: subtitle,
			actionLabel: actionLabel,
			onAction: onAction,
		);
	}

	void _openOrderSeguimiento(String orderId) {
		unawaited(() async {
			final order = await ref
					.read(maintenanceOrdersRepositoryProvider)
					.fetchOrderById(orderId);
			if (!mounted || order == null) return;
			showMaintenanceOrderSeguimientoSheet(context, order, ref: ref);
		}());
	}

	void _navigateAprobarStock(String orderId) {
		ref.read(orderNavigationTargetProvider.notifier).setTarget(orderId);
		context.push("/supervisor/pedidos-mantenimiento");
	}

	Future<void> _marcarRetiro(String orderId) async {
		final order = await ref
				.read(maintenanceOrdersRepositoryProvider)
				.fetchOrderById(orderId);
		if (!mounted || order == null) return;
		await handleOrderNotificationAction(
			context: context,
			ref: ref,
			action: const OrderNotificationAction(
				kind: OrderNotificationActionKind.marcarRetiro,
				label: "Marcar retiro",
			),
			orderId: orderId,
			order: order,
		);
	}

	void _onMaintNotifications(List<MaintenanceOrderNotificationRow> list) {
		if (!_maintNotifPrimed) {
			_seenMaintNotifIds.addAll(list.map((e) => e.id));
			_maintNotifPrimed = true;
			return;
		}
		final role = ref.read(currentProfileProvider).value?.rol;
		for (final n in list) {
			if (_seenMaintNotifIds.contains(n.id)) continue;
			_seenMaintNotifIds.add(n.id);

			String? actionLabel;
			VoidCallback? onAction;
			if (role == AppRole.panol ||
					role == AppRole.admin ||
					role == AppRole.superadmin) {
				if (n.kind == "panol_atento_retiro" ||
						n.kind == "material_llego_planta") {
					actionLabel = "Marcar retiro";
					onAction = () => unawaited(_marcarRetiro(n.orderId));
				}
			}
			if (role == AppRole.supervisor ||
					role == AppRole.admin ||
					role == AppRole.superadmin) {
				actionLabel ??= "Aprobar stock";
				onAction ??= () => _navigateAprobarStock(n.orderId);
			}
			actionLabel ??= "Ver pedido";
			onAction ??= () => _openOrderSeguimiento(n.orderId);

			unawaited(
				_alert(
					idKey: "mon-${n.id}",
					title: n.title,
					message: n.body,
					actionLabel: actionLabel,
					onAction: onAction,
				),
			);
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
			unawaited(
				_alert(
					idKey: "cin-${n.id}",
					title: n.title,
					message: n.body,
				),
			);
		}
	}

	bool _puedeRecibirAvisoNuevoPedidoSupervisor() {
		final rol = ref.read(currentProfileProvider).value?.rol;
		return rol == AppRole.supervisor ||
				rol == AppRole.admin ||
				rol == AppRole.superadmin;
	}

	bool _puedeRecibirAvisoNuevoPedidoPanol() {
		final rol = ref.read(currentProfileProvider).value?.rol;
		return rol == AppRole.panol ||
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
				final nombre = formatSolicitanteNombre(o.solicitante);
				unawaited(
					_alert(
						idKey: "mo-${o.id}",
						title: "Nuevo pedido",
						message: "$nombre hizo un pedido",
						subtitle: "${o.producto} · ${o.numeroOrden}",
						actionLabel: "Aprobar stock",
						onAction: () => _navigateAprobarStock(o.id),
					),
				);
			}
		}
	}

	void _onPanolOrders(List<MaintenanceOrder> list) {
		if (!_puedeRecibirAvisoNuevoPedidoPanol()) return;
		if (!_panolOrdersPrimed) {
			_seenPanolOrderIds.addAll(list.map((e) => e.id));
			_panolOrdersPrimed = true;
			return;
		}
		for (final o in list) {
			if (_seenPanolOrderIds.contains(o.id)) continue;
			_seenPanolOrderIds.add(o.id);
			if (o.workflowStatus == MaintenanceWorkflowStatus.forwardedToPanol) {
				final nombre = formatSolicitanteNombre(o.solicitante);
				unawaited(
					_alert(
						idKey: "panol-${o.id}",
						title: "Nuevo pedido en pañol",
						message: "$nombre — derivado por supervisor",
						subtitle: "${o.producto} · ${o.numeroOrden}",
						actionLabel: "Ver pedido",
						onAction: () => _openOrderSeguimiento(o.id),
					),
				);
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		ref.listen(authSessionProvider, (prev, next) {
			final uid = next?.user.id;
			if (uid != _sessionUserId) {
				_sessionUserId = uid;
				_resetPriming();
			}
		});
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
			if (!_puedeRecibirAvisoNuevoPedidoPanol()) return;
			next.whenData(_onPanolOrders);
		});
		return const SizedBox.shrink();
	}
}
