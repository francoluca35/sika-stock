import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";

/// Pantalla temporal post-login hasta rutas por rol.
class HomeScreen extends ConsumerWidget {
	const HomeScreen({super.key});

	static bool _canManageUsers(AppRole? r) =>
		r == AppRole.admin || r == AppRole.superadmin;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final profileAsync = ref.watch(currentProfileProvider);

		return Scaffold(
			appBar: AppBar(
				title: const Text("Sika Stock"),
				actions: [
					TextButton(
						onPressed: () async {
							await ref.read(authRepositoryProvider).signOut();
						},
						child: const Text(
							"Cerrar sesión",
							style: TextStyle(color: Colors.black87),
						),
					),
				],
			),
			body: profileAsync.when(
				data: (p) {
					final rol = p?.rol?.label ?? "—";
					final showAdmin = _canManageUsers(p?.rol);
					return Center(
						child: Padding(
							padding: AppTokens.padScreen,
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Text(
										"Sesión iniciada",
										style: Theme.of(context).textTheme.titleLarge,
									),
									const SizedBox(height: 12),
									Text("Rol: $rol", textAlign: TextAlign.center),
									if (showAdmin) ...[
										const SizedBox(height: 28),
										FilledButton.icon(
											style: FilledButton.styleFrom(
												backgroundColor: AppTokens.redAction,
												foregroundColor: Colors.white,
												minimumSize: const Size.fromHeight(48),
											),
											onPressed: () => context.push("/admin/nuevos-usuarios"),
											icon: const Icon(Icons.person_add_alt_1),
											label: const Text("Nuevos usuarios"),
										),
									],
								],
							),
						),
					);
				},
				loading: () => const Center(child: CircularProgressIndicator()),
				error: (e, _) => Center(child: Text("Error al cargar perfil: $e")),
			),
		);
	}
}
