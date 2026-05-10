import "app_role.dart";

/// Fila de `profiles` (ajustá nombres de columnas si tu tabla difiere).
class ProfileRow {
	const ProfileRow({
		required this.id,
		this.email,
		this.nombre,
		this.usuario,
		this.rol,
		this.createdAt,
	});

	final String id;
	final String? email;
	final String? nombre;
	final String? usuario;
	final AppRole? rol;
	final DateTime? createdAt;

	static DateTime? _parseCreated(dynamic v) {
		if (v == null) return null;
		if (v is DateTime) return v;
		return DateTime.tryParse(v.toString());
	}

	factory ProfileRow.fromMap(Map<String, dynamic> map) {
		return ProfileRow(
			id: map["id"] as String,
			email: map["email"] as String?,
			nombre: map["nombre"] as String? ?? map["full_name"] as String?,
			usuario: map["usuario"] as String? ?? map["username"] as String?,
			rol: AppRole.fromDb(map["rol"]?.toString()),
			createdAt: _parseCreated(map["created_at"]),
		);
	}
}
