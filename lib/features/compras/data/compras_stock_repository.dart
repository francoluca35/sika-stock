import "package:supabase_flutter/supabase_flutter.dart";

import "../../supervisor/domain/maintenance_order.dart";
import "../domain/compras_in_app_notification_row.dart";
import "../domain/compras_panol_stock_request_row.dart";

class ComprasStockRepository {
	ComprasStockRepository(this._client);

	final SupabaseClient _client;

	/// Solicitudes ordenadas por más reciente primero (historial Compras).
	Future<List<ComprasPanolStockRequestRow>> fetchPanolStockRequests() async {
		final raw = await _client
				.from("compras_panol_stock_requests")
				.select("*, maintenance_orders(workflow_status, created_at, updated_at)")
				.order("created_at", ascending: false);
		final list = raw as List? ?? [];
		return list
				.map((e) => ComprasPanolStockRequestRow.fromJson(Map<String, dynamic>.from(e as Map)))
				.toList();
	}

	Future<List<ComprasInAppNotificationRow>> fetchMyNotifications({int limit = 40}) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return [];
		final raw = await _client
				.from("compras_in_app_notifications")
				.select()
				.eq("user_id", uid)
				.order("created_at", ascending: false)
				.limit(limit);
		final list = raw as List? ?? [];
		return list
				.map((e) => ComprasInAppNotificationRow.fromJson(Map<String, dynamic>.from(e as Map)))
				.toList();
	}

	Future<void> markNotificationRead(String notificationId) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return;
		await _client.from("compras_in_app_notifications").update({
			"read_at": DateTime.now().toUtc().toIso8601String(),
		}).eq("id", notificationId).eq("user_id", uid);
	}

	Future<void> dismissNotification(String notificationId) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return;
		await _client
				.from("compras_in_app_notifications")
				.delete()
				.eq("id", notificationId)
				.eq("user_id", uid);
	}

	Future<void> dismissAllMyNotifications() async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return;
		await _client.from("compras_in_app_notifications").delete().eq("user_id", uid);
	}

	/// Marca como leídas todas las notificaciones de solicitudes Pañol (p. ej. al abrir historial).
	Future<void> markAllPanolStockNotificationsRead() async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return;
		await _client
				.from("compras_in_app_notifications")
				.update({
					"read_at": DateTime.now().toUtc().toIso8601String(),
				})
				.eq("user_id", uid)
				.eq("kind", "panol_stock_request");
	}

	/// Pañol: registra solicitud a Compras (dispara notificaciones vía trigger en BD).
	Future<void> createPanolStockRequestFromMaintenanceOrder(MaintenanceOrder order) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) {
			throw Exception("No hay sesión");
		}
		await _client.from("compras_panol_stock_requests").insert({
			"maintenance_order_id": order.id,
			"order_number": order.numeroOrden,
			"product_name": order.producto,
			"quantity": order.quantity,
			"priority": order.priority,
			"destination": order.destination,
			"solicitante_display": order.solicitante,
			"panol_user_id": uid,
			"imagen_url": order.imagenUrl,
		});
	}

	/// Compras: registra que se emitió la OC (notifica a pañol, supervisor, admin y solicitante).
	Future<void> comprasNotifyOcEmitted(String maintenanceOrderId) async {
		await _client
				.from("maintenance_orders")
				.update({"workflow_status": "compras_oc_notified"})
				.eq("id", maintenanceOrderId)
				.eq("workflow_status", "panol_requested_compras");
	}

	/// Compras o Pañol: confirma llegada del material a planta (notifica a todos los roles).
	Future<void> comprasNotifyMaterialArrived(String maintenanceOrderId) async {
		await _client
				.from("maintenance_orders")
				.update({"workflow_status": "compras_arrived_notified"})
				.eq("id", maintenanceOrderId)
				.eq("workflow_status", "compras_oc_notified");
	}
}
