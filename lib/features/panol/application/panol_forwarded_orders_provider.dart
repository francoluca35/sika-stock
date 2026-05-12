import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../supervisor/application/maintenance_orders_realtime_provider.dart";
import "../../supervisor/application/maintenance_orders_provider.dart";
import "../../supervisor/domain/maintenance_order.dart";

/// Consultas enviadas a pañol cuando el supervisor indica que no hay stock.
final panolForwardedOrdersProvider =
		FutureProvider.autoDispose<List<MaintenanceOrder>>((ref) async {
	ref.watch(maintenanceOrdersRealtimeTickProvider);
	final repo = ref.watch(maintenanceOrdersRepositoryProvider);
	return repo.fetchForwardedForPanol();
});
