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

	/// Fila desde Supabase para historial del supervisor.
	factory CompletedMaintenanceRecord.fromOrder(MaintenanceOrder o) {
		final ws = o.workflowStatus;
		final motivo = switch (ws) {
			MaintenanceWorkflowStatus.completed => "Entregado",
			MaintenanceWorkflowStatus.forwardedToPanol => "Consulta con pañol",
			MaintenanceWorkflowStatus.panolRequestedCompras => "Seguimiento con compras",
			MaintenanceWorkflowStatus.comprasOcNotified => "Consulta (OC emitida)",
			MaintenanceWorkflowStatus.comprasPurchaseDone => "Compra realizada",
			MaintenanceWorkflowStatus.comprasArrivedNotified => "Material en planta",
			MaintenanceWorkflowStatus.cancelled => "Cancelado",
			_ => "Cerrado",
		};
		final fecha = o.updatedAt ?? o.fechaPedido;
		return CompletedMaintenanceRecord(
			id: o.id,
			pedido: o,
			fechaCierre: fecha,
			motivoCierre: motivo,
		);
	}
}
