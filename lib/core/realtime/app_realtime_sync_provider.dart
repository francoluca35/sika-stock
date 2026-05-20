import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../features/auth/application/auth_providers.dart";
import "../../features/auth/application/auth_session_provider.dart";
import "../refresh/provider_reload.dart";

/// Suscripción Realtime global: refresca streams y futures al detectar cambios en Postgres.
final appRealtimeSyncProvider =
		NotifierProvider<AppRealtimeSyncNotifier, int>(AppRealtimeSyncNotifier.new);

class AppRealtimeSyncNotifier extends Notifier<int> {
	RealtimeChannel? _channel;
	Timer? _maintenanceDebounce;
	Timer? _stockDebounce;
	Timer? _maintNotifDebounce;
	Timer? _comprasNotifDebounce;

	static const _debounceMs = 120;

	void _runIfMounted(void Function(ProviderContainer container) action) {
		if (!ref.mounted) return;
		action(ref.container);
	}

	void _scheduleMaintenanceReload() {
		_maintenanceDebounce?.cancel();
		_maintenanceDebounce = Timer(
			const Duration(milliseconds: _debounceMs),
			() => _runIfMounted(ProviderReload.onMaintenanceTablesChange),
		);
	}

	void _scheduleStockReload() {
		_stockDebounce?.cancel();
		_stockDebounce = Timer(
			const Duration(milliseconds: _debounceMs),
			() => _runIfMounted(ProviderReload.onStockTablesChange),
		);
	}

	void _scheduleMaintNotifReload() {
		_maintNotifDebounce?.cancel();
		_maintNotifDebounce = Timer(
			const Duration(milliseconds: _debounceMs),
			() => _runIfMounted(ProviderReload.onMaintenanceNotificationsChange),
		);
	}

	void _scheduleComprasNotifReload() {
		_comprasNotifDebounce?.cancel();
		_comprasNotifDebounce = Timer(
			const Duration(milliseconds: _debounceMs),
			() => _runIfMounted(ProviderReload.onComprasNotificationsChange),
		);
	}

	void _cancelDebouncers() {
		_maintenanceDebounce?.cancel();
		_maintenanceDebounce = null;
		_stockDebounce?.cancel();
		_stockDebounce = null;
		_maintNotifDebounce?.cancel();
		_maintNotifDebounce = null;
		_comprasNotifDebounce?.cancel();
		_comprasNotifDebounce = null;
	}

	@override
	int build() {
		ref.keepAlive();
		final session = ref.watch(authSessionProvider);
		if (session == null) {
			_teardown();
			return 0;
		}
		final client = ref.watch(supabaseClientProvider);
		_teardown();
		_subscribe(client);
		ref.onDispose(_teardown);
		return 0;
	}

	void _subscribe(SupabaseClient client) {
		final uid = client.auth.currentUser?.id ?? "anon";
		_channel = client.channel("app-realtime-sync-$uid");
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
					callback: (_) => _scheduleMaintNotifReload(),
				)
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "compras_in_app_notifications",
					callback: (_) => _scheduleComprasNotifReload(),
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
					if (status == RealtimeSubscribeStatus.subscribed) return;
					if (kDebugMode) {
						debugPrint(
							"[realtime] canal sync: $status ${error ?? ""}",
						);
					}
					if (status == RealtimeSubscribeStatus.channelError ||
							status == RealtimeSubscribeStatus.timedOut ||
							status == RealtimeSubscribeStatus.closed) {
						// Reconectar: invalidar este notifier recrea el canal.
						ref.invalidateSelf();
					}
				});
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
