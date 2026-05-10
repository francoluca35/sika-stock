import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../data/auth_repository.dart";
import "../domain/profile_row.dart";

final supabaseClientProvider = Provider<SupabaseClient>(
	(ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
	(ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Perfil del usuario autenticado (null si no hay sesión o aún no cargó).
final currentProfileProvider = FutureProvider<ProfileRow?>((ref) async {
	final repo = ref.watch(authRepositoryProvider);
	if (repo.currentUser == null) return null;
	return repo.fetchCurrentProfile();
});
