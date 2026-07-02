import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../features/auth/application/auth_providers.dart";
import "../../features/auth/application/auth_session_provider.dart";
import "../../features/compras/application/compras_in_app_notifications_provider.dart";
import "../../features/orders/application/mantenimiento_notificaciones_provider.dart";
import "../../features/orders/application/mis_pedidos_mantenimiento_provider.dart";
import "../../features/panol/application/panol_forwarded_orders_provider.dart";
import "../../features/supervisor/application/maintenance_orders_provider.dart";
import "../refresh/provider_reload.dart";

/// `true` si el único canal Realtime está activo en esta sesión.
final appRealtimeSyncProvider =
		NotifierProvider<AppRealtimeSyncNotifier, bool>(AppRealtimeSyncNotifier.new);

/// Un solo canal WebSocket. Si falla, se desactiva sin reintentos (evita polling/reload).
class AppRealtimeSyncNotifier extends Notifier<bool> {
	RealtimeChannel? _channel;
	Timer? _maintenanceDebounce;
	Timer? _stockDebounce;
	bool _disabled = false;
	bool _connecting = false;

	static const _debounceMs = 300;

	void _silentRefreshAll() {
		if (!ref.mounted || _disabled) return;
		final c = ref.container;
		unawaited(c.read(maintenanceOrdersProvider.notifier).refresh(silent: true));
		unawaited(c.read(panolForwardedOrdersProvider.notifier).refresh(silent: true));
		unawaited(c.read(misPedidosMantenimientoProvider.notifier).refresh(silent: true));
		unawaited(c.read(mantenimientoNotificacionesProvider.notifier).refresh(silent: true));
		unawaited(c.read(comprasInAppNotificationsProvider.notifier).refresh(silent: true));
		ProviderReload.onMaintenanceTablesChange(c);
	}

	void _scheduleMaintenanceReload() {
		_maintenanceDebounce?.cancel();
		_maintenanceDebounce = Timer(
			const Duration(milliseconds: _debounceMs),
			_silentRefreshAll,
		);
	}

	void _scheduleStockReload() {
		_stockDebounce?.cancel();
		_stockDebounce = Timer(
			const Duration(milliseconds: _debounceMs),
			() {
				if (!ref.mounted || _disabled) return;
				ProviderReload.onStockTablesChange(ref.container);
			},
		);
	}

	void _cancelDebouncers() {
		_maintenanceDebounce?.cancel();
		_maintenanceDebounce = null;
		_stockDebounce?.cancel();
		_stockDebounce = null;
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
					callback: (_) => _scheduleMaintenanceReload(),
				)
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "compras_panol_stock_requests",
					callback: (_) => _scheduleMaintenanceReload(),
				)
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "maintenance_order_notifications",
					callback: (_) => _scheduleMaintenanceReload(),
				)
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "compras_in_app_notifications",
					callback: (_) => _scheduleMaintenanceReload(),
				)
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "stock_items",
					callback: (_) => _scheduleStockReload(),
				)
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "stock_categories",
					callback: (_) => _scheduleStockReload(),
				)
				.subscribe((status, [error]) {
					_connecting = false;
					if (status == RealtimeSubscribeStatus.subscribed) {
						if (kDebugMode) {
							debugPrint("[live-sync] WebSocket conectado");
						}
						state = true;
						return;
					}
					if (kDebugMode) {
						debugPrint("[live-sync] WebSocket no disponible: $status ${error ?? ""}");
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
