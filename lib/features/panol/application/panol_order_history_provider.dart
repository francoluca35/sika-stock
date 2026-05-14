import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../supervisor/application/maintenance_orders_provider.dart";
import "../../supervisor/domain/completed_maintenance_record.dart";

/// Historial de pedidos vistos por pañol (completados / cancelados).
final panolOrderHistoryProvider =
		FutureProvider<List<CompletedMaintenanceRecord>>((ref) async {
	ref.keepAlive();
	final repo = ref.watch(maintenanceOrdersRepositoryProvider);
	final rows = await repo.fetchPanolOrderHistory();
	return rows.map(CompletedMaintenanceRecord.fromOrder).toList();
});
