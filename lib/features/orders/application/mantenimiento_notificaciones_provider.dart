import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../supervisor/application/maintenance_orders_provider.dart";
import "../../supervisor/application/maintenance_orders_realtime_provider.dart";
import "../../supervisor/domain/maintenance_order_notification_row.dart";

/// Avisos del flujo de pedidos (stock OK / derivado a pañol) para el usuario actual.
final mantenimientoNotificacionesProvider =
		FutureProvider.autoDispose<List<MaintenanceOrderNotificationRow>>((ref) async {
	ref.watch(maintenanceOrdersRealtimeTickProvider);
	final repo = ref.watch(maintenanceOrdersRepositoryProvider);
	return repo.fetchMyNotifications();
});
