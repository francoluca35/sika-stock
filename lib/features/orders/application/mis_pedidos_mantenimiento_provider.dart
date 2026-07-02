import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_session_provider.dart";
import "../../supervisor/application/maintenance_orders_provider.dart";
import "../../supervisor/domain/maintenance_order.dart";

/// Pedidos de mantenimiento del usuario actual (HTTP; actualización manual o Realtime global).
final misPedidosMantenimientoProvider =
		AsyncNotifierProvider<MisPedidosMantenimientoNotifier, List<MaintenanceOrder>>(
	MisPedidosMantenimientoNotifier.new,
);

class MisPedidosMantenimientoNotifier extends AsyncNotifier<List<MaintenanceOrder>> {
	@override
	Future<List<MaintenanceOrder>> build() async {
		ref.keepAlive();
		final session = ref.watch(authSessionProvider);
		if (session == null) return const [];
		return ref.read(maintenanceOrdersRepositoryProvider).fetchMine();
	}

	Future<void> refresh({bool silent = false}) async {
		if (!silent) {
			state = const AsyncValue.loading();
		}
		state = await AsyncValue.guard(() async {
			final session = ref.read(authSessionProvider);
			if (session == null) return const <MaintenanceOrder>[];
			return ref.read(maintenanceOrdersRepositoryProvider).fetchMine();
		});
	}
}
