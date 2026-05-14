import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/realtime/realtime_refresh.dart";
import "../../auth/application/auth_providers.dart";
import "../data/maintenance_orders_repository.dart";
import "../domain/completed_maintenance_record.dart";
import "maintenance_orders_realtime_provider.dart";

/// Historial real del supervisor: entregados, en consulta con pañol y cancelados.
final supervisorMaintenanceHistoryProvider =
		FutureProvider<List<CompletedMaintenanceRecord>>((ref) async {
	ref.keepAlive();
	bindRealtimeTickRefresh(
		ref,
		maintenanceOrdersRealtimeTickProvider,
		() => ref.invalidateSelf(),
	);
	ref.watch(maintenanceOrdersRealtimeTickProvider);
	final client = ref.watch(supabaseClientProvider);
	final repo = MaintenanceOrdersRepository(client);
	final rows = await repo.fetchSupervisorHistory();
	return rows.map(CompletedMaintenanceRecord.fromOrder).toList();
});
