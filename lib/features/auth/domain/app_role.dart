/// Roles alineados al backend (Postgres enum / texto en `profiles.rol`).
/// En alta desde la app no se ofrecen ADMIN ni SUPERADMIN salvo SUPERADMIN
/// (solo SUPERADMIN puede elegir SUPERADMIN; ADMIN se asigna solo en BD).
enum AppRole {
	mantenimiento("MANTENIMIENTO", "Mantenimiento"),
	supervisor("SUPERVISOR", "Supervisor"),
	panol("PANOL", "Pañol"),
	compras("COMPRAS", "Compras"),
	admin("ADMIN", "Admin"),
	superadmin("SUPERADMIN", "Superadmin");

	const AppRole(this.dbValue, this.label);

	final String dbValue;
	final String label;

	static AppRole? fromDb(String? value) {
		if (value == null) return null;
		var v = value.trim();
		v = v.replaceAll(RegExp(r"[\uFEFF\u200B]"), "");
		v = v.toUpperCase();
		// Sinónimos que a veces aparecen en BD / migraciones.
		if (v == "MAINTENANCE") {
			return AppRole.mantenimiento;
		}
		for (final r in AppRole.values) {
			if (r.dbValue == v) return r;
		}
		return null;
	}

}
