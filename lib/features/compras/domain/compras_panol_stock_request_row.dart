/// Fila de `compras_panol_stock_requests` (solicitud Pañol → Compras sin stock).
class ComprasPanolStockRequestRow {
	const ComprasPanolStockRequestRow({
		required this.id,
		required this.createdAt,
		required this.maintenanceOrderId,
		required this.orderNumber,
		required this.productName,
		required this.quantity,
		required this.priority,
		required this.destination,
		required this.solicitanteDisplay,
		required this.panolUserId,
		this.imagenUrl,
		this.maintenanceWorkflowStatus,
	});

	final String id;
	final DateTime createdAt;
	final String maintenanceOrderId;
	final String orderNumber;
	final String productName;
	final int quantity;
	final String priority;
	final String destination;
	final String solicitanteDisplay;
	final String panolUserId;
	final String? imagenUrl;
	/// `maintenance_orders.workflow_status` (join opcional).
	final String? maintenanceWorkflowStatus;

	factory ComprasPanolStockRequestRow.fromJson(Map<String, dynamic> m) {
		final c = m["created_at"];
		String? moWs;
		final mo = m["maintenance_orders"];
		if (mo is Map<String, dynamic>) {
			moWs = mo["workflow_status"] as String?;
		}
		return ComprasPanolStockRequestRow(
			id: m["id"] as String,
			createdAt: c is DateTime ? c : DateTime.parse(c.toString()),
			maintenanceOrderId: m["maintenance_order_id"] as String,
			orderNumber: m["order_number"] as String,
			productName: m["product_name"] as String,
			quantity: (m["quantity"] as num).toInt(),
			priority: m["priority"] as String,
			destination: m["destination"] as String,
			solicitanteDisplay: m["solicitante_display"] as String,
			panolUserId: m["panol_user_id"] as String,
			imagenUrl: m["imagen_url"] as String?,
			maintenanceWorkflowStatus: moWs,
		);
	}
}
