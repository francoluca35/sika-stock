import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../../auth/application/auth_session_provider.dart";
import "../../supervisor/domain/maintenance_order.dart";

const _panolForwardedStatuses = {
	MaintenanceWorkflowStatus.forwardedToPanol,
	MaintenanceWorkflowStatus.panolRequestedCompras,
	MaintenanceWorkflowStatus.comprasOcNotified,
	MaintenanceWorkflowStatus.comprasPurchaseDone,
	MaintenanceWorkflowStatus.comprasArrivedNotified,
	MaintenanceWorkflowStatus.supervisorStockOk,
};

/// Consultas enviadas a pañol (stream Realtime).
final panolForwardedOrdersProvider =
		StreamProvider<List<MaintenanceOrder>>((ref) {
	ref.keepAlive();
	final session = ref.watch(authSessionProvider);
	if (session == null) {
		return Stream.value(const []);
	}
	final client = ref.watch(supabaseClientProvider);
	return client
			.from("maintenance_orders")
			.stream(primaryKey: ["id"])
			.order("created_at", ascending: false)
			.map(
				(rows) => rows
						.map(
							(m) => MaintenanceOrder.fromJson(
								Map<String, dynamic>.from(m),
							),
						)
						.where((o) => _panolForwardedStatuses.contains(o.workflowStatus))
						.toList(),
			);
});
