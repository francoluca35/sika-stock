import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../orders/presentation/widgets/maintenance_notifications_block.dart";
import "../application/compras_in_app_notifications_provider.dart";
import "../application/compras_stock_repository_provider.dart";

/// Pantalla inicial **Compras**: BIENVENIDO + tarjetas + barra inferior Compras · Perfil.
class ComprasHomeScreen extends ConsumerStatefulWidget {
	const ComprasHomeScreen({super.key});

	@override
	ConsumerState<ComprasHomeScreen> createState() => _ComprasHomeScreenState();
}

class _ComprasHomeScreenState extends ConsumerState<ComprasHomeScreen> {
	/// 0 = panel Compras, 1 = Perfil.
	int _tabIndex = 0;

	void _soon(String msg) {
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text("$msg — próximamente.")),
		);
	}

	@override
	Widget build(BuildContext context) {
		final bottomInset = MediaQuery.paddingOf(context).bottom;

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					_ComprasHeader(
						title: _tabIndex == 0 ? "COMPRAS" : "PERFIL",
						onRefresh: () => ScreenRefresh.comprasHome(ref),
						onLogout: () async {
							await ref.read(authRepositoryProvider).signOut();
						},
					),
					Expanded(
						child: IndexedStack(
							index: _tabIndex,
							children: [
								_ComprasMainTab(
									onPedidos: () => _soon(
										"Las órdenes de compra se registran en el sistema externo",
									),
									onHistorialPedidos: () =>
											context.push("/compras/historial-pedidos"),
									onHistorialCompras: () =>
											context.push("/compras/historial-compras"),
								),
								_ComprasPerfilTab(
									onLogout: () async {
										await ref.read(authRepositoryProvider).signOut();
									},
								),
							],
						),
					),
					_ComprasBottomBar(
						bottomPadding: bottomInset,
						selectedIndex: _tabIndex,
						onCompras: () => setState(() => _tabIndex = 0),
						onPerfil: () => setState(() => _tabIndex = 1),
					),
				],
			),
		);
	}
}

class _ComprasHeader extends StatelessWidget {
	const _ComprasHeader({
		required this.title,
		required this.onRefresh,
		required this.onLogout,
	});

	final String title;
	final VoidCallback onRefresh;
	final Future<void> Function() onLogout;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: AppTokens.yellowHeader,
			elevation: 2,
			shadowColor: Colors.black26,
			child: SafeArea(
				bottom: false,
				child: SizedBox(
					height: 52,
					child: Stack(
						alignment: Alignment.center,
						children: [
							Center(
								child: Text(
									title,
									style: const TextStyle(
										fontWeight: FontWeight.bold,
										fontSize: 18,
										letterSpacing: 0.9,
										color: Colors.black87,
									),
								),
							),
							Align(
								alignment: Alignment.centerRight,
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										IconButton(
											tooltip: "Recargar",
											icon: const Icon(Icons.refresh, color: Colors.black87),
											onPressed: onRefresh,
										),
										PopupMenuButton<String>(
									tooltip: "Más",
									offset: const Offset(0, 40),
									icon: const Icon(Icons.more_vert, color: Colors.black87),
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
						],
					),
				),
			),
		);
	}
}

class _ComprasNotificationsBlock extends ConsumerWidget {
	const _ComprasNotificationsBlock();

	Future<void> _borrarTodas(BuildContext context, WidgetRef ref) async {
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text("Borrar todos los avisos"),
				content: const Text(
					"¿Querés eliminar todos los avisos de pedidos desde pañol?",
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text("Cancelar"),
					),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text("Borrar todas"),
					),
				],
			),
		);
		if (ok != true) return;
		try {
			await ref.read(comprasStockRepositoryProvider).dismissAllMyNotifications();
			ref.invalidate(comprasInAppNotificationsProvider);
		} catch (e) {
			if (!context.mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudieron borrar los avisos: $e")),
			);
		}
	}

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final async = ref.watch(comprasInAppNotificationsProvider);
		return async.when(
			data: (list) {
				final panol = list
						.where((n) => n.kind == "panol_stock_request")
						.where((n) => n.isUnread)
						.take(8)
						.toList();
				if (panol.isEmpty) return const SizedBox.shrink();
				return Material(
					color: const Color(0xFFFFF8E1),
					borderRadius: BorderRadius.circular(AppTokens.radiusMd),
					elevation: 0,
					child: Container(
						decoration: BoxDecoration(
							borderRadius: BorderRadius.circular(AppTokens.radiusMd),
							border: Border.all(color: Colors.amber.shade700),
						),
						padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Row(
									children: [
										Icon(
											Icons.notifications_active_outlined,
											size: 20,
											color: Colors.amber.shade900,
										),
										const SizedBox(width: 8),
										Expanded(
											child: Text(
												"Nuevos pedidos desde pañol",
												style: TextStyle(
													fontWeight: FontWeight.bold,
													fontSize: 14,
													color: Colors.amber.shade900,
												),
											),
										),
										TextButton(
											onPressed: () => _borrarTodas(context, ref),
											style: TextButton.styleFrom(
												padding: const EdgeInsets.symmetric(horizontal: 8),
												minimumSize: Size.zero,
												tapTargetSize: MaterialTapTargetSize.shrinkWrap,
											),
											child: Text(
												"Borrar todas",
												style: TextStyle(
													fontSize: 12,
													fontWeight: FontWeight.w700,
													color: Colors.amber.shade900,
												),
											),
										),
									],
								),
								const SizedBox(height: 8),
								for (final n in panol)
									Padding(
										padding: const EdgeInsets.only(bottom: 8),
										child: Material(
											color: AppTokens.whiteSurface,
											borderRadius: BorderRadius.circular(8),
											child: Padding(
												padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
												child: Row(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Expanded(
															child: Column(
																crossAxisAlignment:
																		CrossAxisAlignment.start,
																children: [
																	Text(
																		n.title,
																		style: TextStyle(
																			fontWeight: FontWeight.w800,
																			fontSize: 13,
																			color: Colors.orange.shade900,
																		),
																	),
																	const SizedBox(height: 4),
																	Text(
																		n.body,
																		style: TextStyle(
																			fontSize: 12.5,
																			height: 1.25,
																			color: Colors.grey.shade800,
																		),
																	),
																],
															),
														),
														IconButton(
															tooltip: "Descartar aviso",
															icon: Icon(
																Icons.close,
																size: 20,
																color: Colors.grey.shade600,
															),
															padding: EdgeInsets.zero,
															constraints: const BoxConstraints(
																minWidth: 36,
																minHeight: 36,
															),
															onPressed: () async {
																await ref
																		.read(comprasStockRepositoryProvider)
																		.dismissNotification(n.id);
																ref.invalidate(
																	comprasInAppNotificationsProvider,
																);
															},
														),
													],
												),
											),
										),
									),
							],
						),
					),
				);
			},
			loading: () => const SizedBox.shrink(),
			error: (_, __) => const SizedBox.shrink(),
		);
	}
}

class _ComprasMainTab extends ConsumerWidget {
	const _ComprasMainTab({
		required this.onPedidos,
		required this.onHistorialPedidos,
		required this.onHistorialCompras,
	});

	final VoidCallback onPedidos;
	final VoidCallback onHistorialPedidos;
	final VoidCallback onHistorialCompras;

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		return SingleChildScrollView(
			padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
			child: Align(
				alignment: Alignment.topCenter,
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 520),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Row(
								crossAxisAlignment: CrossAxisAlignment.center,
								children: [
									Container(
										width: 52,
										height: 52,
										decoration: const BoxDecoration(
											color: AppTokens.yellowHeader,
											shape: BoxShape.circle,
										),
										child: const Icon(
											Icons.shopping_cart_outlined,
											color: Colors.black87,
											size: 28,
										),
									),
									const SizedBox(width: 14),
									const Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text(
													"BIENVENIDO",
													style: TextStyle(
														fontWeight: FontWeight.bold,
														fontSize: 22,
														letterSpacing: 0.6,
														color: Colors.black87,
													),
												),
												SizedBox(height: 4),
												Text(
													"Rol de Compras",
													style: TextStyle(
														fontSize: 14,
														color: Colors.black54,
														fontWeight: FontWeight.w500,
													),
												),
											],
										),
									),
								],
							),
							const SizedBox(height: 16),
							const MaintenanceNotificationsBlock(),
							const SizedBox(height: 12),
							const _ComprasNotificationsBlock(),
							const SizedBox(height: 12),
							_ComprasMenuCard(
								leadingDecoration: const BoxDecoration(
									color: AppTokens.redAction,
									borderRadius: BorderRadius.all(Radius.circular(12)),
								),
								leading: const Icon(
									Icons.inventory_2_outlined,
									color: Colors.white,
									size: 28,
								),
								title: "PEDIDOS",
								subtitle: "Crear y gestionar pedidos de compra",
								onTap: onPedidos,
							),
							const SizedBox(height: 12),
							_ComprasMenuCard(
								leadingDecoration: BoxDecoration(
									color: AppTokens.blackNav,
									borderRadius: BorderRadius.circular(12),
								),
								leading: const Icon(
									Icons.schedule,
									color: Colors.white,
									size: 28,
								),
								title: "HISTORIAL DE PEDIDOS",
								subtitle: "Ver el historial de pedidos realizados",
								onTap: onHistorialPedidos,
							),
							const SizedBox(height: 12),
							_ComprasMenuCard(
								leadingDecoration: const BoxDecoration(
									color: AppTokens.yellowHeader,
									borderRadius: BorderRadius.all(Radius.circular(12)),
								),
								leading: const Icon(
									Icons.shopping_bag_outlined,
									color: Colors.black87,
									size: 28,
								),
								title: "HISTORIAL DE COMPRAS",
								subtitle: "Ver el historial de compras realizadas",
								onTap: onHistorialCompras,
							),
						],
					),
				),
			),
		);
	}
}

class _ComprasPerfilTab extends StatelessWidget {
	const _ComprasPerfilTab({required this.onLogout});

	final Future<void> Function() onLogout;

	@override
	Widget build(BuildContext context) {
		return Center(
			child: Padding(
				padding: const EdgeInsets.all(24),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						CircleAvatar(
							radius: 36,
							backgroundColor: Colors.grey.shade300,
							child: Icon(Icons.person, size: 40, color: Colors.grey.shade700),
						),
						const SizedBox(height: 16),
						Text(
							"Perfil",
							style: Theme.of(context).textTheme.titleLarge?.copyWith(
										fontWeight: FontWeight.bold,
									),
						),
						const SizedBox(height: 8),
						Text(
							"Opciones de cuenta — próximamente.",
							textAlign: TextAlign.center,
							style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
						),
						const SizedBox(height: 28),
						OutlinedButton.icon(
							onPressed: () async => onLogout(),
							icon: const Icon(Icons.logout),
							label: const Text("Cerrar sesión"),
						),
					],
				),
			),
		);
	}
}

class _ComprasBottomBar extends StatelessWidget {
	const _ComprasBottomBar({
		required this.bottomPadding,
		required this.selectedIndex,
		required this.onCompras,
		required this.onPerfil,
	});

	final double bottomPadding;
	final int selectedIndex;
	final VoidCallback onCompras;
	final VoidCallback onPerfil;

	Color _color(int index) =>
		selectedIndex == index ? AppTokens.yellowAccent : Colors.white70;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: AppTokens.blackNav,
			child: Padding(
				padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomPadding),
				child: Row(
					mainAxisAlignment: MainAxisAlignment.spaceEvenly,
					children: [
						_ComprasBottomItem(
							label: "Compras",
							icon: Icons.shopping_cart,
							color: _color(0),
							onTap: onCompras,
						),
						_ComprasBottomItem(
							label: "Perfil",
							icon: Icons.person_outline,
							color: _color(1),
							onTap: onPerfil,
						),
					],
				),
			),
		);
	}
}

class _ComprasBottomItem extends StatelessWidget {
	const _ComprasBottomItem({
		required this.label,
		required this.icon,
		required this.color,
		required this.onTap,
	});

	final String label;
	final IconData icon;
	final Color color;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		return InkWell(
			onTap: onTap,
			child: Padding(
				padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						Icon(icon, color: color, size: 26),
						const SizedBox(height: 4),
						Text(
							label,
							style: TextStyle(
								color: color,
								fontWeight: FontWeight.w600,
								fontSize: 11,
							),
						),
					],
				),
			),
		);
	}
}

class _ComprasMenuCard extends StatelessWidget {
	const _ComprasMenuCard({
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
