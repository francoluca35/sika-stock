import "package:supabase_flutter/supabase_flutter.dart";

import "../../auth/domain/app_role.dart";

class AdminUsersRepository {
	AdminUsersRepository(this._client);

	final SupabaseClient _client;

	static const String _functionName = "create-user";

	Future<void> createUser({
		required String email,
		required String password,
		required String nombre,
		required String usuario,
		required AppRole rol,
	}) async {
		final res = await _client.functions.invoke(
			_functionName,
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
}
