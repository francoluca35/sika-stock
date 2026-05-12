import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../supervisor/application/maintenance_orders_realtime_provider.dart";
import "../../supervisor/application/maintenance_orders_provider.dart";
import "../../supervisor/domain/maintenance_order.dart";

/// Pedidos de mantenimiento creados por el usuario actual.
final misPedidosMantenimientoProvider =
		FutureProvider.autoDispose<List<MaintenanceOrder>>((ref) async {
	ref.watch(maintenanceOrdersRealtimeTickProvider);
	final repo = ref.watch(maintenanceOrdersRepositoryProvider);
	return repo.fetchMine();
});
