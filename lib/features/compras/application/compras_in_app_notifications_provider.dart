import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../../auth/application/auth_session_provider.dart";
import "../domain/compras_in_app_notification_row.dart";

/// Notificaciones in-app de Compras (stream Realtime).
final comprasInAppNotificationsProvider =
		StreamProvider<List<ComprasInAppNotificationRow>>((ref) {
	ref.keepAlive();
	final session = ref.watch(authSessionProvider);
	if (session == null) {
		return Stream.value(const []);
	}
	final uid = session.user.id;
	final client = ref.watch(supabaseClientProvider);
	return client
			.from("compras_in_app_notifications")
			.stream(primaryKey: ["id"])
			.eq("user_id", uid)
			.order("created_at", ascending: false)
			.map(
				(rows) => rows
						.map(
							(m) => ComprasInAppNotificationRow.fromJson(
								Map<String, dynamic>.from(m),
							),
						)
						.toList(),
			);
});
