import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_session_provider.dart";
import "../../supervisor/application/maintenance_orders_provider.dart";
import "../../supervisor/domain/maintenance_order_notification_row.dart";

/// Avisos del flujo de pedidos (HTTP; actualización manual o Realtime global).
final mantenimientoNotificacionesProvider =
		AsyncNotifierProvider<MantenimientoNotificacionesNotifier,
				List<MaintenanceOrderNotificationRow>>(
	MantenimientoNotificacionesNotifier.new,
);

class MantenimientoNotificacionesNotifier
		extends AsyncNotifier<List<MaintenanceOrderNotificationRow>> {
	@override
	Future<List<MaintenanceOrderNotificationRow>> build() async {
		ref.keepAlive();
		final session = ref.watch(authSessionProvider);
		if (session == null) return const [];
		return ref.read(maintenanceOrdersRepositoryProvider).fetchMyNotifications();
	}

	Future<void> refresh({bool silent = false}) async {
		if (!silent) {
			state = const AsyncValue.loading();
		}
		state = await AsyncValue.guard(() async {
			final session = ref.read(authSessionProvider);
			if (session == null) return const <MaintenanceOrderNotificationRow>[];
			return ref.read(maintenanceOrdersRepositoryProvider).fetchMyNotifications();
		});
	}
}
