import "../../compras/domain/compras_panol_stock_request_row.dart";
import "../presentation/widgets/producto_seguimiento_panel.dart";

/// Estados de compra con seguimiento activo (desde solicitud pañol → compras).
const _workflowSeguimientoCompras = {
	"panol_requested_compras",
	"compras_oc_notified",
	"compras_arrived_notified",
};

SeguimientoCompraEstado seguimientoEstadoDesdeWorkflow(String? ws) {
	switch (ws) {
		case "compras_arrived_notified":
			return SeguimientoCompraEstado.entregado;
		case "compras_oc_notified":
			return SeguimientoCompraEstado.comprado;
		default:
			return SeguimientoCompraEstado.pendienteCompra;
	}
}

bool comprasRequestEnSeguimientoActivo(ComprasPanolStockRequestRow r) {
	final ws = r.maintenanceWorkflowStatus;
	if (ws == null || ws.isEmpty) return false;
	return _workflowSeguimientoCompras.contains(ws);
}

ProductoSeguimiento productoSeguimientoDesdeComprasRequest(
	ComprasPanolStockRequestRow r,
) {
	final ws = r.maintenanceWorkflowStatus;
	final estado = seguimientoEstadoDesdeWorkflow(ws);
	final trayecto = <SeguimientoEvento>[];

	final altaPedido = r.maintenanceCreatedAt ?? r.createdAt;
	trayecto.add(
		SeguimientoEvento(
			titulo: "Pedido registrado · ${r.solicitanteDisplay}",
			cuando: altaPedido,
		),
	);

	trayecto.add(
		SeguimientoEvento(
			titulo: "Pañol solicitó material a compras (${r.quantity} u.)",
			cuando: r.createdAt,
		),
	);

	if (ws == "compras_oc_notified" ||
			ws == "compras_arrived_notified" ||
			ws == "completed") {
		trayecto.add(
			SeguimientoEvento(
				titulo: "Compras emitió orden de compra",
				cuando: r.maintenanceUpdatedAt ?? r.createdAt,
			),
		);
	}

	if (ws == "compras_arrived_notified" || ws == "completed") {
		trayecto.add(
			SeguimientoEvento(
				titulo: "Material recibido en planta",
				cuando: r.maintenanceUpdatedAt ?? r.createdAt,
			),
		);
	}

	return ProductoSeguimiento(
		id: r.id,
		maintenanceOrderId: r.maintenanceOrderId,
		workflowStatus: ws,
		producto: r.productName,
		referenciaPedido: "${r.orderNumber} · ${r.destination}",
		estado: estado,
		trayecto: trayecto,
	);
}

List<ProductoSeguimiento> productosSeguimientoDesdeComprasRequests(
	List<ComprasPanolStockRequestRow> rows,
) {
	return rows
			.where(comprasRequestEnSeguimientoActivo)
			.map(productoSeguimientoDesdeComprasRequest)
			.toList();
}
