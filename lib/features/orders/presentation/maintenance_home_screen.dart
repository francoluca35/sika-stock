import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../supervisor/application/maintenance_orders_realtime_provider.dart";
import "widgets/maintenance_notifications_block.dart";
import "widgets/order_hub_bottom_bar.dart";

/// Inicio del rol **Mantenimiento**: hacer pedido e historial de pedidos (sin hub de gestión de stock).
class MaintenanceHomeScreen extends ConsumerWidget {
	const MaintenanceHomeScreen({super.key});

	void _soon(BuildContext context, String msg) {
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text("$msg — próximamente.")),
		);
	}

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		ref.watch(maintenanceOrdersRealtimeTickProvider);
		final bottomInset = MediaQuery.paddingOf(context).bottom;

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					_MaintenanceHomeHeader(
						onLogout: () async {
							await ref.read(authRepositoryProvider).signOut();
						},
					),
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
							child: Align(
								alignment: Alignment.topCenter,
								child: ConstrainedBox(
									constraints: const BoxConstraints(maxWidth: 520),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: [
											const MaintenanceNotificationsBlock(),
											const SizedBox(height: 8),
											Text(
												"Pedidos de mantenimiento",
												style: TextStyle(
													color: Colors.grey.shade700,
													fontSize: 14,
												),
											),
											const SizedBox(height: 18),
											_MaintenanceMenuCard(
												leadingDecoration: const BoxDecoration(
													color: AppTokens.redAction,
													borderRadius: BorderRadius.all(Radius.circular(12)),
												),
												leading: const Icon(
													Icons.add_shopping_cart_outlined,
													color: Colors.white,
													size: 28,
												),
												title: "HACER PEDIDO",
												subtitle: "Solicitar repuestos o materiales al supervisor",
												onTap: () => context.push("/pedidos/nuevo"),
											),
											const SizedBox(height: 16),
											_MaintenanceMenuCard(
												leadingDecoration: const BoxDecoration(
													color: Colors.black87,
													borderRadius: BorderRadius.all(Radius.circular(12)),
												),
												leading: const Icon(
													Icons.history,
													color: Colors.white,
													size: 28,
												),
												title: "HISTORIAL DE PEDIDOS",
												subtitle: "Ver el estado de tus pedidos y retiros",
												onTap: () => context.push("/pedidos/mis-pedidos"),
											),
										],
									),
								),
							),
						),
					),
					OrderHubBottomBar(
						bottomPadding: bottomInset,
						selectedIndex: null,
						onPedido: () => context.push("/pedidos/nuevo"),
						onHistorial: () => context.push("/pedidos/mis-pedidos"),
						onPerfil: () => _soon(context, "Perfil"),
					),
				],
			),
		);
	}
}

class _MaintenanceHomeHeader extends StatelessWidget {
	const _MaintenanceHomeHeader({required this.onLogout});

	final Future<void> Function() onLogout;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: AppTokens.yellowHeader,
			elevation: 2,
			shadowColor: Colors.black26,
			child: SafeArea(
				bottom: false,
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
					child: Row(
						children: [
							const Text(
								"MANTENIMIENTO",
								style: TextStyle(
									fontWeight: FontWeight.bold,
									fontSize: 18,
									letterSpacing: 0.6,
									color: Colors.black87,
								),
							),
							const Spacer(),
							PopupMenuButton<String>(
								tooltip: "Cuenta",
								offset: const Offset(0, 40),
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										CircleAvatar(
											radius: 18,
											backgroundColor: Colors.black87,
											child: const Icon(
												Icons.person,
												color: AppTokens.yellowHeader,
												size: 22,
											),
										),
										const SizedBox(width: 6),
										const Icon(Icons.arrow_drop_down, color: Colors.black87),
									],
								),
								onSelected: (value) async {
									if (value == "logout") await onLogout();
								},
								itemBuilder: (context) => [
									const PopupMenuItem(
										value: "logout",
										child: ListTile(
											contentPadding: EdgeInsets.zero,
											leading: Icon(Icons.logout, size: 22),
											title: Text("Cerrar sesión"),
										),
									),
								],
							),
						],
					),
				),
			),
		);
	}
}

class _MaintenanceMenuCard extends StatelessWidget {
	const _MaintenanceMenuCard({
		required this.leadingDecoration,
		required this.leading,
		required this.title,
		required this.subtitle,
		required this.onTap,
	});

	final BoxDecoration leadingDecoration;
	final Widget leading;
	final String title;
	final String subtitle;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: AppTokens.whiteSurface,
			borderRadius: BorderRadius.circular(AppTokens.radiusLg),
			elevation: 1,
			shadowColor: Colors.black12,
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(AppTokens.radiusLg),
				child: Ink(
					decoration: BoxDecoration(
						color: AppTokens.whiteSurface,
						borderRadius: BorderRadius.circular(AppTokens.radiusLg),
						border: Border.all(color: Colors.black87, width: 1.1),
					),
					child: Padding(
						padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
						child: Row(
							children: [
								Container(
									width: 56,
									height: 56,
									decoration: leadingDecoration,
									child: Center(child: leading),
								),
								const SizedBox(width: 14),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												title,
												style: const TextStyle(
													fontWeight: FontWeight.bold,
													fontSize: 13.5,
													letterSpacing: 0.25,
													height: 1.15,
													color: Colors.black87,
												),
											),
											const SizedBox(height: 4),
											Text(
												subtitle,
												style: TextStyle(
													fontSize: 12.5,
													height: 1.25,
													color: Colors.grey.shade700,
												),
											),
										],
									),
								),
								const Icon(Icons.chevron_right, color: Colors.black87, size: 26),
							],
						),
					),
				),
			),
		);
	}
}
