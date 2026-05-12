import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../auth/application/auth_providers.dart";
import "../../../auth/domain/app_role.dart";
import "../panol_seguimiento_screen.dart";

/// Solo **Pañol**, **Supervisor**, **Admin** y **Superadmin** ven el seguimiento.
class SeguimientoAccessGate extends ConsumerWidget {
	const SeguimientoAccessGate({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final async = ref.watch(currentProfileProvider);
		return async.when(
			data: (perfil) {
				if (!appRolePuedeAccederASeguimiento(perfil?.rol)) {
					WidgetsBinding.instance.addPostFrameCallback((_) {
						if (!context.mounted) return;
						context.go("/home");
					});
					return Scaffold(
						backgroundColor: Colors.grey.shade100,
						body: const Center(child: CircularProgressIndicator()),
					);
				}
				return const PanolSeguimientoScreen();
			},
			loading: () => const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			),
			error: (_, __) {
				WidgetsBinding.instance.addPostFrameCallback((_) {
					if (!context.mounted) return;
					context.go("/home");
				});
				return Scaffold(
					backgroundColor: Colors.grey.shade100,
					body: const Center(child: CircularProgressIndicator()),
				);
			},
		);
	}
}
