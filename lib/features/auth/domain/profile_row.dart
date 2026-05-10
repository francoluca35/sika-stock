import "app_role.dart";

/// Fila de `profiles` (ajustá nombres de columnas si tu tabla difiere).
class ProfileRow {
	const ProfileRow({
		required this.id,
		this.email,
		this.nombre,
		this.usuario,
		this.rol,
	});

	final String id;
	final String? email;
	final String? nombre;
	final String? usuario;
	final AppRole? rol;

	factory ProfileRow.fromMap(Map<String, dynamic> map) {
		return ProfileRow(
			id: map["id"] as String,
			email: map["email"] as String?,
			nombre: map["nombre"] as String? ?? map["full_name"] as String?,
			usuario: map["usuario"] as String? ?? map["username"] as String?,
			rol: AppRole.fromDb(map["rol"]?.toString()),
		);
	}
}
