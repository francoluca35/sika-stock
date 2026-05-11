import "package:flutter_riverpod/flutter_riverpod.dart";

import "../domain/completed_maintenance_record.dart";
import "../domain/maintenance_order.dart";

/// Pedidos de mantenimiento ya cerrados (retiro, etc.) — demo en memoria → Supabase.
final maintenanceHistoryProvider =
		NotifierProvider<MaintenanceHistoryNotifier, List<CompletedMaintenanceRecord>>(
	MaintenanceHistoryNotifier.new,
);

class MaintenanceHistoryNotifier extends Notifier<List<CompletedMaintenanceRecord>> {
	static List<CompletedMaintenanceRecord> _demoSeed() => [
				CompletedMaintenanceRecord(
					id: "hist-demo-1",
					pedido: MaintenanceOrder(
						id: "4",
						numeroOrden: "ORD-0004",
						fechaPedido: DateTime(2024, 5, 18, 16, 0),
						producto: "CILINDRO NEUMÁTICO",
						estado: MaintenanceOrderStatus.completado,
						solicitante: "Ana Gómez — Logística",
						motivo: "Fuga en vástago detectada en inspección de rutina.",
						imagenUrl: "https://picsum.photos/seed/maint4/900/500",
					),
					fechaCierre: DateTime(2024, 5, 19, 10, 15),
					motivoCierre: "Completado por retiro de stock",
				),
			];

	@override
	List<CompletedMaintenanceRecord> build() => List<CompletedMaintenanceRecord>.from(_demoSeed());

	void registrarRetiro(MaintenanceOrder ordenActiva) {
		final record = CompletedMaintenanceRecord(
			id: "${ordenActiva.id}-${DateTime.now().millisecondsSinceEpoch}",
			pedido: ordenActiva.copyWith(estado: MaintenanceOrderStatus.completado),
			fechaCierre: DateTime.now(),
			motivoCierre: "Completado por retiro de stock",
		);
		state = [...state, record];
	}
}
