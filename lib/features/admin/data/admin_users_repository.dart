import "package:supabase_flutter/supabase_flutter.dart";

import "../../auth/domain/app_role.dart";
import "../../auth/domain/profile_row.dart";

class AdminUsersRepository {
	AdminUsersRepository(this._client);

	final SupabaseClient _client;

	static const String _createUserFn = "create-user";
	static const String _updateUserFn = "update-user";

	Future<void> createUser({
		required String email,
		required String password,
		required String nombre,
		required String usuario,
		required AppRole rol,
	}) async {
		final res = await _client.functions.invoke(
			_createUserFn,
			body: <String, dynamic>{
				"email": email.trim(),
				"password": password,
				"nombre": nombre.trim(),
				"usuario": usuario.trim(),
				"rol": rol.dbValue,
			},
		);

		if (res.status != 200) {
			final err = res.data;
			final msg = err is Map && err["error"] != null
				? err["error"].toString()
				: "Error ${res.status}";
			throw Exception(msg);
		}
	}

	Future<void> updateUser({
		required String userId,
		required String email,
		required String nombre,
		required String usuario,
		required AppRole rol,
		String? password,
	}) async {
		final body = <String, dynamic>{
			"userId": userId,
			"email": email.trim(),
			"nombre": nombre.trim(),
			"usuario": usuario.trim(),
			"rol": rol.dbValue,
		};
		final p = password?.trim();
		if (p != null && p.isNotEmpty) {
			body["password"] = p;
		}

		final res = await _client.functions.invoke(
			_updateUserFn,
			body: body,
		);

		if (res.status != 200) {
			final err = res.data;
			final msg = err is Map && err["error"] != null
				? err["error"].toString()
				: "Error ${res.status}";
			throw Exception(msg);
		}
	}

	/// Listado para ADMIN/SUPERADMIN (requiere política `profiles_select_scope` en Supabase).
	Future<List<ProfileRow>> fetchAllProfiles() async {
		final rows = await _client
			.from("profiles")
			.select()
			.order("created_at", ascending: false)
			.limit(500);

		final list = rows as List<dynamic>;
		return list
			.map((e) => ProfileRow.fromMap(Map<String, dynamic>.from(e as Map)))
			.toList();
	}
}
