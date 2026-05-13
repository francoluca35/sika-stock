import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../auth/application/auth_providers.dart";

/// Incrementa ante cambios Realtime en solicitudes Pañol→Compras y notificaciones Compras.
final comprasFlowRealtimeTickProvider =
		NotifierProvider<ComprasFlowRealtimeTickNotifier, int>(
	ComprasFlowRealtimeTickNotifier.new,
);

class ComprasFlowRealtimeTickNotifier extends Notifier<int> {
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
			"public-compras-flow-${client.auth.currentUser?.id ?? "anon"}",
		);
		_channel!
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "compras_panol_stock_requests",
					callback: (_) => _bump(),
				)
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "compras_in_app_notifications",
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
