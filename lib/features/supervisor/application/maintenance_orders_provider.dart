import "package:flutter_riverpod/flutter_riverpod.dart";

import "../domain/maintenance_order.dart";
import "maintenance_history_provider.dart";

/// Listado de pedidos de mantenimiento (demo → RPC / tabla Supabase).
final maintenanceOrdersProvider =
		NotifierProvider<MaintenanceOrdersNotifier, List<MaintenanceOrder>>(
	MaintenanceOrdersNotifier.new,
);

class MaintenanceOrdersNotifier extends Notifier<List<MaintenanceOrder>> {
	static List<MaintenanceOrder> _demo() => [
				MaintenanceOrder(
					id: "1",
					numeroOrden: "ORD-0001",
					fechaPedido: DateTime(2024, 5, 20, 10, 30),
					producto: "MOTOR ELÉCTRICO",
					estado: MaintenanceOrderStatus.pendiente,
					solicitante: "Roberto Díaz — Producción línea 2",
					motivo:
							"Revisión por vibración anormal y ruido en rodamiento delantero.",
					imagenUrl: "https://picsum.photos/seed/maint1/900/500",
				),
				MaintenanceOrder(
					id: "2",
					numeroOrden: "ORD-0002",
					fechaPedido: DateTime(2024, 5, 19, 14, 15),
					producto: "BOMBA HIDRÁULICA",
					estado: MaintenanceOrderStatus.enviado,
					solicitante: "Laura Martínez — Mantenimiento",
					motivo: "Pérdida de presión intermitente en circuito principal.",
					imagenUrl: null,
				),
				MaintenanceOrder(
					id: "3",
					numeroOrden: "ORD-0003",
					fechaPedido: DateTime(2024, 5, 21, 8, 45),
					producto: "COMPRESOR",
					estado: MaintenanceOrderStatus.enProceso,
					solicitante: "Carlos Vega — Pañol",
					motivo: "Calibración y cambio de filtros según plan anual.",
				),
				MaintenanceOrder(
					id: "5",
					numeroOrden: "ORD-0005",
					fechaPedido: DateTime(2024, 5, 22, 9, 10),
					producto: "MOTOR ELÉCTRICO",
					estado: MaintenanceOrderStatus.pendiente,
					solicitante: "Pedro Ruiz — Turno noche",
					motivo: "Solicitud de rodillo de repuesto por desgate.",
				),
				MaintenanceOrder(
					id: "6",
					numeroOrden: "ORD-0006",
					fechaPedido: DateTime(2024, 5, 17, 11, 20),
					producto: "BOMBA HIDRÁULICA",
					estado: MaintenanceOrderStatus.enviado,
					solicitante: "María López — Calidad",
					motivo: "Chequeo tras parada programada de fin de semana.",
				),
				MaintenanceOrder(
					id: "7",
					numeroOrden: "ORD-0007",
					fechaPedido: DateTime(2024, 5, 23, 7, 50),
					producto: "COMPRESOR",
					estado: MaintenanceOrderStatus.enProceso,
					solicitante: "Lucía Fernández — Seguridad e higiene",
					motivo: "Actualización de mangueras y revisiones CE.",
				),
			];

	@override
	List<MaintenanceOrder> build() => List<MaintenanceOrder>.from(_demo());

	/// Quita el pedido del listado activo y lo registra en historial como cerrado por retiro.
	void registrarRetiro(String orderId) {
		final list = [...state];
		final idx = list.indexWhere((o) => o.id == orderId);
		if (idx < 0) return;
		final o = list[idx];
		ref.read(maintenanceHistoryProvider.notifier).registrarRetiro(o);
		list.removeAt(idx);
		state = list;
	}
}
