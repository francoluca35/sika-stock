import "package:supabase_flutter/supabase_flutter.dart";

import "../../supervisor/domain/maintenance_order.dart";
import "../domain/compras_in_app_notification_row.dart";
import "../domain/compras_panol_stock_request_row.dart";

class ComprasStockRepository {
	ComprasStockRepository(this._client);

	final SupabaseClient _client;

	static const _cpsrSelect =
			"id, created_at, maintenance_order_id, order_number, product_name, quantity, "
			"priority, destination, solicitante_display, panol_user_id, imagen_url, "
			"maintenance_orders(workflow_status, created_at, updated_at)";

	static const _cinSelect =
			"id, created_at, user_id, kind, ref_id, title, body, read_at";

	static const _limitRequests = 50;

	/// Solicitudes ordenadas por más reciente primero (historial Compras).
	Future<List<ComprasPanolStockRequestRow>> fetchPanolStockRequests() async {
		final raw = await _client
				.from("compras_panol_stock_requests")
				.select(_cpsrSelect)
				.order("created_at", ascending: false)
				.limit(_limitRequests);
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
				.select(_cinSelect)
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

	/// Pañol: registra solicitud a compras (dispara notificaciones vía trigger en BD).
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

	/// Pañol: avisa que el material está listo para retirar.
	Future<void> panolNotifyReadyForPickup(String maintenanceOrderId) async {
		const fromStates = [
			"panol_requested_compras",
			"compras_oc_notified",
			"compras_purchase_done",
		];
		for (final from in fromStates) {
			final res = await _client
					.from("maintenance_orders")
					.update({"workflow_status": "compras_arrived_notified"})
					.eq("id", maintenanceOrderId)
					.eq("workflow_status", from)
					.select("id");
			if ((res as List).isNotEmpty) return;
		}
		throw Exception("El pedido no está en un estado que permita avisar retiro.");
	}
}
