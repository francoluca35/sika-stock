import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_tokens.dart";
import "../../admin/presentation/admin_panel_screen.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";

/// Post-login: panel admin según mockups (ADMIN / SUPERADMIN); resto de roles pantalla simple.
class HomeScreen extends ConsumerWidget {
	const HomeScreen({super.key});

	static bool _isAdminPanel(AppRole? r) =>
		r == AppRole.admin || r == AppRole.superadmin;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final profileAsync = ref.watch(currentProfileProvider);

		return profileAsync.when(
			data: (p) {
				if (_isAdminPanel(p?.rol)) {
					return const AdminPanelScreen();
				}
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
					body: Center(
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
									Text(
										"Rol: ${p?.rol?.label ?? "—"}",
										textAlign: TextAlign.center,
									),
								],
							),
						),
					),
				);
			},
			loading: () => const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			),
			error: (e, _) => Scaffold(
				backgroundColor: Colors.grey.shade100,
				body: SafeArea(
					child: Center(
						child: Padding(
							padding: AppTokens.padScreen,
							child: Column(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
									const SizedBox(height: 16),
									Text(
										"No se pudo cargar el perfil",
										style: Theme.of(context).textTheme.titleMedium?.copyWith(
													fontWeight: FontWeight.bold,
												),
										textAlign: TextAlign.center,
									),
									const SizedBox(height: 8),
									Text(
										"$e",
										style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
										textAlign: TextAlign.center,
									),
									const SizedBox(height: 24),
									TextButton(
										onPressed: () => ref.invalidate(currentProfileProvider),
										child: const Text("Reintentar"),
									),
								],
							),
						),
					),
				),
			),
		);
	}
}
