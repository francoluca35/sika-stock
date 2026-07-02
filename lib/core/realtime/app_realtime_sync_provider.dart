import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../features/auth/application/auth_providers.dart";
import "../../features/auth/application/auth_session_provider.dart";
import "../../features/auth/domain/app_role.dart";
import "../../features/orders/application/mantenimiento_notificaciones_provider.dart";
import "../../features/orders/application/mis_pedidos_mantenimiento_provider.dart";
import "../../features/panol/application/panol_forwarded_orders_provider.dart";
import "../../features/supervisor/application/maintenance_orders_provider.dart";

/// `true` si el único canal Realtime está activo en esta sesión.
final appRealtimeSyncProvider =
		NotifierProvider<AppRealtimeSyncNotifier, bool>(AppRealtimeSyncNotifier.new);

/// Un solo WebSocket: solo pedidos + notificaciones de pedido. Sin stock ni compras.
class AppRealtimeSyncNotifier extends Notifier<bool> {
	RealtimeChannel? _channel;
	Timer? _ordersDebounce;
	Timer? _notifDebounce;
	bool _disabled = false;
	bool _connecting = false;

	static const _debounceMs = 400;

	void _refreshOrdersForCurrentRole() {
		if (!ref.mounted || _disabled) return;
		final c = ref.container;
		final rol = c.read(currentProfileProvider).value?.rol;
		switch (rol) {
			case AppRole.supervisor:
				unawaited(
					c.read(maintenanceOrdersProvider.notifier).refresh(silent: true),
				);
			case AppRole.panol:
				unawaited(
					c.read(panolForwardedOrdersProvider.notifier).refresh(silent: true),
				);
			case AppRole.mantenimiento:
				unawaited(
					c.read(misPedidosMantenimientoProvider.notifier).refresh(silent: true),
				);
			case AppRole.admin:
			case AppRole.superadmin:
				unawaited(
					c.read(maintenanceOrdersProvider.notifier).refresh(silent: true),
				);
				unawaited(
					c.read(panolForwardedOrdersProvider.notifier).refresh(silent: true),
				);
			case AppRole.compras:
			case null:
				break;
		}
	}

	void _scheduleOrdersReload() {
		_ordersDebounce?.cancel();
		_ordersDebounce = Timer(
			const Duration(milliseconds: _debounceMs),
			_refreshOrdersForCurrentRole,
		);
	}

	void _scheduleNotificationsReload() {
		_notifDebounce?.cancel();
		_notifDebounce = Timer(
			const Duration(milliseconds: _debounceMs),
			() {
				if (!ref.mounted || _disabled) return;
				unawaited(
					ref
							.read(mantenimientoNotificacionesProvider.notifier)
							.refresh(silent: true),
				);
			},
		);
	}

	void _cancelDebouncers() {
		_ordersDebounce?.cancel();
		_ordersDebounce = null;
		_notifDebounce?.cancel();
		_notifDebounce = null;
	}

	@override
	bool build() {
		ref.keepAlive();
		final session = ref.watch(authSessionProvider);
		if (session == null) {
			_teardown();
			_disabled = false;
			_connecting = false;
			return false;
		}
		if (!_disabled && !_connecting && _channel == null) {
			_connecting = true;
			_trySubscribe(ref.read(supabaseClientProvider));
		}
		ref.onDispose(_teardown);
		return _channel != null && !_disabled;
	}

	void _trySubscribe(SupabaseClient client) {
		if (_disabled) {
			_connecting = false;
			return;
		}
		final uid = client.auth.currentUser?.id ?? "anon";
		_channel = client.channel("app-live-sync-$uid");
		_channel!
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "maintenance_orders",
					callback: (_) => _scheduleOrdersReload(),
				)
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "maintenance_order_notifications",
					callback: (_) => _scheduleNotificationsReload(),
				)
				.subscribe((status, [error]) {
					_connecting = false;
					if (status == RealtimeSubscribeStatus.subscribed) {
						if (kDebugMode) {
							debugPrint("[live-sync] WebSocket conectado (pedidos)");
						}
						state = true;
						return;
					}
					if (kDebugMode) {
						debugPrint(
							"[live-sync] WebSocket no disponible: $status ${error ?? ""}",
						);
					}
					_disableRealtime();
				});
	}

	void _disableRealtime() {
		if (_disabled) return;
		_disabled = true;
		_teardown();
		state = false;
	}

	void _teardown() {
		_cancelDebouncers();
		final ch = _channel;
		_channel = null;
		if (ch != null) {
			unawaited(ch.unsubscribe());
		}
	}
}
