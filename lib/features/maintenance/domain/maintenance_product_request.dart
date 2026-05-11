/// Pedido de producto del rol **Mantenimiento** (demo en memoria → Supabase).
class MaintenanceProductRequest {
	const MaintenanceProductRequest({
		required this.id,
		required this.tipoPedido,
		required this.cantidad,
		required this.tipoProducto,
		required this.destino,
		required this.createdAt,
	});

	final String id;
	final String tipoPedido;
	final int cantidad;
	final String tipoProducto;
	final String destino;
	final DateTime createdAt;
}
