import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../admin/presentation/widgets/admin_shell_bottom_bar.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/profile_row.dart";
import "../../orders/presentation/widgets/maintenance_notifications_block.dart";
import "../application/maintenance_orders_provider.dart";

/// Pantalla inicial **Supervisor**: accesos rápidos a pedidos, stock y seguimiento.
class SupervisorHomeScreen extends ConsumerWidget {
	const SupervisorHomeScreen({super.key});

	static const String _logoAsset = "assets/sika.png";

	/// Primer nombre capitalizado, o usuario / email local si no hay nombre.
	static String _welcomeName(ProfileRow? p) {
		final n = p?.nombre?.trim();
		if (n != null && n.isNotEmpty) {
			final first = n.split(RegExp(r"\s+")).firstWhere((s) => s.isNotEmpty, orElse: () => n);
			if (first.isEmpty) return "usuario";
			return "${first[0].toUpperCase()}${first.length > 1 ? first.substring(1).toLowerCase() : ""}";
		}
		final u = p?.usuario?.trim();
		if (u != null && u.isNotEmpty) return u;
		final e = p?.email?.trim();
		if (e != null && e.isNotEmpty) {
			final local = e.split("@").first;
			if (local.isNotEmpty) return local;
		}
		return "usuario";
	}

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final profileAsync = ref.watch(currentProfileProvider);

		return profileAsync.when(
			data: (p) {
				final nombre = _welcomeName(p);
				final bottomInset = MediaQuery.paddingOf(context).bottom;
				final pedidosPendientesSupervisor =
					ref.watch(supervisorPendingMaintenanceBadgeProvider);
				return Scaffold(
					backgroundColor: AppTokens.surfacePage,
					body: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							_SupervisorHeader(
								logoAsset: _logoAsset,
								onRefresh: () => ScreenRefresh.supervisorHome(ref),
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
													const MaintenanceNotificationsBlock(),
													const SizedBox(height: 12),
													Text(
														"Bienvenido, $nombre",
														style: const TextStyle(
															fontWeight: FontWeight.bold,
															fontSize: 20,
															color: Colors.black87,
															height: 1.25,
														),
													),
													const SizedBox(height: 8),
													Text(
														"Seleccioná una opción",
														style: TextStyle(
															color: Colors.grey.shade700,
															fontSize: 14,
														),
													),
													const SizedBox(height: 18),
											_SupervisorMenuCard(
												leadingDecoration: const BoxDecoration(
													color: Colors.white,
													borderRadius: BorderRadius.all(Radius.circular(12)),
													border: Border.fromBorderSide(
														BorderSide(color: Colors.black87, width: 1.3),
													),
												),
												leading: const _LeadingIconBadge(
													icon: Icons.checklist_outlined,
													iconColor: Colors.black87,
												),
												title: "ELEGIR PRODUCTO",
												subtitle:
														"Ver stock en catálogo: confirmar retiro con pañol o derivar si no hay",
												onTap: () => context.push("/supervisor/elegir-producto-retiro"),
											),
											const SizedBox(height: 12),
											_SupervisorMenuCard(
												leadingDecoration: const BoxDecoration(
													color: AppTokens.yellowHeader,
													borderRadius: BorderRadius.all(Radius.circular(12)),
												),
												leading: const Icon(
													Icons.inventory_2_outlined,
													color: Colors.black87,
													size: 28,
												),
												title: "STOCK",
												subtitle: "Consultar inventario y movimientos",
												onTap: () => context.push("/supervisor/stock"),
											),
											const SizedBox(height: 12),
											_SupervisorMenuCard(
												leadingDecoration: const BoxDecoration(
													color: AppTokens.redAction,
													borderRadius: BorderRadius.all(Radius.circular(12)),
												),
												leading: const Icon(
													Icons.handyman_outlined,
													color: Colors.white,
													size: 28,
												),
												title: "PEDIDOS DE MANTENIMIENTO",
												subtitle: "Gestionar solicitudes de mantenimiento",
												badgeCount: pedidosPendientesSupervisor,
												onTap: () => context.push(
														"/supervisor/pedidos-mantenimiento",
													),
											),
											const SizedBox(height: 12),
											_SupervisorMenuCard(
												leadingDecoration: const BoxDecoration(
													color: AppTokens.whiteSurface,
													borderRadius: BorderRadius.all(Radius.circular(12)),
													border: Border.fromBorderSide(
														BorderSide(color: Colors.black87, width: 1.5),
													),
												),
												leading: const Icon(
													Icons.history_edu_outlined,
													color: Colors.black87,
													size: 28,
												),
												title: "HISTORIAL MANTENIMIENTO",
												subtitle:
														"Entregados, consulta pañol y cancelados",
												onTap: () =>
														context.push("/supervisor/historial-pedidos"),
											),
											const SizedBox(height: 12),
											_SupervisorMenuCard(
												leadingDecoration: const BoxDecoration(
													color: AppTokens.yellowAccent,
													borderRadius: BorderRadius.all(Radius.circular(12)),
												),
												leading: const Icon(
													Icons.bar_chart_rounded,
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
							AdminShellBottomBar(
								bottomPadding: bottomInset,
								showCrearOrdenCompra: false,
								onInicio: () {},
								onOrdenCompra: () {},
								onConfig: () => context.push("/configuracion"),
							),
						],
					),
				);
			},
			loading: () => Scaffold(
				backgroundColor: AppTokens.surfacePage,
				body: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						_SupervisorHeader(
							logoAsset: _logoAsset,
							onRefresh: () => ScreenRefresh.supervisorHome(ref),
							onLogout: () async {
								await ref.read(authRepositoryProvider).signOut();
							},
						),
						const Expanded(
							child: Center(child: CircularProgressIndicator()),
						),
					],
				),
			),
			error: (_, __) => Scaffold(
				backgroundColor: AppTokens.surfacePage,
				body: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						_SupervisorHeader(
							logoAsset: _logoAsset,
							onRefresh: () => ScreenRefresh.supervisorHome(ref),
							onLogout: () async {
								await ref.read(authRepositoryProvider).signOut();
							},
						),
						Expanded(
							child: Center(
								child: Padding(
									padding: const EdgeInsets.all(24),
									child: Text(
										"No se pudo cargar tu perfil.",
										textAlign: TextAlign.center,
										style: TextStyle(color: Colors.grey.shade700),
									),
								),
							),
						),
					],
				),
			),
		);
	}
}

class _SupervisorHeader extends StatelessWidget {
	const _SupervisorHeader({
		required this.logoAsset,
		required this.onRefresh,
		required this.onLogout,
	});

	final String logoAsset;
	final VoidCallback onRefresh;
	final VoidCallback onLogout;

	@override
	Widget build(BuildContext context) {
		return Container(
			width: double.infinity,
			decoration: BoxDecoration(
				color: AppTokens.yellowHeader,
				boxShadow: [
					BoxShadow(
						color: Colors.black.withValues(alpha: 0.08),
						blurRadius: 10,
						offset: const Offset(0, 3),
					),
				],
			),
			child: SafeArea(
				bottom: false,
				child: Padding(
					padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							Image.asset(
								logoAsset,
								height: 44,
								fit: BoxFit.contain,
								semanticLabel: "Logo Sika",
							),
							const Expanded(
								child: Text(
									"SUPERVISOR",
									textAlign: TextAlign.center,
									style: TextStyle(
										fontWeight: FontWeight.bold,
										fontSize: 17,
										letterSpacing: 0.6,
										color: Colors.black87,
									),
								),
							),
							IconButton(
								tooltip: "Recargar",
								icon: const Icon(Icons.refresh, color: Colors.black87),
								onPressed: onRefresh,
							),
							IconButton(
								tooltip: "Cerrar sesión",
								icon: const Icon(Icons.logout, color: Colors.black87),
								onPressed: onLogout,
							),
						],
					),
				),
			),
		);
	}
}

class _LeadingIconBadge extends StatelessWidget {
	const _LeadingIconBadge({
		required this.icon,
		required this.iconColor,
	});

	final IconData icon;
	final Color iconColor;

	@override
	Widget build(BuildContext context) {
		return Stack(
			clipBehavior: Clip.none,
			alignment: Alignment.center,
			children: [
				Icon(icon, color: iconColor, size: 26),
				Positioned(
					right: 2,
					bottom: 2,
					child: Container(
						padding: const EdgeInsets.all(3),
						decoration: const BoxDecoration(
							color: AppTokens.redAction,
							shape: BoxShape.circle,
						),
						child: const Icon(Icons.add, color: Colors.white, size: 11),
					),
				),
			],
		);
	}
}

class _SupervisorMenuCard extends StatelessWidget {
	const _SupervisorMenuCard({
		required this.leadingDecoration,
		required this.leading,
		required this.title,
		required this.subtitle,
		required this.onTap,
		this.badgeCount = 0,
	});

	final BoxDecoration leadingDecoration;
	final Widget leading;
	final String title;
	final String subtitle;
	final VoidCallback onTap;

	/// Pedidos nuevos pendientes de decisión (solo tarjeta mantenimiento).
	final int badgeCount;

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
								badgeCount > 0
									? _SupervisorMenuChevronBadge(count: badgeCount)
									: const Icon(
											Icons.chevron_right,
											color: Colors.black87,
											size: 26,
										),
							],
						),
					),
				),
			),
		);
	}
}

class _SupervisorMenuChevronBadge extends StatelessWidget {
	const _SupervisorMenuChevronBadge({required this.count});

	final int count;

	String get _label {
		if (count > 99) return "99+";
		return "$count";
	}

	@override
	Widget build(BuildContext context) {
		return SizedBox(
			width: 40,
			height: 32,
			child: Stack(
				clipBehavior: Clip.none,
				alignment: Alignment.center,
				children: [
					const Icon(
						Icons.chevron_right,
						color: Colors.black87,
						size: 26,
					),
					Positioned(
						right: -2,
						top: -6,
						child: Container(
							constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
							padding: const EdgeInsets.symmetric(horizontal: 5),
							decoration: const BoxDecoration(
								color: AppTokens.redAction,
								shape: BoxShape.circle,
								boxShadow: [
									BoxShadow(
										color: Colors.black26,
										blurRadius: 4,
										offset: Offset(0, 1),
									),
								],
							),
							alignment: Alignment.center,
							child: Text(
								_label,
								style: const TextStyle(
									color: Colors.white,
									fontSize: 11,
									fontWeight: FontWeight.w800,
									height: 1,
								),
							),
						),
					),
				],
			),
		);
	}
}
