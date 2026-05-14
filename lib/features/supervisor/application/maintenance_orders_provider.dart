import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../../auth/application/auth_session_provider.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../data/maintenance_orders_repository.dart";
import "../domain/maintenance_order.dart";
import "supervisor_maintenance_history_provider.dart";

final maintenanceOrdersRepositoryProvider = Provider<MaintenanceOrdersRepository>(
	(ref) => MaintenanceOrdersRepository(ref.watch(supabaseClientProvider)),
);

const _supervisorActiveStatuses = {
	MaintenanceWorkflowStatus.pendingSupervisor,
	MaintenanceWorkflowStatus.supervisorStockOk,
	MaintenanceWorkflowStatus.comprasArrivedNotified,
};

List<MaintenanceOrder> _mapSupervisorActiveRows(List<Map<String, dynamic>> rows) {
	return rows
			.map((m) => MaintenanceOrder.fromJson(Map<String, dynamic>.from(m)))
			.where((o) => _supervisorActiveStatuses.contains(o.workflowStatus))
			.toList();
}

/// Pedidos activos para supervisor (stream Supabase + Realtime).
final maintenanceOrdersProvider =
		StreamNotifierProvider<MaintenanceOrdersNotifier, List<MaintenanceOrder>>(
	MaintenanceOrdersNotifier.new,
);

class MaintenanceOrdersNotifier extends StreamNotifier<List<MaintenanceOrder>> {
	@override
	Stream<List<MaintenanceOrder>> build() {
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
				.map(_mapSupervisorActiveRows);
	}

	Future<void> supervisorDecideStock({
		required String orderId,
		required bool hayStock,
		String? stockItemId,
	}) async {
		final repo = ref.read(maintenanceOrdersRepositoryProvider);
		await repo.supervisorDecideStock(
			orderId: orderId,
			hayStock: hayStock,
			stockItemId: stockItemId,
		);
		if (hayStock && stockItemId != null && stockItemId.isNotEmpty) {
			ref.invalidate(supervisorStockCatalogProvider);
		}
		ref.invalidate(supervisorMaintenanceHistoryProvider);
	}

	Future<void> supervisorCreateFromCatalogAndDecide({
		required String solicitanteDisplay,
		required String productName,
		required int quantity,
		required String productType,
		required String priority,
		required String destination,
		required bool hayStock,
		String? stockItemId,
	}) async {
		final repo = ref.read(maintenanceOrdersRepositoryProvider);
		final id = await repo.createOrderReturningId(
			solicitanteDisplay: solicitanteDisplay,
			productName: productName,
			quantity: quantity,
			productType: productType,
			priority: priority,
			destination: destination,
		);
		await supervisorDecideStock(
			orderId: id,
			hayStock: hayStock,
			stockItemId: hayStock ? stockItemId : null,
		);
	}

	Future<void> registrarRetiro(String orderId) async {
		final list = state.value;
		if (list == null) return;
		final exists = list.any((o) => o.id == orderId);
		if (!exists) return;
		await ref.read(maintenanceOrdersRepositoryProvider).markCompleted(orderId);
		ref.invalidate(supervisorStockCatalogProvider);
		ref.invalidate(supervisorMaintenanceHistoryProvider);
	}
}

/// Cantidad de pedidos en **pending_supervisor**.
final supervisorPendingMaintenanceBadgeProvider = Provider<int>((ref) {
	final async = ref.watch(maintenanceOrdersProvider);
	return async.maybeWhen(
		data: (list) => list
				.where(
					(o) =>
							o.workflowStatus ==
							MaintenanceWorkflowStatus.pendingSupervisor,
				)
				.length,
		orElse: () => 0,
	);
});
