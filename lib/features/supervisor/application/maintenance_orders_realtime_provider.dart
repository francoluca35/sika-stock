import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../auth/application/auth_providers.dart";

/// Contador que incrementa ante cambios Realtime en pedidos o notificaciones del flujo mantenimiento.
///
/// [ref.watch] en listados para volver a consultar sin polling.
final maintenanceOrdersRealtimeTickProvider =
		NotifierProvider<MaintenanceOrdersRealtimeTickNotifier, int>(
	MaintenanceOrdersRealtimeTickNotifier.new,
);

class MaintenanceOrdersRealtimeTickNotifier extends Notifier<int> {
	RealtimeChannel? _channel;

	void _bump() {
		Future.microtask(() {
			if (!ref.mounted) return;
			state++;
		});
	}

	@override
	int build() {
		ref.keepAlive();
		final client = ref.watch(supabaseClientProvider);
		_unsubscribe();
		_channel = client.channel(
			"public-maint-flow-${client.auth.currentUser?.id ?? "anon"}",
		);
		_channel!
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "maintenance_orders",
					callback: (_) => _bump(),
				)
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "maintenance_order_notifications",
					callback: (_) => _bump(),
				)
				.subscribe();
		ref.onDispose(_unsubscribe);
		return 0;
	}

	void _unsubscribe() {
		final ch = _channel;
		_channel = null;
		if (ch != null) {
			unawaited(ch.unsubscribe());
		}
	}
}
