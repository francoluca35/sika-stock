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

/// Recarga inmediata de providers con keepAlive (invalidate + read / notifier.refresh).
abstract final class ProviderReload {
	/// Streams Supabase de pedidos y avisos de mantenimiento.
	static void maintenanceStreams(ProviderContainer container) {
		container.invalidate(maintenanceOrdersProvider);
		container.read(maintenanceOrdersProvider);
		container.invalidate(panolForwardedOrdersProvider);
		container.read(panolForwardedOrdersProvider);
		container.invalidate(misPedidosMantenimientoProvider);
		container.read(misPedidosMantenimientoProvider);
		container.invalidate(mantenimientoNotificacionesProvider);
		container.read(mantenimientoNotificacionesProvider);
	}

	static void comprasNotificationStream(ProviderContainer container) {
		container.invalidate(comprasInAppNotificationsProvider);
		container.read(comprasInAppNotificationsProvider);
	}

	/// Listados que no usan `.stream()` (historial, seguimiento, solicitudes).
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

	/// Cambios en `maintenance_orders` o `compras_panol_stock_requests`.
	/// Los listados con `.stream()` se actualizan solos vía Realtime de Supabase;
	/// acá solo recargamos futures (historial, seguimiento, solicitudes).
	static void onMaintenanceTablesChange(ProviderContainer container) {
		maintenanceFutures(container);
	}

	static void onStockTablesChange(ProviderContainer container) {
		stockCatalog(container);
		stockCategories(container);
	}
}
