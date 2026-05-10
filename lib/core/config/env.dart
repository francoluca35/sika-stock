import "package:flutter_dotenv/flutter_dotenv.dart";

/// Variables desde `.env` (asset en `pubspec.yaml`). No subir `.env` al repo.
abstract final class Env {
	static Future<void> load() async {
		await dotenv.load(fileName: ".env");
	}

	static String get supabaseUrl {
		final v = dotenv.env["SUPABASE_URL"]?.trim();
		if (v == null || v.isEmpty) {
			throw StateError("SUPABASE_URL falta o está vacío en .env");
		}
		var u = v;
		while (u.endsWith("/")) {
			u = u.substring(0, u.length - 1);
		}
		return u;
	}

	static String get supabaseAnonKey {
		final v = dotenv.env["SUPABASE_ANON_KEY"]?.trim();
		if (v == null || v.isEmpty) {
			throw StateError("SUPABASE_ANON_KEY falta o está vacío en .env");
		}
		return v;
	}
}
