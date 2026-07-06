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

/// Pedidos activos para supervisor (HTTP; actualización manual o Realtime global).
final maintenanceOrdersProvider =
		AsyncNotifierProvider<MaintenanceOrdersNotifier, List<MaintenanceOrder>>(
	MaintenanceOrdersNotifier.new,
);

class MaintenanceOrdersNotifier extends AsyncNotifier<List<MaintenanceOrder>> {
	@override
	Future<List<MaintenanceOrder>> build() async {
		ref.keepAlive();
		final session = ref.watch(authSessionProvider);
		if (session == null) return const [];
		return ref.read(maintenanceOrdersRepositoryProvider).fetchSupervisorActive();
	}

	Future<void> refresh({bool silent = false}) async {
		if (!silent) {
			state = const AsyncValue.loading();
		}
		state = await AsyncValue.guard(() async {
			final session = ref.read(authSessionProvider);
			if (session == null) return const <MaintenanceOrder>[];
			return ref.read(maintenanceOrdersRepositoryProvider).fetchSupervisorActive();
		});
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
			ref.read(supervisorStockCatalogProvider.notifier).refresh();
		}
		await _afterWorkflowChange();
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
		await _afterRetiroInventoryChange();
	}

	Future<void> confirmarRetiroOk({
		required MaintenanceOrder order,
		String? stockItemId,
	}) async {
		if (order.workflowStatus != MaintenanceWorkflowStatus.pendingSupervisor) {
			throw Exception(
				"El retiro físico y el descuento de stock los registra pañol.",
			);
		}
		final sid = stockItemId?.trim();
		if (sid == null || sid.isEmpty) {
			throw Exception(
				"Elegí una línea del catálogo (ELEGIR) antes de RETIRO OK.",
			);
		}
		await ref.read(maintenanceOrdersRepositoryProvider).supervisorDecideStock(
					orderId: order.id,
					hayStock: true,
					stockItemId: sid,
				);
		await _afterWorkflowChange();
	}

	Future<void> _afterRetiroInventoryChange() async {
		ref.read(supervisorStockCatalogProvider.notifier).refresh();
		await _afterWorkflowChange();
	}

	Future<void> cancelOrder({
		required String orderId,
		required String observacion,
	}) async {
		await ref.read(maintenanceOrdersRepositoryProvider).cancelOrder(
					orderId: orderId,
					observacion: observacion,
				);
		await _afterWorkflowChange();
	}

	Future<void> _afterWorkflowChange() async {
		await refresh(silent: true);
		ref.invalidate(supervisorMaintenanceHistoryProvider);
		ref.read(supervisorMaintenanceHistoryProvider);
	}
}

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
