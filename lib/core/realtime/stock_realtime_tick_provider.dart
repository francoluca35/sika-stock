import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../features/auth/application/auth_providers.dart";
import "../../features/auth/application/auth_session_provider.dart";

/// Tick ante cambios en inventario y categorías.
final stockRealtimeTickProvider =
		NotifierProvider<StockRealtimeTickNotifier, int>(StockRealtimeTickNotifier.new);

class StockRealtimeTickNotifier extends Notifier<int> {
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
		final session = ref.watch(authSessionProvider);
		if (session == null) {
			_unsubscribe();
			return 0;
		}
		final client = ref.watch(supabaseClientProvider);
		_unsubscribe();
		_channel = client.channel(
			"public-stock-${client.auth.currentUser?.id ?? "anon"}",
		);
		_channel!
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "stock_items",
					callback: (_) => _bump(),
				)
				.onPostgresChanges(
					event: PostgresChangeEvent.all,
					schema: "public",
					table: "stock_categories",
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
