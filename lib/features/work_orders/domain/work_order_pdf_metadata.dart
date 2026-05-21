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
	});

	final String company;
	final String plant;
	final String sector;
	final String location;
	final String orderType;
	final String date;
	final String responsible;
	final String orderNumber;
	/// En pantalla se completa con el técnico asignado (no viene del PDF).
	final String receiver;
	final String tolerance;
	final String workDescription;

	bool get hasAnyData =>
			company.isNotEmpty ||
			plant.isNotEmpty ||
			sector.isNotEmpty ||
			orderType.isNotEmpty ||
			orderNumber.isNotEmpty;

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
			};

	factory WorkOrderPdfMetadata.fromJson(Map<String, dynamic>? m) {
		if (m == null || m.isEmpty) return const WorkOrderPdfMetadata();
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
	});

	final String workDescription;
	final String tasksNews;
	final String observations;

	Map<String, dynamic> toJson() => {
				"workDescription": workDescription,
				"tasksNews": tasksNews,
				"observations": observations,
			};

	factory WorkOrderFormData.fromJson(Map<String, dynamic>? m) {
		if (m == null || m.isEmpty) return const WorkOrderFormData();
		return WorkOrderFormData(
			workDescription: WorkOrderPdfMetadata.str(m["workDescription"]),
			tasksNews: WorkOrderPdfMetadata.str(m["tasksNews"]),
			observations: WorkOrderPdfMetadata.str(m["observations"]),
		);
	}
}
