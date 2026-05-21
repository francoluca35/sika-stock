import "work_order_form_rows.dart";

/// Datos leídos del PDF oficial (solo lectura para mantenimiento).
class WorkOrderPdfMetadata {
	const WorkOrderPdfMetadata({
		this.company = "",
		this.plant = "",
		this.sector = "",
		this.location = "",
		this.orderType = "",
		this.date = "",
		this.responsible = "",
		this.orderNumber = "",
		this.receiver = "",
		this.tolerance = "",
		this.workDescription = "",
		this.procedure = "",
		this.requestedBy = "",
		this.priority = "",
		this.procedureSteps = const [],
	});

	final String company;
	final String plant;
	final String sector;
	final String location;
	final String orderType;
	final String date;
	final String responsible;
	final String orderNumber;
	final String receiver;
	final String tolerance;
	final String workDescription;
	final String procedure;
	final String requestedBy;
	final String priority;
	final List<String> procedureSteps;

	bool get hasAnyData =>
			company.isNotEmpty ||
			plant.isNotEmpty ||
			sector.isNotEmpty ||
			location.isNotEmpty ||
			orderType.isNotEmpty ||
			orderNumber.isNotEmpty ||
			date.isNotEmpty ||
			responsible.isNotEmpty ||
			procedure.isNotEmpty ||
			workDescription.isNotEmpty ||
			procedureSteps.isNotEmpty;

	WorkOrderPdfMetadata withReceiver(String name) {
		final n = name.trim();
		if (n.isEmpty) return this;
		return WorkOrderPdfMetadata(
			company: company,
			plant: plant,
			sector: sector,
			location: location,
			orderType: orderType,
			date: date,
			responsible: responsible,
			orderNumber: orderNumber,
			receiver: n,
			tolerance: tolerance,
			workDescription: workDescription,
			procedure: procedure,
			requestedBy: requestedBy,
			priority: priority,
			procedureSteps: procedureSteps,
		);
	}

	Map<String, dynamic> toJson() => {
				"company": company,
				"plant": plant,
				"sector": sector,
				"location": location,
				"orderType": orderType,
				"date": date,
				"responsible": responsible,
				"orderNumber": orderNumber,
				"receiver": receiver,
				"tolerance": tolerance,
				"workDescription": workDescription,
				"procedure": procedure,
				"requestedBy": requestedBy,
				"priority": priority,
				"procedureSteps": procedureSteps,
			};

	factory WorkOrderPdfMetadata.fromJson(Map<String, dynamic>? m) {
		if (m == null || m.isEmpty) return const WorkOrderPdfMetadata();
		final stepsRaw = m["procedureSteps"];
		final List<String> steps;
		if (stepsRaw is List) {
			steps = stepsRaw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
		} else {
			steps = [];
		}
		return WorkOrderPdfMetadata(
			company: str(m["company"]),
			plant: str(m["plant"]),
			sector: str(m["sector"]),
			location: str(m["location"]),
			orderType: str(m["orderType"]),
			date: str(m["date"]),
			responsible: str(m["responsible"]),
			orderNumber: str(m["orderNumber"]),
			receiver: str(m["receiver"]),
			tolerance: str(m["tolerance"]),
			workDescription: str(m["workDescription"]),
			procedure: str(m["procedure"]),
			requestedBy: str(m["requestedBy"]),
			priority: str(m["priority"]),
			procedureSteps: steps,
		);
	}

	static String str(dynamic v) => (v as String?)?.trim() ?? "";
}

/// Datos que completa mantenimiento al cerrar la OT.
class WorkOrderFormData {
	const WorkOrderFormData({
		this.workDescription = "",
		this.tasksNews = "",
		this.observations = "",
		this.materials = const [],
		this.labor = const [],
		this.counterState = "",
		this.startedAtIso,
		this.finishedAtIso,
	});

	final String workDescription;
	final String tasksNews;
	final String observations;
	final List<OtMaterialRow> materials;
	final List<OtLaborRow> labor;
	final String counterState;
	final String? startedAtIso;
	final String? finishedAtIso;

	Map<String, dynamic> toJson() => {
				"workDescription": workDescription,
				"tasksNews": tasksNews,
				"observations": observations,
				"materials": materials.map((e) => e.toJson()).toList(),
				"labor": labor.map((e) => e.toJson()).toList(),
				"counterState": counterState,
				if (startedAtIso != null) "startedAt": startedAtIso,
				if (finishedAtIso != null) "finishedAt": finishedAtIso,
			};

	factory WorkOrderFormData.fromJson(Map<String, dynamic>? m) {
		if (m == null || m.isEmpty) return const WorkOrderFormData();
		final mats = m["materials"];
		final lab = m["labor"];
		return WorkOrderFormData(
			workDescription: WorkOrderPdfMetadata.str(m["workDescription"]),
			tasksNews: WorkOrderPdfMetadata.str(m["tasksNews"]),
			observations: WorkOrderPdfMetadata.str(m["observations"]),
			materials: mats is List
					? mats
							.map((e) => OtMaterialRow.fromJson(Map<String, dynamic>.from(e as Map)))
							.toList()
					: const [],
			labor: lab is List
					? lab
							.map((e) => OtLaborRow.fromJson(Map<String, dynamic>.from(e as Map)))
							.toList()
					: const [],
			counterState: WorkOrderPdfMetadata.str(m["counterState"]),
			startedAtIso: m["startedAt"]?.toString(),
			finishedAtIso: m["finishedAt"]?.toString(),
		);
	}

	DateTime? get startedAt => startedAtIso == null ? null : DateTime.tryParse(startedAtIso!);
	DateTime? get finishedAt => finishedAtIso == null ? null : DateTime.tryParse(finishedAtIso!);
}
