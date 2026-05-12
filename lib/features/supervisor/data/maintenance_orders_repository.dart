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
		final uid = _client.auth.currentUser?.id;
		if (uid == null) {
			throw Exception("No hay sesión");
		}
		await _client.from("maintenance_orders").insert({
			"created_by": uid,
			"solicitante_display": solicitanteDisplay,
			"product_name": productName,
			"quantity": quantity,
			"product_type": productType,
			"priority": priority,
			"destination": destination,
		});
	}

	Future<List<MaintenanceOrder>> fetchSupervisorHistory() async {
		final rows = await _client
				.from("maintenance_orders")
				.select()
				.inFilter("workflow_status", [
					"completed",
					"forwarded_to_panol",
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
				])
				.order("created_at", ascending: false);
		return _mapList(rows);
	}

	Future<List<MaintenanceOrder>> fetchForwardedForPanol() async {
		final rows = await _client
				.from("maintenance_orders")
				.select()
				.eq("workflow_status", "forwarded_to_panol")
				.order("created_at", ascending: false);
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
		String? note,
	}) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) {
			throw Exception("No hay sesión");
		}
		final next = hayStock ? "supervisor_stock_ok" : "forwarded_to_panol";
		await _client
				.from("maintenance_orders")
				.update({
					"workflow_status": next,
					"supervisor_id": uid,
					"supervisor_decided_at": DateTime.now().toUtc().toIso8601String(),
					"supervisor_note": note,
				})
				.eq("id", orderId)
				.eq("workflow_status", "pending_supervisor");
	}

	Future<void> markCompleted(String orderId) async {
		await _client
				.from("maintenance_orders")
				.update({"workflow_status": "completed"})
				.eq("id", orderId)
				.eq("workflow_status", "supervisor_stock_ok");
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
}
