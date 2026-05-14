import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../../auth/application/auth_session_provider.dart";
import "../../supervisor/application/maintenance_orders_provider.dart";
import "../../supervisor/domain/maintenance_order_notification_row.dart";

/// Avisos del flujo de pedidos para el usuario actual (stream Realtime).
final mantenimientoNotificacionesProvider =
		StreamProvider<List<MaintenanceOrderNotificationRow>>((ref) {
	ref.keepAlive();
	final session = ref.watch(authSessionProvider);
	if (session == null) {
		return Stream.value(const []);
	}
	final uid = session.user.id;
	final client = ref.watch(supabaseClientProvider);
	return client
			.from("maintenance_order_notifications")
			.stream(primaryKey: ["id"])
			.eq("user_id", uid)
			.order("created_at", ascending: false)
			.map(
				(rows) => rows
						.map(
							(m) => MaintenanceOrderNotificationRow.fromJson(
								Map<String, dynamic>.from(m),
							),
						)
						.toList(),
			);
});
