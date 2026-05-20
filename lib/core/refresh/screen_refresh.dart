import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../features/auth/application/auth_providers.dart";
import "../../features/compras/application/compras_panol_stock_requests_provider.dart";
import "../../features/orders/application/mantenimiento_notificaciones_provider.dart";
import "../../features/orders/application/mis_pedidos_mantenimiento_provider.dart";
import "../../features/panol/application/panol_order_history_provider.dart";
import "../../features/panol/application/panol_seguimiento_compras_provider.dart";
import "../../features/supervisor/application/supervisor_maintenance_history_provider.dart";
import "provider_reload.dart";

/// Recarga manual (botón ⟳). Complementa Realtime en [app_realtime_sync_provider].
abstract final class ScreenRefresh {
	static ProviderContainer _c(WidgetRef ref) =>
			ProviderScope.containerOf(ref.context);

	static void pedidosSupervisor(WidgetRef ref) {
		final c = _c(ref);
		ProviderReload.maintenanceStreams(c);
		ProviderReload.stockCatalog(c);
	}

	static void historialMantenimiento(WidgetRef ref) {
		final c = _c(ref);
		c.invalidate(supervisorMaintenanceHistoryProvider);
		c.read(supervisorMaintenanceHistoryProvider);
	}

	static void stock(WidgetRef ref) {
		ProviderReload.stockAll(_c(ref));
	}

	static void pedidosPanol(WidgetRef ref) {
		final c = _c(ref);
		ProviderReload.maintenanceStreams(c);
		ProviderReload.stockCatalog(c);
		c.invalidate(panolOrderHistoryProvider);
		c.read(panolOrderHistoryProvider);
		c.invalidate(comprasPanolStockRequestsProvider);
		c.read(comprasPanolStockRequestsProvider);
	}

	static void seguimiento(WidgetRef ref) {
		final c = _c(ref);
		c.invalidate(panolSeguimientoComprasProvider);
		c.read(panolSeguimientoComprasProvider);
		c.invalidate(comprasPanolStockRequestsProvider);
		c.read(comprasPanolStockRequestsProvider);
	}

	static void compras(WidgetRef ref) {
		final c = _c(ref);
		ProviderReload.maintenanceFutures(c);
		ProviderReload.comprasNotificationStream(c);
		c.invalidate(mantenimientoNotificacionesProvider);
		c.read(mantenimientoNotificacionesProvider);
	}

	static void misPedidos(WidgetRef ref) {
		final c = _c(ref);
		c.invalidate(misPedidosMantenimientoProvider);
		c.read(misPedidosMantenimientoProvider);
		c.invalidate(mantenimientoNotificacionesProvider);
		c.read(mantenimientoNotificacionesProvider);
	}

	static void supervisorHome(WidgetRef ref) {
		pedidosSupervisor(ref);
		historialMantenimiento(ref);
	}

	static void panolHome(WidgetRef ref) {
		pedidosPanol(ref);
		seguimiento(ref);
		stock(ref);
	}

	static void mantenimientoHome(WidgetRef ref) {
		misPedidos(ref);
	}

	static void comprasHome(WidgetRef ref) {
		compras(ref);
	}

	static void adminHome(WidgetRef ref) {
		pedidosSupervisor(ref);
		historialMantenimiento(ref);
		compras(ref);
		stock(ref);
	}

	static void all(WidgetRef ref) {
		final c = _c(ref);
		supervisorHome(ref);
		panolHome(ref);
		mantenimientoHome(ref);
		comprasHome(ref);
		c.invalidate(currentProfileProvider);
		c.read(currentProfileProvider);
	}
}
