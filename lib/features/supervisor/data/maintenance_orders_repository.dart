import "dart:math";
import "dart:typed_data";

import "package:supabase_flutter/supabase_flutter.dart";

import "../domain/maintenance_order.dart";
import "../domain/maintenance_order_notification_row.dart";

class MaintenanceOrdersRepository {
	MaintenanceOrdersRepository(this._client);

	final SupabaseClient _client;

	static const String _photoBucket = "maintenance-order-photos";

	Future<void> createOrder({
		required String solicitanteDisplay,
		required String productName,
		required int quantity,
		required String productType,
		required String priority,
		required String destination,
		Uint8List? photoJpeg,
	}) async {
		await createOrderReturningId(
			solicitanteDisplay: solicitanteDisplay,
			productName: productName,
			quantity: quantity,
			productType: productType,
			priority: priority,
			destination: destination,
			photoJpeg: photoJpeg,
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
		Uint8List? photoJpeg,
	}) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) {
			throw Exception("No hay sesión");
		}

		final orderId = _generateUuidV4();
		String? imagenUrl;
		if (photoJpeg != null && photoJpeg.isNotEmpty) {
			imagenUrl = await _uploadOrderPhoto(
				userId: uid,
				orderId: orderId,
				jpeg: photoJpeg,
			);
		}

		final payload = <String, dynamic>{
			"id": orderId,
			"created_by": uid,
			"solicitante_display": solicitanteDisplay,
			"product_name": productName,
			"quantity": quantity,
			"product_type": productType,
			"priority": priority,
			"destination": destination,
		};
		if (imagenUrl != null) {
			payload["imagen_url"] = imagenUrl;
		}

		await _client.from("maintenance_orders").insert(payload).select("id").single();

		return orderId;
	}

	/// URL de la foto del pedido (columna BD o archivo en Storage si la URL no se guardó).
	Future<String?> resolveOrderPhotoUrl(MaintenanceOrder order) async {
		final stored = order.imagenUrl?.trim();
		if (stored != null && stored.isNotEmpty) {
			return stored;
		}

		final creator = order.createdBy?.trim();
		if (creator == null || creator.isEmpty) {
			return null;
		}

		final path = "$creator/${order.id}.jpg";
		try {
			final files = await _client.storage.from(_photoBucket).list(
				path: creator,
				searchOptions: SearchOptions(
					search: "${order.id}.jpg",
					limit: 1,
				),
			);
			if (files.isEmpty) {
				return null;
			}
			return _client.storage.from(_photoBucket).getPublicUrl(path);
		} catch (_) {
			return null;
		}
	}

	static String _generateUuidV4() {
		final random = Random.secure();
		final bytes = List<int>.generate(16, (_) => random.nextInt(256));
		bytes[6] = (bytes[6] & 0x0f) | 0x40;
		bytes[8] = (bytes[8] & 0x3f) | 0x80;
		String b(int i) => bytes[i].toRadixString(16).padLeft(2, "0");
		return "${b(0)}${b(1)}${b(2)}${b(3)}-${b(4)}${b(5)}-${b(6)}${b(7)}"
			"-${b(8)}${b(9)}-${b(10)}${b(11)}${b(12)}${b(13)}${b(14)}${b(15)}";
	}

	Future<String> _uploadOrderPhoto({
		required String userId,
		required String orderId,
		required Uint8List jpeg,
	}) async {
		final path = "$userId/$orderId.jpg";
		try {
			await _client.storage.from(_photoBucket).uploadBinary(
				path,
				jpeg,
				fileOptions: const FileOptions(
					contentType: "image/jpeg",
					upsert: true,
				),
			);
		} on StorageException catch (e) {
			if (e.statusCode == 403 || (e.message).toLowerCase().contains("row-level security")) {
				throw Exception(
					"No se pudo subir la foto: faltan permisos en Supabase Storage. "
					"Ejecutá en el SQL Editor la migración "
					"20260623140000_maintenance_order_photos_storage_rls_fix.sql",
				);
			}
			rethrow;
		}
		return _client.storage.from(_photoBucket).getPublicUrl(path);
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
					"compras_purchase_done",
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
					"compras_purchase_done",
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

	Future<void> markCompleted(
		String orderId, {
		String? stockItemId,
	}) async {
		if (_client.auth.currentUser?.id == null) {
			throw Exception("No hay sesión");
		}
		final sid = stockItemId?.trim();
		final params = <String, dynamic>{
			"p_order_id": orderId,
			"p_stock_item_id": (sid != null && sid.isNotEmpty) ? sid : null,
		};
		await _client.rpc<void>(
			"complete_maintenance_order_with_inventory",
			params: params,
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
