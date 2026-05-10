import "package:supabase_flutter/supabase_flutter.dart";

import "../domain/profile_row.dart";

class AuthRepository {
	AuthRepository(this._client);

	final SupabaseClient _client;

	Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

	Session? get currentSession => _client.auth.currentSession;

	User? get currentUser => _client.auth.currentUser;

	Future<AuthResponse> signInWithEmail({
		required String email,
		required String password,
	}) async {
		return _client.auth.signInWithPassword(
			email: email.trim(),
			password: password,
		);
	}

	Future<void> signOut() async {
		await _client.auth.signOut();
	}

	Future<void> requestPasswordReset(String email) async {
		await _client.auth.resetPasswordForEmail(email.trim());
	}

	Future<ProfileRow?> fetchCurrentProfile() async {
		final uid = _client.auth.currentUser?.id;
		if (uid == null) return null;

		try {
			final raw = await _client.rpc("get_my_profile");
			if (raw == null) return null;
			return ProfileRow.fromMap(Map<String, dynamic>.from(raw as Map));
		} catch (_) {
			final data = await _client.from("profiles").select().eq("id", uid).maybeSingle();
			if (data == null) return null;
			return ProfileRow.fromMap(Map<String, dynamic>.from(data));
		}
	}
}
