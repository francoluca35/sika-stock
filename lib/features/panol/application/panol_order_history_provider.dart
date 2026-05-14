import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/realtime/realtime_refresh.dart";
import "../../supervisor/application/maintenance_orders_provider.dart";
import "../../supervisor/application/maintenance_orders_realtime_provider.dart";
import "../../supervisor/domain/completed_maintenance_record.dart";

/// Historial de pedidos vistos por pañol (completados / cancelados).
final panolOrderHistoryProvider =
		FutureProvider<List<CompletedMaintenanceRecord>>((ref) async {
	ref.keepAlive();
	bindRealtimeTickRefresh(
		ref,
		maintenanceOrdersRealtimeTickProvider,
		() => ref.invalidateSelf(),
	);
	ref.watch(maintenanceOrdersRealtimeTickProvider);
	final repo = ref.watch(maintenanceOrdersRepositoryProvider);
	final rows = await repo.fetchPanolOrderHistory();
	return rows.map(CompletedMaintenanceRecord.fromOrder).toList();
});
