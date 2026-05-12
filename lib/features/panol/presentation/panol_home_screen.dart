import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";

/// Pantalla inicial **Pañol**: solo accesos; cada uno abre su propia pantalla.
class PanolHomeScreen extends ConsumerWidget {
	const PanolHomeScreen({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					_PanolHomeHeader(
						onLogout: () async {
							await ref.read(authRepositoryProvider).signOut();
						},
					),
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
							child: Align(
								alignment: Alignment.topCenter,
								child: ConstrainedBox(
									constraints: const BoxConstraints(maxWidth: 520),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: [
											Text(
												"Seleccioná una opción",
												style: TextStyle(
													color: Colors.grey.shade700,
													fontSize: 14,
												),
											),
											const SizedBox(height: 18),
											_PanolMenuCard(
												leadingDecoration: const BoxDecoration(
													color: AppTokens.redAction,
													borderRadius: BorderRadius.all(Radius.circular(12)),
												),
												leading: const Icon(
													Icons.inventory_2_outlined,
													color: Colors.white,
													size: 28,
												),
												title: "STOCK",
												subtitle: "Tabla, acciones y gestión de inventario",
												onTap: () => context.push("/panol/stock"),
											),
											const SizedBox(height: 12),
											_PanolMenuCard(
												leadingDecoration: BoxDecoration(
													color: AppTokens.blackNav,
													borderRadius: BorderRadius.circular(12),
												),
												leading: const Icon(
													Icons.assignment_outlined,
													color: Colors.white,
													size: 28,
												),
												title: "PEDIDOS",
												subtitle: "Analizar stock, pedir y últimos pedidos",
												onTap: () => context.push("/panol/pedidos"),
											),
											const SizedBox(height: 12),
											_PanolMenuCard(
												leadingDecoration: const BoxDecoration(
													color: AppTokens.whiteSurface,
													borderRadius: BorderRadius.all(Radius.circular(12)),
													border: Border.fromBorderSide(
														BorderSide(color: Colors.black87, width: 1.5),
													),
												),
												leading: const Icon(
													Icons.category_outlined,
													color: Colors.black87,
													size: 28,
												),
												title: "CATEGORÍAS",
												subtitle: "Ver, agregar, editar o eliminar categorías",
												onTap: () => context.push("/panol/categorias"),
											),
											const SizedBox(height: 12),
											_PanolMenuCard(
												leadingDecoration: const BoxDecoration(
													color: AppTokens.yellowAccent,
													borderRadius: BorderRadius.all(Radius.circular(12)),
												),
												leading: const Icon(
													Icons.show_chart,
													color: Colors.black87,
													size: 28,
												),
												title: "SEGUIMIENTO",
												subtitle: "Seguimiento de pedidos y órdenes",
												onTap: () => context.push("/panol/seguimiento"),
											),
										],
									),
								),
							),
						),
					),
				],
			),
		);
	}
}

class _PanolHomeHeader extends StatelessWidget {
	const _PanolHomeHeader({required this.onLogout});

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
								"PAÑOL",
								style: TextStyle(
									fontWeight: FontWeight.bold,
									fontSize: 20,
									letterSpacing: 0.8,
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
										const Text(
											"PAÑOL",
											style: TextStyle(
												fontWeight: FontWeight.w700,
												fontSize: 14,
												color: Colors.black87,
											),
										),
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

class _PanolMenuCard extends StatelessWidget {
	const _PanolMenuCard({
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
