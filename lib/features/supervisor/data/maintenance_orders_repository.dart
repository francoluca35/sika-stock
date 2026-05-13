import "package:supabase_flutter/supabase_flutter.dart";

import "../domain/maintenance_order.dart";
import "../domain/maintenance_order_notification_row.dart";

class MaintenanceOrdersRepository {
	MaintenanceOrdersRepository(this._client);

	final SupabaseClient _client;

	Future<void> createOrder({
		required String solicitanteDisplay,
		required String productName,
		required int quantity,
		required String productType,
		required String priority,
		required String destination,
	}) async {
		await createOrderReturningId(
			solicitanteDisplay: solicitanteDisplay,
			productName: productName,
			quantity: quantity,
			productType: productType,
			priority: priority,
			destination: destination,
		);
	}

	/// Inserta la OM y devuelve el `id` (para encadenar decisión del supervisor).
	Future<String> createOrderReturningId({
		required String solicitanteDisplay,
		required String productName,
		required int quantity,
		required String productType,
		required String priority,
		required String destination,
	}) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) {
			throw Exception("No hay sesión");
		}
		final row = await _client
				.from("maintenance_orders")
				.insert({
					"created_by": uid,
					"solicitante_display": solicitanteDisplay,
					"product_name": productName,
					"quantity": quantity,
					"product_type": productType,
					"priority": priority,
					"destination": destination,
				})
				.select("id")
				.single();
		return row["id"] as String;
	}

	Future<MaintenanceOrder?> fetchOrderById(String id) async {
		final row = await _client.from("maintenance_orders").select().eq("id", id).maybeSingle();
		if (row == null) return null;
		return MaintenanceOrder.fromJson(Map<String, dynamic>.from(row));
	}

	Future<List<MaintenanceOrder>> fetchSupervisorHistory() async {
		final rows = await _client
				.from("maintenance_orders")
				.select()
				.inFilter("workflow_status", [
					"completed",
					"forwarded_to_panol",
					"panol_requested_compras",
					"compras_oc_notified",
					"compras_arrived_notified",
					"cancelled",
				])
				.order("updated_at", ascending: false);
		return _mapList(rows);
	}

	Future<List<MaintenanceOrder>> fetchSupervisorActive() async {
		final rows = await _client
				.from("maintenance_orders")
				.select()
				.inFilter("workflow_status", [
					"pending_supervisor",
					"supervisor_stock_ok",
					"compras_arrived_notified",
				])
				.order("created_at", ascending: false);
		return _mapList(rows);
	}

	Future<List<MaintenanceOrder>> fetchForwardedForPanol() async {
		final rows = await _client
				.from("maintenance_orders")
				.select()
				.inFilter("workflow_status", [
					"forwarded_to_panol",
					"panol_requested_compras",
					"compras_oc_notified",
					"compras_arrived_notified",
					"supervisor_stock_ok",
				])
				.order("created_at", ascending: false);
		return _mapList(rows);
	}

	/// Historial pañol: pedidos cerrados o cancelados que pasaron por su circuito.
	Future<List<MaintenanceOrder>> fetchPanolOrderHistory() async {
		final rows = await _client
				.from("maintenance_orders")
				.select()
				.inFilter("workflow_status", ["completed", "cancelled"])
				.order("updated_at", ascending: false);
		return _mapList(rows);
	}

	Future<List<MaintenanceOrder>> fetchMine() async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return [];
		final rows = await _client
				.from("maintenance_orders")
				.select()
				.eq("created_by", uid)
				.order("created_at", ascending: false);
		return _mapList(rows);
	}

	List<MaintenanceOrder> _mapList(dynamic rows) {
		if (rows is! List) return [];
		return rows
				.map((e) => MaintenanceOrder.fromJson(Map<String, dynamic>.from(e as Map)))
				.toList();
	}

	Future<void> supervisorDecideStock({
		required String orderId,
		required bool hayStock,
		String? stockItemId,
	}) async {
		if (_client.auth.currentUser?.id == null) {
			throw Exception("No hay sesión");
		}
		await _client.rpc<void>(
			"supervisor_decide_stock_with_inventory",
			params: <String, dynamic>{
				"p_order_id": orderId,
				"p_hay_stock": hayStock,
				"p_stock_item_id": hayStock ? stockItemId : null,
			},
		);
	}

	Future<void> markCompleted(String orderId) async {
		if (_client.auth.currentUser?.id == null) {
			throw Exception("No hay sesión");
		}
		await _client.rpc<void>(
			"complete_maintenance_order_with_inventory",
			params: <String, dynamic>{"p_order_id": orderId},
		);
	}

	/// Pañol: material ubicado fuera del catálogo digital; pasa a retiro (aviso vía trigger en BD).
	Future<void> panolMarkExternalStockFound(String orderId) async {
		await _client
				.from("maintenance_orders")
				.update({"workflow_status": "supervisor_stock_ok"})
				.eq("id", orderId)
				.eq("workflow_status", "forwarded_to_panol");
	}

	/// Pañol: registra cantidad en inventario y marca pedido listo para retiro.
	Future<void> panolConfirmCatalogStock({
		required String orderId,
		required String stockItemId,
		required int cantidad,
	}) async {
		if (_client.auth.currentUser?.id == null) {
			throw Exception("No hay sesión");
		}
		await _client.rpc<void>(
			"panol_confirm_stock_with_inventory",
			params: <String, dynamic>{
				"p_order_id": orderId,
				"p_stock_item_id": stockItemId,
				"p_cantidad": cantidad,
			},
		);
	}

	Future<void> insertOrderNotification({
		required String userId,
		required String orderId,
		required String kind,
		required String title,
		required String body,
	}) async {
		await _client.from("maintenance_order_notifications").insert({
			"user_id": userId,
			"order_id": orderId,
			"kind": kind,
			"title": title,
			"body": body,
		});
	}

	Future<List<MaintenanceOrderNotificationRow>> fetchMyNotifications({
		int limit = 40,
	}) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return [];
		final rows = await _client
				.from("maintenance_order_notifications")
				.select()
				.eq("user_id", uid)
				.order("created_at", ascending: false)
				.limit(limit);
		return (rows as List)
				.map(
					(e) => MaintenanceOrderNotificationRow.fromJson(
						Map<String, dynamic>.from(e as Map),
					),
				)
				.toList();
	}

	Future<void> markNotificationRead(String notificationId) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return;
		await _client
				.from("maintenance_order_notifications")
				.update({
					"read_at": DateTime.now().toUtc().toIso8601String(),
				})
				.eq("id", notificationId)
				.eq("user_id", uid);
	}

	Future<void> dismissNotification(String notificationId) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return;
		await _client
				.from("maintenance_order_notifications")
				.delete()
				.eq("id", notificationId)
				.eq("user_id", uid);
	}

	Future<void> dismissAllMyNotifications() async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return;
		await _client
				.from("maintenance_order_notifications")
				.delete()
				.eq("user_id", uid);
	}
}
