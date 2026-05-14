import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../../auth/application/auth_session_provider.dart";
import "../../supervisor/application/maintenance_orders_provider.dart";
import "../../supervisor/domain/maintenance_order.dart";

/// Pedidos de mantenimiento creados por el usuario actual (stream Realtime).
final misPedidosMantenimientoProvider =
		StreamProvider<List<MaintenanceOrder>>((ref) {
	ref.keepAlive();
	final session = ref.watch(authSessionProvider);
	if (session == null) {
		return Stream.value(const []);
	}
	final uid = session.user.id;
	final client = ref.watch(supabaseClientProvider);
	return client
			.from("maintenance_orders")
			.stream(primaryKey: ["id"])
			.eq("created_by", uid)
			.order("created_at", ascending: false)
			.map(
				(rows) => rows
						.map(
							(m) => MaintenanceOrder.fromJson(
								Map<String, dynamic>.from(m),
							),
						)
						.toList(),
			);
});
