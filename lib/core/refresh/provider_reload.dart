import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../features/compras/application/compras_in_app_notifications_provider.dart";
import "../../features/compras/application/compras_panol_stock_requests_provider.dart";
import "../../features/orders/application/mantenimiento_notificaciones_provider.dart";
import "../../features/orders/application/mis_pedidos_mantenimiento_provider.dart";
import "../../features/panol/application/panol_forwarded_orders_provider.dart";
import "../../features/panol/application/panol_order_history_provider.dart";
import "../../features/panol/application/panol_seguimiento_compras_provider.dart";
import "../../features/stock/application/stock_categories_provider.dart";
import "../../features/stock/application/supervisor_stock_catalog_provider.dart";
import "../../features/supervisor/application/maintenance_orders_provider.dart";
import "../../features/supervisor/application/supervisor_maintenance_history_provider.dart";

/// Recarga de providers (botón ⟳ o evento Realtime). Sin polling automático.
abstract final class ProviderReload {
	static void maintenanceStreams(ProviderContainer container, {bool silent = false}) {
		unawaited(container.read(maintenanceOrdersProvider.notifier).refresh(silent: silent));
		unawaited(container.read(panolForwardedOrdersProvider.notifier).refresh(silent: silent));
		unawaited(container.read(misPedidosMantenimientoProvider.notifier).refresh(silent: silent));
		unawaited(container.read(mantenimientoNotificacionesProvider.notifier).refresh(silent: silent));
	}

	static void comprasNotificationStream(ProviderContainer container, {bool silent = false}) {
		unawaited(
			container.read(comprasInAppNotificationsProvider.notifier).refresh(silent: silent),
		);
	}

	static void maintenanceFutures(ProviderContainer container) {
		container.invalidate(supervisorMaintenanceHistoryProvider);
		container.read(supervisorMaintenanceHistoryProvider);
		container.invalidate(panolOrderHistoryProvider);
		container.read(panolOrderHistoryProvider);
		container.invalidate(panolSeguimientoComprasProvider);
		container.read(panolSeguimientoComprasProvider);
		container.invalidate(comprasPanolStockRequestsProvider);
		container.read(comprasPanolStockRequestsProvider);
	}

	static void stockCatalog(ProviderContainer container) {
		container.read(supervisorStockCatalogProvider.notifier).refresh();
	}

	static void stockCatalogForce(ProviderContainer container) {
		container
				.read(supervisorStockCatalogProvider.notifier)
				.refresh(showLoading: true);
	}

	static void stockCategories(ProviderContainer container) {
		container.read(stockCategoriesProvider.notifier).refresh();
	}

	static void onMaintenanceTablesChange(ProviderContainer container) {
		maintenanceFutures(container);
	}

	static void onStockTablesChange(ProviderContainer container) {
		stockCatalog(container);
		stockCategories(container);
	}
}
