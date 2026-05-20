import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../../auth/application/auth_session_provider.dart";
import "../../orders/application/mantenimiento_notificaciones_provider.dart";
import "../../panol/application/panol_forwarded_orders_provider.dart";
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
		_afterWorkflowChange();
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
		if (hayStock) {
			await ref.read(maintenanceOrdersRepositoryProvider).markCompleted(id);
			_afterRetiroInventoryChange();
		}
	}

	Future<void> registrarRetiro(String orderId) async {
		final list = state.value;
		if (list == null) return;
		final exists = list.any((o) => o.id == orderId);
		if (!exists) return;
		await ref.read(maintenanceOrdersRepositoryProvider).markCompleted(orderId);
		_afterRetiroInventoryChange();
	}

	/// Un solo RETIRO OK: avisa (supervisor_stock_ok) + historial (completed) + un descuento.
	Future<void> confirmarRetiroOk({
		required MaintenanceOrder order,
		String? stockItemId,
	}) async {
		final repo = ref.read(maintenanceOrdersRepositoryProvider);
		switch (order.workflowStatus) {
			case MaintenanceWorkflowStatus.pendingSupervisor:
				final sid = stockItemId?.trim();
				if (sid == null || sid.isEmpty) {
					throw Exception(
						"Elegí una línea del catálogo (ELEGIR) antes de RETIRO OK.",
					);
				}
				await repo.supervisorDecideStock(
					orderId: order.id,
					hayStock: true,
					stockItemId: sid,
				);
				await repo.markCompleted(order.id);
			case MaintenanceWorkflowStatus.supervisorStockOk:
			case MaintenanceWorkflowStatus.comprasArrivedNotified:
				final sidOk = stockItemId?.trim();
				await repo.markCompleted(
					order.id,
					stockItemId: sidOk != null && sidOk.isNotEmpty ? sidOk : null,
				);
			default:
				throw Exception("Este pedido no admite RETIRO OK en su estado actual.");
		}
		_afterRetiroInventoryChange();
	}

	void _afterRetiroInventoryChange() {
		ref.invalidate(supervisorStockCatalogProvider);
		_afterWorkflowChange();
	}

	/// Pedido sale de «activos» y el historial debe mostrar el registro nuevo.
	void _afterWorkflowChange() {
		ref.invalidate(maintenanceOrdersProvider);
		ref.read(maintenanceOrdersProvider);
		ref.invalidate(supervisorMaintenanceHistoryProvider);
		ref.read(supervisorMaintenanceHistoryProvider);
		ref.invalidate(panolForwardedOrdersProvider);
		ref.read(panolForwardedOrdersProvider);
		ref.invalidate(mantenimientoNotificacionesProvider);
		ref.read(mantenimientoNotificacionesProvider);
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
