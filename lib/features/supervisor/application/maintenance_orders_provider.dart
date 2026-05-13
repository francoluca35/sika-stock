import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../data/maintenance_orders_repository.dart";
import "../domain/maintenance_order.dart";
import "maintenance_orders_realtime_provider.dart";
import "supervisor_maintenance_history_provider.dart";

final maintenanceOrdersRepositoryProvider = Provider<MaintenanceOrdersRepository>(
	(ref) => MaintenanceOrdersRepository(ref.watch(supabaseClientProvider)),
);

/// Pedidos activos para supervisor: esperando decisión o con stock confirmado.
final maintenanceOrdersProvider =
		AsyncNotifierProvider<MaintenanceOrdersNotifier, List<MaintenanceOrder>>(
	MaintenanceOrdersNotifier.new,
);

class MaintenanceOrdersNotifier extends AsyncNotifier<List<MaintenanceOrder>> {
	@override
	Future<List<MaintenanceOrder>> build() {
		ref.watch(maintenanceOrdersRealtimeTickProvider);
		return ref.read(maintenanceOrdersRepositoryProvider).fetchSupervisorActive();
	}

	Future<void> refresh() async {
		state = const AsyncValue.loading();
		state = await AsyncValue.guard(
			() => ref.read(maintenanceOrdersRepositoryProvider).fetchSupervisorActive(),
		);
	}

	Future<void> supervisorDecideStock({
		required String orderId,
		required bool hayStock,
		String? stockItemId,
	}) async {
		final list = state.value;
		MaintenanceOrder? orden;
		if (list != null) {
			for (final o in list) {
				if (o.id == orderId) {
					orden = o;
					break;
				}
			}
		}
		final repo = ref.read(maintenanceOrdersRepositoryProvider);
		orden ??= await repo.fetchOrderById(orderId);
		await repo.supervisorDecideStock(
			orderId: orderId,
			hayStock: hayStock,
			stockItemId: stockItemId,
		);
		final selfId = ref.read(supabaseClientProvider).auth.currentUser?.id;
		final destinatario = orden?.createdBy;
		if (destinatario != null &&
				destinatario.isNotEmpty &&
				destinatario != selfId) {
			try {
				await repo.insertOrderNotification(
					userId: destinatario,
					orderId: orderId,
					kind: hayStock ? "stock_ok_retiro" : "derivado_panol",
					title: hayStock ? "Podés retirar el pedido" : "Pedido en gestión con pañol",
					body: hayStock
							? "${orden!.numeroOrden}: stock disponible en inventario. Pasá a retirar cuando puedas."
							: "${orden!.numeroOrden}: no hay stock suficiente en depósito automático. Pañol lo gestionará; estará disponible a la brevedad.",
				);
			} catch (_) {
				// No bloquear el flujo si la tabla de avisos aún no existe en el proyecto remoto.
			}
		}
		if (hayStock &&
				stockItemId != null &&
				stockItemId.isNotEmpty) {
			ref.invalidate(supervisorStockCatalogProvider);
		}
		ref.invalidate(supervisorMaintenanceHistoryProvider);
		await refresh();
	}

	/// Alta desde catálogo (supervisor) y decisión inmediata: retiro con stock o derivación a pañol.
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

	/// Cierra pedido con stock ya confirmado (retiro en planta).
	Future<void> registrarRetiro(String orderId) async {
		final list = state.value;
		if (list == null) return;
		MaintenanceOrder? orden;
		for (final o in list) {
			if (o.id == orderId) {
				orden = o;
				break;
			}
		}
		if (orden == null) return;
		await ref.read(maintenanceOrdersRepositoryProvider).markCompleted(orderId);
		ref.invalidate(supervisorStockCatalogProvider);
		ref.invalidate(supervisorMaintenanceHistoryProvider);
		await refresh();
	}
}

/// Cantidad de pedidos en **pending_supervisor** (pendientes de decisión del supervisor).
/// Sigue en tiempo real a [maintenanceOrdersProvider] (tick Realtime).
final supervisorPendingMaintenanceBadgeProvider = Provider<int>((ref) {
	final async = ref.watch(maintenanceOrdersProvider);
	return async.maybeWhen(
		data: (list) => list
			.where(
				(o) => o.workflowStatus == MaintenanceWorkflowStatus.pendingSupervisor,
			)
			.length,
		orElse: () => 0,
	);
});
