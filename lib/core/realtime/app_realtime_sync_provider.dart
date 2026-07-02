import "dart:async";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../features/auth/application/auth_providers.dart";
import "../../features/auth/application/auth_session_provider.dart";
import "../refresh/provider_reload.dart";

/// Suscripción Realtime global: refresca solo providers que no usan `.stream()`.
final appRealtimeSyncProvider =
		NotifierProvider<AppRealtimeSyncNotifier, int>(AppRealtimeSyncNotifier.new);

class AppRealtimeSyncNotifier extends Notifier<int> {
	RealtimeChannel? _channel;
	Timer? _maintenanceDebounce;
	Timer? _stockDebounce;
	Timer? _reconnectDebounce;
	int _reconnectAttempts = 0;

	static const _debounceMs = 120;
	static const _maxReconnectDelaySec = 60;

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

	void _cancelDebouncers() {
		_maintenanceDebounce?.cancel();
		_maintenanceDebounce = null;
		_stockDebounce?.cancel();
		_stockDebounce = null;
		_reconnectDebounce?.cancel();
		_reconnectDebounce = null;
	}

	void _scheduleReconnect() {
		if (!ref.mounted || _channel == null) return;
		_reconnectDebounce?.cancel();
		final delaySec = math.min(
			_maxReconnectDelaySec,
			math.pow(2, _reconnectAttempts).toInt(),
		);
		_reconnectAttempts++;
		_reconnectDebounce = Timer(Duration(seconds: delaySec), () {
			if (!ref.mounted) return;
			final client = ref.read(supabaseClientProvider);
			final ch = _channel;
			if (ch != null) {
				unawaited(ch.unsubscribe());
			}
			_channel = null;
			if (kDebugMode) {
				debugPrint("[realtime] reintento de suscripción en ${delaySec}s");
			}
			_subscribe(client);
		});
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
		_reconnectAttempts = 0;
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
					if (status == RealtimeSubscribeStatus.subscribed) {
						_reconnectAttempts = 0;
						_reconnectDebounce?.cancel();
						_reconnectDebounce = null;
						return;
					}
					if (kDebugMode) {
						debugPrint(
							"[realtime] canal sync: $status ${error ?? ""}",
						);
					}
					if (status == RealtimeSubscribeStatus.channelError ||
							status == RealtimeSubscribeStatus.timedOut ||
							status == RealtimeSubscribeStatus.closed) {
						_scheduleReconnect();
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
