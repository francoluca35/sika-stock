import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../../auth/domain/profile_row.dart";
import "../data/admin_users_repository.dart";

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>(
	(ref) => AdminUsersRepository(ref.watch(supabaseClientProvider)),
);

final usersListProvider = FutureProvider.autoDispose<List<ProfileRow>>((ref) async {
	return ref.watch(adminUsersRepositoryProvider).fetchAllProfiles();
});
