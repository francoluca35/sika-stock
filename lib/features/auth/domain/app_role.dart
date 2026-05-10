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
		final v = value.trim().toUpperCase();
		for (final r in AppRole.values) {
			if (r.dbValue == v) return r;
		}
		return null;
	}

}
