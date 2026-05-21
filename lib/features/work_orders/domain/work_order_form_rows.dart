/// Fila de materiales (plantilla OT Sika).
class OtMaterialRow {
	OtMaterialRow({
		this.date = "",
		this.code = "",
		this.quantity = "",
		this.description = "",
		this.unit = "",
		this.cost = "",
	});

	String date;
	String code;
	String quantity;
	String description;
	String unit;
	String cost;

	Map<String, dynamic> toJson() => {
				"date": date,
				"code": code,
				"quantity": quantity,
				"description": description,
				"unit": unit,
				"cost": cost,
			};

	static OtMaterialRow fromJson(Map<String, dynamic> m) {
		return OtMaterialRow(
			date: _s(m["date"]),
			code: _s(m["code"]),
			quantity: _s(m["quantity"]),
			description: _s(m["description"]),
			unit: _s(m["unit"]),
			cost: _s(m["cost"]),
		);
	}

	static String _s(dynamic v) => (v as String?)?.trim() ?? "";

	static OtMaterialRow empty() => OtMaterialRow();
}

/// Fila de mano de obra (plantilla OT Sika).
class OtLaborRow {
	OtLaborRow({
		this.date = "",
		this.name = "",
		this.normalHours = "",
		this.extraHours = "",
		this.hours100 = "",
		this.hours200 = "",
	});

	String date;
	String name;
	String normalHours;
	String extraHours;
	String hours100;
	String hours200;

	Map<String, dynamic> toJson() => {
				"date": date,
				"name": name,
				"normalHours": normalHours,
				"extraHours": extraHours,
				"hours100": hours100,
				"hours200": hours200,
			};

	static OtLaborRow fromJson(Map<String, dynamic> m) {
		return OtLaborRow(
			date: _s(m["date"]),
			name: _s(m["name"]),
			normalHours: _s(m["normalHours"]),
			extraHours: _s(m["extraHours"]),
			hours100: _s(m["hours100"]),
			hours200: _s(m["hours200"]),
		);
	}

	static String _s(dynamic v) => (v as String?)?.trim() ?? "";

	static OtLaborRow empty() => OtLaborRow();
}

/// Estados posibles del contador / cierre de planta.
abstract final class OtCounterStates {
	static const options = [
		"",
		"ok",
		"pendiente",
		"requiere_seguimiento",
	];

	static String label(String value) {
		switch (value) {
			case "ok":
				return "Contador OK";
			case "pendiente":
				return "Pendiente de revisión";
			case "requiere_seguimiento":
				return "Requiere seguimiento";
			default:
				return "Sin especificar";
		}
	}
}
