import "work_order_check_item.dart";
import "work_order_pdf_metadata.dart";

class WorkOrder {
	const WorkOrder({
		required this.id,
		required this.createdAt,
		required this.createdBy,
		required this.title,
		required this.originalPdfPath,
		required this.status,
		this.otNumber,
		this.updatedAt,
		this.pdfMetadata = const WorkOrderPdfMetadata(),
	});

	final String id;
	final DateTime createdAt;
	final String createdBy;
	final String title;
	final String? otNumber;
	final String originalPdfPath;
	final String status;
	final DateTime? updatedAt;
	final WorkOrderPdfMetadata pdfMetadata;

	bool get isCompleted => status == "completed";

	factory WorkOrder.fromJson(Map<String, dynamic> m) {
		return WorkOrder(
			id: m["id"] as String,
			createdAt: _parseTs(m["created_at"]) ?? DateTime.now().toUtc(),
			createdBy: m["created_by"] as String,
			title: m["title"] as String,
			otNumber: m["ot_number"] as String?,
			originalPdfPath: m["original_pdf_path"] as String,
			status: m["status"] as String? ?? "assigned",
			updatedAt: _parseTs(m["updated_at"]),
			pdfMetadata: WorkOrderPdfMetadata.fromJson(
				m["pdf_metadata"] is Map
						? Map<String, dynamic>.from(m["pdf_metadata"] as Map)
						: null,
			),
		);
	}

	static DateTime? _parseTs(dynamic v) {
		if (v == null) return null;
		if (v is DateTime) return v.toUtc();
		return DateTime.tryParse(v.toString())?.toUtc();
	}
}

class WorkOrderAssignment {
	const WorkOrderAssignment({
		required this.id,
		required this.workOrderId,
		required this.userId,
		required this.status,
		required this.assignedAt,
		this.completedAt,
		this.workOrder,
		this.assigneeName,
		this.response,
	});

	final String id;
	final String workOrderId;
	final String userId;
	final String status;
	final DateTime assignedAt;
	final DateTime? completedAt;
	final WorkOrder? workOrder;
	final String? assigneeName;
	final WorkOrderResponse? response;

	bool get isPending => status == "pending";

	factory WorkOrderAssignment.fromJson(Map<String, dynamic> m) {
		WorkOrder? wo;
		final nested = m["work_orders"];
		if (nested is Map<String, dynamic>) {
			wo = WorkOrder.fromJson(nested);
		}
		WorkOrderResponse? resp;
		final respList = m["work_order_responses"];
		if (respList is List && respList.isNotEmpty) {
			final first = respList.first;
			if (first is Map<String, dynamic>) {
				resp = WorkOrderResponse.fromJson(first);
			}
		} else if (m["work_order_responses"] is Map<String, dynamic>) {
			resp = WorkOrderResponse.fromJson(
				Map<String, dynamic>.from(m["work_order_responses"] as Map),
			);
		}
		String? name;
		final prof = m["profiles"];
		if (prof is Map<String, dynamic>) {
			name = (prof["nombre"] as String?)?.trim();
			if (name == null || name.isEmpty) {
				name = prof["usuario"] as String?;
			}
		}
		return WorkOrderAssignment(
			id: m["id"] as String,
			workOrderId: m["work_order_id"] as String,
			userId: m["user_id"] as String,
			status: m["status"] as String? ?? "pending",
			assignedAt: WorkOrder._parseTs(m["assigned_at"]) ?? DateTime.now().toUtc(),
			completedAt: WorkOrder._parseTs(m["completed_at"]),
			workOrder: wo,
			assigneeName: name,
			response: resp,
		);
	}
}

class WorkOrderResponse {
	const WorkOrderResponse({
		required this.id,
		required this.assignmentId,
		required this.observations,
		required this.checklist,
		required this.submittedAt,
		this.signaturePath,
		this.completedPdfPath,
		this.formData = const WorkOrderFormData(),
		this.startedAt,
		this.finishedAt,
		this.attachmentPaths = const [],
	});

	final String id;
	final String assignmentId;
	final String observations;
	final List<WorkOrderCheckItem> checklist;
	final DateTime submittedAt;
	final String? signaturePath;
	final String? completedPdfPath;
	final WorkOrderFormData formData;
	final DateTime? startedAt;
	final DateTime? finishedAt;
	final List<String> attachmentPaths;

	factory WorkOrderResponse.fromJson(Map<String, dynamic> m) {
		final raw = m["checklist"];
		final List<WorkOrderCheckItem> items;
		if (raw is List) {
			items = raw
					.map((e) => WorkOrderCheckItem.fromJson(
								Map<String, dynamic>.from(e as Map),
							))
					.toList();
		} else {
			items = [];
		}
		final paths = m["attachment_paths"];
		final List<String> attachments;
		if (paths is List) {
			attachments = paths.map((e) => e.toString()).toList();
		} else {
			attachments = [];
		}

		return WorkOrderResponse(
			id: m["id"] as String,
			assignmentId: m["assignment_id"] as String,
			observations: m["observations"] as String? ?? "",
			checklist: items,
			submittedAt: WorkOrder._parseTs(m["submitted_at"]) ?? DateTime.now().toUtc(),
			signaturePath: m["signature_path"] as String?,
			completedPdfPath: m["completed_pdf_path"] as String?,
			formData: WorkOrderFormData.fromJson(
				m["form_data"] is Map
						? Map<String, dynamic>.from(m["form_data"] as Map)
						: null,
			),
			startedAt: WorkOrder._parseTs(m["started_at"]),
			finishedAt: WorkOrder._parseTs(m["finished_at"]),
			attachmentPaths: attachments,
		);
	}
}
