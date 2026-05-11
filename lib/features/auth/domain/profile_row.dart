import "app_role.dart";

/// Fila de `profiles` (ajustá nombres de columnas si tu tabla difiere).
class ProfileRow {
	const ProfileRow({
		required this.id,
		this.email,
		this.nombre,
		this.usuario,
		this.rol,
		this.rolDb,
		this.createdAt,
	});

	final String id;
	final String? email;
	final String? nombre;
	final String? usuario;
	final AppRole? rol;

	/// Valor crudo de `profiles.rol` (útil si el enum en app no reconoce un sinónimo de BD).
	final String? rolDb;
	final DateTime? createdAt;

	static DateTime? _parseCreated(dynamic v) {
		if (v == null) return null;
		if (v is DateTime) return v;
		return DateTime.tryParse(v.toString());
	}

	static String? _str(dynamic v) {
		if (v == null) return null;
		if (v is String) {
			final t = v.trim();
			return t.isEmpty ? null : t;
		}
		return v.toString().trim().isEmpty ? null : v.toString().trim();
	}

	factory ProfileRow.fromMap(Map<String, dynamic> map) {
		final rawRol = _str(map["rol"]) ?? _str(map["role"]);
		return ProfileRow(
			id: _str(map["id"]) ?? map["id"].toString(),
			email: _str(map["email"]),
			nombre: _str(map["nombre"]) ?? _str(map["full_name"]),
			usuario: _str(map["usuario"]) ?? _str(map["username"]),
			rol: AppRole.fromDb(rawRol),
			rolDb: rawRol,
			createdAt: _parseCreated(map["created_at"]),
		);
	}
}
