import "package:flutter_riverpod/flutter_riverpod.dart";

import "../domain/maintenance_product_request.dart";

/// Pedidos «pedir producto» del usuario mantenimiento (demo → Supabase).
final maintenanceMyRequestsProvider =
		NotifierProvider<MaintenanceMyRequestsNotifier, List<MaintenanceProductRequest>>(
	MaintenanceMyRequestsNotifier.new,
);

class MaintenanceMyRequestsNotifier extends Notifier<List<MaintenanceProductRequest>> {
	@override
	List<MaintenanceProductRequest> build() => [];

	void registrar(MaintenanceProductRequest r) {
		state = [...state, r];
	}
}
