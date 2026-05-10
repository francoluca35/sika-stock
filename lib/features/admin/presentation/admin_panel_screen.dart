import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/profile_row.dart";

/// Panel principal ADMIN / SUPERADMIN según mockups (desktop 3×2, mobile lista).
class AdminPanelScreen extends ConsumerWidget {
	const AdminPanelScreen({super.key});

	static const String _logoAsset = "assets/sika.png";

	static String _welcomeName(ProfileRow? p) {
		final n = p?.nombre?.trim();
		if (n != null && n.isNotEmpty) {
			final first = n.split(RegExp(r"\s+")).first;
			return first.toUpperCase();
		}
		return p?.rol?.label.toUpperCase() ?? "ADMIN";
	}

	Future<void> _signOut(WidgetRef ref) async {
		await ref.read(authRepositoryProvider).signOut();
	}

	void _soon(BuildContext context, String feature) {
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text("$feature — próximamente.")),
		);
	}

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final profileAsync = ref.watch(currentProfileProvider);

		return profileAsync.when(
			data: (p) {
				final welcome = _welcomeName(p);
				final bottomInset = MediaQuery.paddingOf(context).bottom;

				return Scaffold(
					backgroundColor: AppTokens.whiteSurface,
					body: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							_AdminYellowHeader(
								logoAsset: _logoAsset,
								isMobile: _isCompact(context),
								onLogout: () => _signOut(ref),
								profileLabel: p?.rol?.label.toUpperCase() ?? "ADMIN",
							),
							Expanded(
								child: SingleChildScrollView(
									padding: EdgeInsets.fromLTRB(
										16,
										_isCompact(context) ? 20 : 10,
										16,
										_isCompact(context) ? 24 : 12,
									),
									child: Center(
										child: ConstrainedBox(
											constraints: const BoxConstraints(maxWidth: 1000),
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.stretch,
												children: [
													Text(
														"BIENVENIDO, $welcome",
														style: TextStyle(
															fontWeight: FontWeight.bold,
															fontSize: _isCompact(context) ? 22 : 18,
															color: Colors.black87,
														),
													),
													SizedBox(height: _isCompact(context) ? 8 : 6),
													Text(
														"Selecciona una opción para gestionar el sistema",
														style: TextStyle(
															fontSize: _isCompact(context) ? 14 : 13,
															color: Colors.grey.shade700,
														),
													),
													SizedBox(height: _isCompact(context) ? 24 : 12),
													if (_isCompact(context))
														_MobileActionList(
															onCrearPerfil: () =>
																context.push("/admin/nuevos-usuarios"),
															onUsuarios: () =>
																_soon(context, "Usuarios"),
															onPedidos: () =>
																_soon(context, "Hacer pedidos"),
															onStock: () => _soon(context, "Stock"),
															onSeguimientos: () =>
																_soon(context, "Seguimientos"),
															onHistorial: () =>
																_soon(context, "Historial de pedidos"),
														)
													else
														_DesktopActionGrid(
															onCrearPerfil: () =>
																context.push("/admin/nuevos-usuarios"),
															onUsuarios: () =>
																_soon(context, "Usuarios"),
															onPedidos: () =>
																_soon(context, "Hacer pedidos"),
															onStock: () => _soon(context, "Stock"),
															onSeguimientos: () =>
																_soon(context, "Seguimientos"),
															onHistorial: () =>
																_soon(context, "Historial de pedidos"),
														),
												],
											),
										),
									),
								),
							),
							_AdminBottomBar(
								bottomPadding: bottomInset,
								onInicio: () {},
								onOrdenCompra: () =>
									_soon(context, "Crear orden de compra"),
								onConfig: () =>
									_soon(context, "Configuración"),
							),
						],
					),
				);
			},
			loading: () => const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			),
			error: (e, _) => Scaffold(
				body: Center(child: Text("Error: $e")),
			),
		);
	}

	bool _isCompact(BuildContext context) =>
		MediaQuery.sizeOf(context).width < 720;
}

class _AdminYellowHeader extends StatelessWidget {
	const _AdminYellowHeader({
		required this.logoAsset,
		required this.isMobile,
		required this.onLogout,
		required this.profileLabel,
	});

	final String logoAsset;
	final bool isMobile;
	final VoidCallback onLogout;
	final String profileLabel;

	@override
	Widget build(BuildContext context) {
		final bar = Container(
			width: double.infinity,
			color: AppTokens.yellowHeader,
			child: SafeArea(
				bottom: false,
				child: Padding(
					padding: EdgeInsets.fromLTRB(
						isMobile ? 6 : 8,
						10,
						10,
						10,
					),
					child: isMobile ? _mobileRow(context) : _desktopRow(context),
				),
			),
		);
		return bar;
	}

	Widget _mobileRow(BuildContext context) {
		return Row(
			crossAxisAlignment: CrossAxisAlignment.center,
			children: [
				Image.asset(
					logoAsset,
					height: 46,
					fit: BoxFit.contain,
					filterQuality: FilterQuality.high,
					alignment: Alignment.centerLeft,
					semanticLabel: "Logo Sika",
				),
				const Spacer(),
				_PopupProfile(label: profileLabel, onLogout: onLogout),
			],
		);
	}

	Widget _desktopRow(BuildContext context) {
		return Row(
			crossAxisAlignment: CrossAxisAlignment.center,
			children: [
				Image.asset(
					logoAsset,
					height: 72,
					fit: BoxFit.contain,
					filterQuality: FilterQuality.high,
					semanticLabel: "Logo Sika",
				),
				const SizedBox(width: 16),
				Expanded(
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						mainAxisSize: MainAxisSize.min,
						children: [
							const Text(
								"PANEL DE ADMINISTRADOR",
								style: TextStyle(
									fontWeight: FontWeight.bold,
									fontSize: 18,
									letterSpacing: 0.4,
									color: Colors.black87,
								),
							),
							const SizedBox(height: 4),
							Text(
								"Sistema de Gestión de Mantenimiento Industrial",
								style: TextStyle(
									fontSize: 13,
									color: Colors.black.withValues(alpha: 0.75),
								),
							),
						],
					),
				),
				_PopupProfile(label: profileLabel, onLogout: onLogout),
			],
		);
	}
}

class _PopupProfile extends StatelessWidget {
	const _PopupProfile({required this.label, required this.onLogout});

	final String label;
	final VoidCallback onLogout;

	@override
	Widget build(BuildContext context) {
		return PopupMenuButton<String>(
			onSelected: (v) {
				if (v == "logout") onLogout();
			},
			itemBuilder: (context) => [
				const PopupMenuItem(value: "logout", child: Text("Cerrar sesión")),
			],
			child: Padding(
				padding: const EdgeInsets.symmetric(horizontal: 8),
				child: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						CircleAvatar(
							radius: 18,
							backgroundColor: Colors.white,
							child: Icon(Icons.person, color: Colors.grey.shade800, size: 22),
						),
						const SizedBox(width: 8),
						Text(
							label,
							style: const TextStyle(
								fontWeight: FontWeight.bold,
								fontSize: 14,
								color: Colors.black87,
							),
						),
						const Icon(Icons.arrow_drop_down, color: Colors.black87),
					],
				),
			),
		);
	}
}

class _DesktopActionGrid extends StatelessWidget {
	const _DesktopActionGrid({
		required this.onCrearPerfil,
		required this.onUsuarios,
		required this.onPedidos,
		required this.onStock,
		required this.onSeguimientos,
		required this.onHistorial,
	});

	final VoidCallback onCrearPerfil;
	final VoidCallback onUsuarios;
	final VoidCallback onPedidos;
	final VoidCallback onStock;
	final VoidCallback onSeguimientos;
	final VoidCallback onHistorial;

	@override
	Widget build(BuildContext context) {
		return LayoutBuilder(
			builder: (context, c) {
				final w = c.maxWidth;
				final cross = w >= 900 ? 3 : 2;
				return GridView.count(
					crossAxisCount: cross,
					shrinkWrap: true,
					physics: const NeverScrollableScrollPhysics(),
					mainAxisSpacing: 12,
					crossAxisSpacing: 12,
					childAspectRatio: cross == 3 ? 1.42 : 1.18,
					children: [
						_DesktopCard(
							bg: AppTokens.yellowHeader,
							fg: Colors.black87,
							icon: Icons.person_add_alt_1,
							title: "CREAR PERFIL",
							subtitle: "Crea nuevos perfiles de usuario",
							onTap: onCrearPerfil,
						),
						_DesktopCard(
							bg: AppTokens.redAction,
							fg: Colors.white,
							icon: Icons.groups_outlined,
							title: "USUARIOS",
							subtitle: "Gestiona los usuarios del sistema",
							onTap: onUsuarios,
						),
						_DesktopCard(
							bg: Colors.white,
							fg: Colors.black87,
							border: Border.all(color: Colors.black87, width: 1.5),
							icon: Icons.add_shopping_cart_outlined,
							title: "HACER PEDIDOS",
							subtitle: "Realiza nuevos pedidos de mantenimiento",
							onTap: onPedidos,
							iconBadge: true,
						),
						_DesktopCard(
							bg: Colors.white,
							fg: Colors.black87,
							border: Border.all(color: Colors.black87, width: 1.5),
							icon: Icons.inventory_2_outlined,
							title: "STOCK",
							subtitle: "Consulta y gestiona el inventario",
							onTap: onStock,
						),
						_DesktopCard(
							bg: AppTokens.yellowHeader,
							fg: Colors.black87,
							icon: Icons.bar_chart_rounded,
							title: "SEGUIMIENTOS",
							subtitle: "Da seguimiento a los pedidos realizados",
							onTap: onSeguimientos,
						),
						_DesktopCard(
							bg: AppTokens.blackNav,
							fg: Colors.white,
							icon: Icons.assignment_outlined,
							title: "HISTORIAL DE PEDIDOS",
							subtitle: "Consulta el historial de todos los pedidos",
							onTap: onHistorial,
							subtitleLight: true,
						),
					],
				);
			},
		);
	}
}

class _DesktopCard extends StatelessWidget {
	const _DesktopCard({
		required this.bg,
		required this.fg,
		required this.icon,
		required this.title,
		required this.subtitle,
		required this.onTap,
		this.border,
		this.iconBadge = false,
		this.subtitleLight = false,
	});

	static const double _iconSize = 46;

	final Color bg;
	final Color fg;
	final IconData icon;
	final String title;
	final String subtitle;
	final VoidCallback onTap;
	final BoxBorder? border;
	final bool iconBadge;
	final bool subtitleLight;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: Colors.transparent,
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(AppTokens.radiusLg),
				child: Ink(
					decoration: BoxDecoration(
						color: bg,
						borderRadius: BorderRadius.circular(AppTokens.radiusLg),
						border: border,
					),
					child: Padding(
						padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							crossAxisAlignment: CrossAxisAlignment.center,
							children: [
								SizedBox(
									height: _iconSize + 6,
									child: Center(
										child: iconBadge
											? Stack(
												clipBehavior: Clip.none,
												alignment: Alignment.center,
												children: [
													Icon(icon, size: _iconSize, color: fg),
													Positioned(
														right: -5,
														top: -3,
														child: Container(
															padding: const EdgeInsets.all(3),
															decoration: const BoxDecoration(
																color: AppTokens.redAction,
																shape: BoxShape.circle,
															),
															child: const Icon(Icons.add, color: Colors.white, size: 13),
														),
													),
												],
											)
											: Icon(icon, size: _iconSize, color: fg),
									),
								),
								const SizedBox(height: 8),
								Text(
									title,
									textAlign: TextAlign.center,
									maxLines: 2,
									overflow: TextOverflow.ellipsis,
									style: TextStyle(
										fontWeight: FontWeight.bold,
										fontSize: 13,
										letterSpacing: 0.3,
										height: 1.12,
										color: fg,
									),
								),
								const SizedBox(height: 5),
								Text(
									subtitle,
									textAlign: TextAlign.center,
									maxLines: 3,
									overflow: TextOverflow.ellipsis,
									style: TextStyle(
										fontSize: 11,
										height: 1.25,
										color: subtitleLight
											? Colors.white.withValues(alpha: 0.92)
											: fg.withValues(alpha: 0.82),
									),
								),
							],
						),
					),
				),
			),
		);
	}
}

class _MobileActionList extends StatelessWidget {
	const _MobileActionList({
		required this.onCrearPerfil,
		required this.onUsuarios,
		required this.onPedidos,
		required this.onStock,
		required this.onSeguimientos,
		required this.onHistorial,
	});

	final VoidCallback onCrearPerfil;
	final VoidCallback onUsuarios;
	final VoidCallback onPedidos;
	final VoidCallback onStock;
	final VoidCallback onSeguimientos;
	final VoidCallback onHistorial;

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				_MobileTile(
					leadingBg: AppTokens.yellowHeader,
					icon: Icons.person_add_alt_1,
					iconColor: Colors.black87,
					title: "CREAR PERFIL",
					subtitle: "Crea nuevos perfiles de usuario",
					onTap: onCrearPerfil,
				),
				const SizedBox(height: 12),
				_MobileTile(
					leadingBg: AppTokens.redAction,
					icon: Icons.groups_outlined,
					iconColor: Colors.white,
					title: "USUARIOS",
					subtitle: "Gestiona los usuarios del sistema",
					onTap: onUsuarios,
				),
				const SizedBox(height: 12),
				_MobileTile(
					leadingBg: Colors.white,
					border: Border.all(color: Colors.black87, width: 1.2),
					icon: Icons.add_shopping_cart_outlined,
					iconColor: Colors.black87,
					title: "HACER PEDIDOS",
					subtitle: "Realiza nuevos pedidos de mantenimiento",
					onTap: onPedidos,
					badge: true,
				),
				const SizedBox(height: 12),
				_MobileTile(
					leadingBg: AppTokens.yellowHeader,
					icon: Icons.inventory_2_outlined,
					iconColor: Colors.black87,
					title: "STOCK",
					subtitle: "Consulta y gestiona el inventario",
					onTap: onStock,
				),
				const SizedBox(height: 12),
				_MobileTile(
					leadingBg: AppTokens.yellowHeader,
					icon: Icons.bar_chart_rounded,
					iconColor: Colors.black87,
					title: "SEGUIMIENTOS",
					subtitle: "Da seguimiento a los pedidos realizados",
					onTap: onSeguimientos,
				),
				const SizedBox(height: 12),
				_MobileTile(
					leadingBg: AppTokens.blackNav,
					icon: Icons.assignment_outlined,
					iconColor: Colors.white,
					title: "HISTORIAL DE PEDIDOS",
					subtitle: "Consulta el historial de todos los pedidos",
					onTap: onHistorial,
					darkTile: true,
				),
			],
		);
	}
}

class _MobileTile extends StatelessWidget {
	const _MobileTile({
		required this.leadingBg,
		required this.icon,
		required this.iconColor,
		required this.title,
		required this.subtitle,
		required this.onTap,
		this.border,
		this.badge = false,
		this.darkTile = false,
	});

	final Color leadingBg;
	final IconData icon;
	final Color iconColor;
	final String title;
	final String subtitle;
	final VoidCallback onTap;
	final BoxBorder? border;
	final bool badge;
	final bool darkTile;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: Colors.white,
			borderRadius: BorderRadius.circular(AppTokens.radiusLg),
			elevation: 1,
			shadowColor: Colors.black26,
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(AppTokens.radiusLg),
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
					child: Row(
						children: [
							Container(
								width: 56,
								height: 56,
								decoration: BoxDecoration(
									color: leadingBg,
									borderRadius: BorderRadius.circular(12),
									border: border,
								),
								child: Stack(
									alignment: Alignment.center,
									children: [
										if (badge)
											Stack(
												clipBehavior: Clip.none,
												children: [
													Icon(icon, color: iconColor, size: 28),
													Positioned(
														right: 6,
														top: 6,
														child: Container(
															padding: const EdgeInsets.all(2),
															decoration: const BoxDecoration(
																color: AppTokens.redAction,
																shape: BoxShape.circle,
															),
															child: const Icon(Icons.add, color: Colors.white, size: 12),
														),
													),
												],
											)
										else
											Icon(icon, color: iconColor, size: 28),
									],
								),
							),
							const SizedBox(width: 14),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											title,
											style: TextStyle(
												fontWeight: FontWeight.bold,
												fontSize: 14,
												letterSpacing: 0.3,
												color: darkTile ? Colors.black87 : Colors.black87,
											),
										),
										const SizedBox(height: 4),
										Text(
											subtitle,
											style: TextStyle(
												fontSize: 12.5,
												color: Colors.grey.shade700,
												height: 1.2,
											),
										),
									],
								),
							),
							Icon(Icons.chevron_right, color: Colors.grey.shade600),
						],
					),
				),
			),
		);
	}
}

class _AdminBottomBar extends StatelessWidget {
	const _AdminBottomBar({
		required this.bottomPadding,
		required this.onInicio,
		required this.onOrdenCompra,
		required this.onConfig,
	});

	final double bottomPadding;
	final VoidCallback onInicio;
	final VoidCallback onOrdenCompra;
	final VoidCallback onConfig;

	static Widget _divider() =>
		Container(width: 1, height: 36, color: Colors.white24);

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: EdgeInsets.only(bottom: bottomPadding),
			color: AppTokens.blackNav,
			child: SafeArea(
				top: false,
				child: SizedBox(
					height: 58,
					child: Row(
						children: [
							Expanded(
								child: InkWell(
									onTap: onOrdenCompra,
									child: const Column(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(
												Icons.request_quote_outlined,
												color: Colors.white,
												size: 24,
											),
											SizedBox(height: 2),
											Text(
												"CREAR ORDEN\nDE COMPRA",
												textAlign: TextAlign.center,
												style: TextStyle(
													color: Colors.white,
													fontWeight: FontWeight.bold,
													fontSize: 9,
													height: 1.15,
													letterSpacing: 0.2,
												),
											),
										],
									),
								),
							),
							_divider(),
							Expanded(
								child: InkWell(
									onTap: onInicio,
									child: const Column(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(Icons.home, color: AppTokens.yellowAccent, size: 26),
											SizedBox(height: 2),
											Text(
												"INICIO",
												style: TextStyle(
													color: AppTokens.yellowAccent,
													fontWeight: FontWeight.bold,
													fontSize: 12,
													letterSpacing: 0.6,
												),
											),
										],
									),
								),
							),
							_divider(),
							Expanded(
								child: InkWell(
									onTap: onConfig,
									child: const Column(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(Icons.settings, color: Colors.white, size: 24),
											SizedBox(height: 2),
											Text(
												"CONFIGURACIÓN",
												style: TextStyle(
													color: Colors.white,
													fontWeight: FontWeight.bold,
													fontSize: 11,
													letterSpacing: 0.4,
												),
											),
										],
									),
								),
							),
						],
					),
				),
			),
		);
	}
}
