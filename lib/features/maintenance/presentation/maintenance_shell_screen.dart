import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/profile_row.dart";
import "maintenance_welcome_tab.dart";
import "widgets/maintenance_bottom_nav_bar.dart";

/// Shell rol **Mantenimiento**: navegación inferior Pedido · Historial · Perfil.
class MaintenanceShellScreen extends ConsumerStatefulWidget {
	const MaintenanceShellScreen({super.key, required this.profile});

	final ProfileRow profile;

	@override
	ConsumerState<MaintenanceShellScreen> createState() =>
			_MaintenanceShellScreenState();
}

class _MaintenanceShellScreenState extends ConsumerState<MaintenanceShellScreen> {
	int _index = 0;

	@override
	Widget build(BuildContext context) {
		final bottomInset = MediaQuery.paddingOf(context).bottom;

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Expanded(
						child: IndexedStack(
							index: _index,
							children: [
								MaintenanceWelcomeTab(
									profile: widget.profile,
									onOpenHistorial: () => setState(() => _index = 1),
								),
								const _MaintenanceHistorialPlaceholder(),
								_MaintenanceProfileTab(
									profile: widget.profile,
									onSignOut: () async {
										await ref.read(authRepositoryProvider).signOut();
									},
								),
							],
						),
					),
					MaintenanceBottomNavBar(
						currentIndex: _index,
						bottomPadding: bottomInset,
						onTap: (i) => setState(() => _index = i),
					),
				],
			),
		);
	}
}

class _MaintenanceHistorialPlaceholder extends StatelessWidget {
	const _MaintenanceHistorialPlaceholder();

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Container(
					width: double.infinity,
					color: AppTokens.yellowHeader,
					child: SafeArea(
						bottom: false,
						child: SizedBox(
							height: 52,
							child: Center(
								child: Text(
									"HISTORIAL",
									style: TextStyle(
										fontWeight: FontWeight.bold,
										fontSize: 17,
										letterSpacing: 0.8,
										color: Colors.black87,
									),
								),
							),
						),
					),
				),
				Expanded(
					child: Center(
						child: Padding(
							padding: const EdgeInsets.all(24),
							child: Text(
								"Pestañas y listados de historial — próximamente\n(etapas 3 y 6).",
								textAlign: TextAlign.center,
								style: TextStyle(
									fontSize: 15,
									color: Colors.grey.shade700,
									height: 1.4,
								),
							),
						),
					),
				),
			],
		);
	}
}

class _MaintenanceProfileTab extends StatelessWidget {
	const _MaintenanceProfileTab({
		required this.profile,
		required this.onSignOut,
	});

	final ProfileRow profile;
	final Future<void> Function() onSignOut;

	@override
	Widget build(BuildContext context) {
		final rolLabel = profile.rol?.label ?? profile.rolDb ?? "—";

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				Container(
					width: double.infinity,
					color: AppTokens.yellowHeader,
					child: SafeArea(
						bottom: false,
						child: SizedBox(
							height: 52,
							child: Center(
								child: Text(
									"PERFIL",
									style: TextStyle(
										fontWeight: FontWeight.bold,
										fontSize: 17,
										letterSpacing: 0.8,
										color: Colors.black87,
									),
								),
							),
						),
					),
				),
				Expanded(
					child: SingleChildScrollView(
						padding: const EdgeInsets.all(20),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								if (profile.nombre != null && profile.nombre!.trim().isNotEmpty)
									_TextBlock(label: "Nombre", value: profile.nombre!.trim()),
								if (profile.email != null && profile.email!.trim().isNotEmpty)
									_TextBlock(label: "Correo", value: profile.email!.trim()),
								_TextBlock(label: "Rol", value: rolLabel),
								const SizedBox(height: 28),
								FilledButton(
									style: FilledButton.styleFrom(
										backgroundColor: AppTokens.redAction,
										foregroundColor: Colors.white,
										padding: const EdgeInsets.symmetric(vertical: 14),
									),
									onPressed: () async => onSignOut(),
									child: const Text("Cerrar sesión"),
								),
							],
						),
					),
				),
			],
		);
	}
}

class _TextBlock extends StatelessWidget {
	const _TextBlock({required this.label, required this.value});

	final String label;
	final String value;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 16),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						label,
						style: TextStyle(
							fontSize: 12,
							fontWeight: FontWeight.w600,
							color: Colors.grey.shade700,
						),
					),
					const SizedBox(height: 4),
					Text(
						value,
						style: const TextStyle(
							fontSize: 16,
							color: Colors.black87,
						),
					),
				],
			),
		);
	}
}
