/// Estados de badge en UI (listados / historial).
enum MaintenanceOrderStatus {
	pendiente,
	enviado,
	enProceso,
	completado,
}

/// Flujo persistido en `maintenance_orders.workflow_status`.
enum MaintenanceWorkflowStatus {
	pendingSupervisor,
	supervisorStockOk,
	forwardedToPanol,
	completed,
	cancelled;

	static MaintenanceWorkflowStatus fromDb(String? raw) {
		switch ((raw ?? "").trim()) {
			case "pending_supervisor":
				return MaintenanceWorkflowStatus.pendingSupervisor;
			case "supervisor_stock_ok":
				return MaintenanceWorkflowStatus.supervisorStockOk;
			case "forwarded_to_panol":
				return MaintenanceWorkflowStatus.forwardedToPanol;
			case "completed":
				return MaintenanceWorkflowStatus.completed;
			case "cancelled":
				return MaintenanceWorkflowStatus.cancelled;
			default:
				return MaintenanceWorkflowStatus.pendingSupervisor;
		}
	}

	String get dbValue {
		switch (this) {
			case MaintenanceWorkflowStatus.pendingSupervisor:
				return "pending_supervisor";
			case MaintenanceWorkflowStatus.supervisorStockOk:
				return "supervisor_stock_ok";
			case MaintenanceWorkflowStatus.forwardedToPanol:
				return "forwarded_to_panol";
			case MaintenanceWorkflowStatus.completed:
				return "completed";
			case MaintenanceWorkflowStatus.cancelled:
				return "cancelled";
		}
	}
}

/// Pedido de mantenimiento (Supabase `maintenance_orders`).
class MaintenanceOrder {
	const MaintenanceOrder({
		required this.id,
		required this.numeroOrden,
		required this.fechaPedido,
		required this.producto,
		required this.workflowStatus,
		required this.solicitante,
		required this.motivo,
		required this.quantity,
		required this.productType,
		required this.priority,
		required this.destination,
		this.imagenUrl,
		this.updatedAt,
		this.createdBy,
	});

	final String id;
	final String numeroOrden;
	final DateTime fechaPedido;
	final String producto;
	final MaintenanceWorkflowStatus workflowStatus;

	/// Quién solicitó el pedido (texto guardado al crear).
	final String solicitante;

	/// Resumen motivo / contexto (derivado o libre).
	final String motivo;

	final int quantity;
	final String productType;
	final String priority;
	final String destination;

	final String? imagenUrl;

	/// Última actualización en BD (útil para ordenar historial).
	final DateTime? updatedAt;

	/// Autor del pedido (`created_by` en Supabase); necesario para notificaciones.
	final String? createdBy;

	/// Badge genérico según flujo.
	MaintenanceOrderStatus get estado {
		switch (workflowStatus) {
			case MaintenanceWorkflowStatus.pendingSupervisor:
				return MaintenanceOrderStatus.pendiente;
			case MaintenanceWorkflowStatus.supervisorStockOk:
				return MaintenanceOrderStatus.enProceso;
			case MaintenanceWorkflowStatus.forwardedToPanol:
				return MaintenanceOrderStatus.enviado;
			case MaintenanceWorkflowStatus.completed:
				return MaintenanceOrderStatus.completado;
			case MaintenanceWorkflowStatus.cancelled:
				return MaintenanceOrderStatus.completado;
		}
	}

	factory MaintenanceOrder.fromJson(Map<String, dynamic> m) {
		final created = m["created_at"];
		DateTime fecha;
		if (created is DateTime) {
			fecha = created;
		} else {
			fecha = DateTime.parse(created.toString());
		}
		final rawUpd = m["updated_at"];
		DateTime? updatedAt;
		if (rawUpd != null) {
			if (rawUpd is DateTime) {
				updatedAt = rawUpd;
			} else {
				updatedAt = DateTime.tryParse(rawUpd.toString());
			}
		}
		return MaintenanceOrder(
			id: m["id"] as String,
			numeroOrden: m["order_number"] as String,
			fechaPedido: fecha,
			producto: m["product_name"] as String,
			workflowStatus: MaintenanceWorkflowStatus.fromDb(
				m["workflow_status"] as String?,
			),
			solicitante: m["solicitante_display"] as String,
			motivo: _composeMotivo(m),
			quantity: (m["quantity"] as num).toInt(),
			productType: m["product_type"] as String,
			priority: m["priority"] as String,
			destination: m["destination"] as String,
			imagenUrl: null,
			updatedAt: updatedAt,
			createdBy: m["created_by"]?.toString(),
		);
	}

	static String _composeMotivo(Map<String, dynamic> m) {
		final dest = (m["destination"] as String?)?.trim() ?? "";
		final tipo = (m["product_type"] as String?)?.trim() ?? "";
		final pri = (m["priority"] as String?)?.trim() ?? "";
		final qty = m["quantity"]?.toString() ?? "";
		return "Para: $dest · Tipo: $tipo · Prioridad: $pri · Cantidad: $qty";
	}

	MaintenanceOrder copyWith({
		MaintenanceWorkflowStatus? workflowStatus,
		DateTime? updatedAt,
		String? createdBy,
	}) {
		return MaintenanceOrder(
			id: id,
			numeroOrden: numeroOrden,
			fechaPedido: fechaPedido,
			producto: producto,
			workflowStatus: workflowStatus ?? this.workflowStatus,
			solicitante: solicitante,
			motivo: motivo,
			quantity: quantity,
			productType: productType,
			priority: priority,
			destination: destination,
			imagenUrl: imagenUrl,
			updatedAt: updatedAt ?? this.updatedAt,
			createdBy: createdBy ?? this.createdBy,
		);
	}
}
