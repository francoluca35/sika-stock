/// Estados del pedido de mantenimiento (badges según mockup).
enum MaintenanceOrderStatus {
	pendiente,
	enviado,
	enProceso,
	completado,
}

/// Pedido de mantenimiento (demo → Supabase).
class MaintenanceOrder {
	const MaintenanceOrder({
		required this.id,
		required this.numeroOrden,
		required this.fechaPedido,
		required this.producto,
		required this.estado,
		required this.solicitante,
		required this.motivo,
		this.imagenUrl,
	});

	final String id;
	final String numeroOrden;
	final DateTime fechaPedido;
	final String producto;
	final MaintenanceOrderStatus estado;

	/// Quién solicitó el pedido (nombre / sector).
	final String solicitante;

	/// Para qué / motivo del pedido.
	final String motivo;

	/// URL de imagen adjunta; `null` si no hay.
	final String? imagenUrl;

	MaintenanceOrder copyWith({
		MaintenanceOrderStatus? estado,
	}) {
		return MaintenanceOrder(
			id: id,
			numeroOrden: numeroOrden,
			fechaPedido: fechaPedido,
			producto: producto,
			estado: estado ?? this.estado,
			solicitante: solicitante,
			motivo: motivo,
			imagenUrl: imagenUrl,
		);
	}
}
