import "maintenance_order.dart";

/// Entrada en historial cuando un pedido de mantenimiento se cierra (p. ej. retiro de stock).
class CompletedMaintenanceRecord {
	const CompletedMaintenanceRecord({
		required this.id,
		required this.pedido,
		required this.fechaCierre,
		required this.motivoCierre,
	});

	/// Identificador estable para la fila de historial.
	final String id;
	final MaintenanceOrder pedido;
	final DateTime fechaCierre;
	final String motivoCierre;
}
