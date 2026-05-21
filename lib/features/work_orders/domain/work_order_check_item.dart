class WorkOrderCheckItem {
	const WorkOrderCheckItem({required this.label, this.done = false});

	final String label;
	final bool done;

	WorkOrderCheckItem copyWith({String? label, bool? done}) {
		return WorkOrderCheckItem(
			label: label ?? this.label,
			done: done ?? this.done,
		);
	}

	Map<String, dynamic> toJson() => {"label": label, "done": done};

	static WorkOrderCheckItem fromJson(Map<String, dynamic> m) {
		return WorkOrderCheckItem(
			label: (m["label"] as String?) ?? "",
			done: m["done"] == true,
		);
	}

	static List<WorkOrderCheckItem> defaultChecklist() => const [
				WorkOrderCheckItem(label: "Trabajo realizado según programa"),
				WorkOrderCheckItem(label: "Estado de equipos / válvulas verificado"),
				WorkOrderCheckItem(label: "Materiales y mano de obra registrados"),
				WorkOrderCheckItem(label: "Área de trabajo en orden y segura"),
			];

	/// Ítems desde pasos del procedimiento leídos del PDF, o checklist genérico.
	static List<WorkOrderCheckItem> fromProcedureSteps(List<String> steps) {
		if (steps.isEmpty) return defaultChecklist();
		return steps.map((s) => WorkOrderCheckItem(label: s)).toList();
	}
}
