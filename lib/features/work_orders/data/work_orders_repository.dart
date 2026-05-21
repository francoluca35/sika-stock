import "dart:typed_data";

import "package:supabase_flutter/supabase_flutter.dart";

import "../../auth/domain/profile_row.dart";
import "../domain/work_order.dart";
import "../domain/work_order_pdf_metadata.dart";
import "work_order_pdf_builder.dart";
import "work_order_pdf_metadata_parser.dart";

class WorkOrdersRepository {
	WorkOrdersRepository(this._client);

	final SupabaseClient _client;
	static const _bucket = "work-orders";

	Future<List<ProfileRow>> fetchMaintenanceProfiles() async {
		final rows = await _client
				.from("profiles")
				.select()
				.eq("rol", "MANTENIMIENTO")
				.order("nombre", ascending: true);
		final list = rows as List? ?? [];
		return list
				.map((e) => ProfileRow.fromMap(Map<String, dynamic>.from(e as Map)))
				.toList();
	}

	Future<List<WorkOrder>> fetchAdminWorkOrders() async {
		final rows = await _client
				.from("work_orders")
				.select()
				.order("created_at", ascending: false)
				.limit(200);
		return _mapWorkOrders(rows);
	}

	Future<WorkOrder?> fetchWorkOrderById(String id) async {
		final row = await _client.from("work_orders").select().eq("id", id).maybeSingle();
		if (row == null) return null;
		return WorkOrder.fromJson(Map<String, dynamic>.from(row));
	}

	Future<List<WorkOrderAssignment>> fetchAssignmentsForWorkOrder(String workOrderId) async {
		final rows = await _client
				.from("work_order_assignments")
				.select(
					"*, profiles(nombre, usuario), work_order_responses(*)",
				)
				.eq("work_order_id", workOrderId)
				.order("assigned_at", ascending: true);
		return _mapAssignments(rows);
	}

	Future<List<WorkOrderAssignment>> fetchMyAssignments() async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return [];
		final rows = await _client
				.from("work_order_assignments")
				.select("*, work_orders(*)")
				.eq("user_id", uid)
				.order("assigned_at", ascending: false)
				.limit(100);
		return _mapAssignments(rows);
	}

	Future<WorkOrderAssignment?> fetchAssignmentById(String assignmentId) async {
		final row = await _client
				.from("work_order_assignments")
				.select("*, work_orders(*), work_order_responses(*)")
				.eq("id", assignmentId)
				.maybeSingle();
		if (row == null) return null;
		return WorkOrderAssignment.fromJson(Map<String, dynamic>.from(row));
	}

	Future<String> createWorkOrderWithAssignments({
		required String title,
		required Uint8List pdfBytes,
		required List<String> assigneeUserIds,
		String? otNumber,
	}) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) throw Exception("No hay sesión");
		if (assigneeUserIds.isEmpty) {
			throw Exception("Seleccioná al menos un empleado de mantenimiento.");
		}

		final metadata = WorkOrderPdfMetadataParser.parseFromPdfBytes(pdfBytes);
		final resolvedOt = otNumber?.trim().isNotEmpty == true
				? otNumber!.trim()
				: (metadata.orderNumber.isNotEmpty ? metadata.orderNumber : null);

		final inserted = await _client
				.from("work_orders")
				.insert({
					"created_by": uid,
					"title": title.trim(),
					"ot_number": resolvedOt,
					"original_pdf_path": "pending",
					"status": "assigned",
					"pdf_metadata": metadata.toJson(),
				})
				.select("id")
				.single();
		final workOrderId = inserted["id"] as String;
		final pdfPath = "$workOrderId/original.pdf";

		await _client.storage.from(_bucket).uploadBinary(
					pdfPath,
					pdfBytes,
					fileOptions: const FileOptions(
						contentType: "application/pdf",
						upsert: true,
					),
				);

		await _client.from("work_orders").update({
			"original_pdf_path": pdfPath,
		}).eq("id", workOrderId);

		final assignRows = assigneeUserIds
				.map((userId) => {"work_order_id": workOrderId, "user_id": userId})
				.toList();
		await _client.from("work_order_assignments").insert(assignRows);

		return workOrderId;
	}

	Future<Uint8List> downloadStorageBytes(String path) async {
		return _client.storage.from(_bucket).download(path);
	}

	Future<String> createSignedUrl(String path, {int expiresInSeconds = 3600}) async {
		return _client.storage.from(_bucket).createSignedUrl(
					path,
					expiresInSeconds,
				);
	}

	Future<void> submitAssignmentResponse({
		required WorkOrderAssignment assignment,
		required String assigneeName,
		required WorkOrderFormData formData,
		required Uint8List signaturePng,
		List<Uint8List> attachmentImages = const [],
	}) async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) throw Exception("No hay sesión");
		if (!assignment.isPending) {
			throw Exception("Esta OT ya fue enviada.");
		}
		final wo = assignment.workOrder;
		if (wo == null) throw Exception("Pedido no encontrado");

		final closedAt = DateTime.now().toUtc();

		final sigPath = "${wo.id}/responses/$uid/signature.png";
		await _client.storage.from(_bucket).uploadBinary(
					sigPath,
					signaturePng,
					fileOptions: const FileOptions(
						contentType: "image/png",
						upsert: true,
					),
				);

		final attachmentPaths = <String>[];
		for (var i = 0; i < attachmentImages.length; i++) {
			final path = "${wo.id}/responses/$uid/attachments/$i.jpg";
			await _client.storage.from(_bucket).uploadBinary(
						path,
						attachmentImages[i],
						fileOptions: const FileOptions(
							contentType: "image/jpeg",
							upsert: true,
						),
					);
			attachmentPaths.add(path);
		}

		final completedPdf = await WorkOrderPdfBuilder.buildCompletedPdf(
			order: wo,
			metadata: wo.pdfMetadata.withReceiver(assigneeName),
			assigneeName: assigneeName,
			formData: formData,
			startedAt: closedAt,
			finishedAt: closedAt,
			signaturePng: signaturePng,
		);
		final pdfPath = "${wo.id}/responses/$uid/completed.pdf";
		await _client.storage.from(_bucket).uploadBinary(
					pdfPath,
					completedPdf,
					fileOptions: const FileOptions(
						contentType: "application/pdf",
						upsert: true,
					),
				);

		await _client.from("work_order_responses").insert({
			"assignment_id": assignment.id,
			"observations": formData.observations.trim(),
			"checklist": [],
			"form_data": formData.toJson(),
			"signature_path": sigPath,
			"completed_pdf_path": pdfPath,
			"attachment_paths": attachmentPaths,
			"started_at": closedAt.toIso8601String(),
			"finished_at": closedAt.toIso8601String(),
		});
	}

	List<WorkOrder> _mapWorkOrders(dynamic rows) {
		if (rows is! List) return [];
		return rows
				.map((e) => WorkOrder.fromJson(Map<String, dynamic>.from(e as Map)))
				.toList();
	}

	List<WorkOrderAssignment> _mapAssignments(dynamic rows) {
		if (rows is! List) return [];
		return rows
				.map((e) => WorkOrderAssignment.fromJson(Map<String, dynamic>.from(e as Map)))
				.toList();
	}
}
