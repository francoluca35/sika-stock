import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/domain/profile_row.dart";

/// Contenido pestaña **Pedido**: BIENVENIDO + accesos (mockup rol mantenimiento).
class MaintenanceWelcomeTab extends StatelessWidget {
	const MaintenanceWelcomeTab({
		super.key,
		required this.profile,
		this.onOpenHistorial,
	});

	final ProfileRow profile;
	final VoidCallback? onOpenHistorial;

	static String _welcomeName(ProfileRow p) {
		final n = p.nombre?.trim();
		if (n != null && n.isNotEmpty) {
			final first = n.split(RegExp(r"\s+")).firstWhere(
				(s) => s.isNotEmpty,
				orElse: () => n,
			);
			if (first.isEmpty) return "usuario";
			return "${first[0].toUpperCase()}${first.length > 1 ? first.substring(1).toLowerCase() : ""}";
		}
		final u = p.usuario?.trim();
		if (u != null && u.isNotEmpty) return u;
		final e = p.email?.trim();
		if (e != null && e.isNotEmpty) {
			final local = e.split("@").first;
			if (local.isNotEmpty) return local;
		}
		return "usuario";
	}

	void _soon(BuildContext context, String msg) {
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text("$msg — próximamente.")),
		);
	}

	@override
	Widget build(BuildContext context) {
		final nombre = _welcomeName(profile);
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				const _MaintenanceBienvenidoHeader(),
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
											"Bienvenido, $nombre",
											style: const TextStyle(
												fontWeight: FontWeight.bold,
												fontSize: 20,
												color: Colors.black87,
												height: 1.25,
											),
										),
										const SizedBox(height: 22),
										_MaintenanceActionCard(
											background: AppTokens.redAction,
											foreground: Colors.white,
											icon: Icons.handyman_outlined,
											title: "PEDIR PRODUCTO",
											subtitle: "Solicitar materiales o repuestos",
											onTap: () => context.push("/mantenimiento/pedir-producto"),
										),
										const SizedBox(height: 12),
										_MaintenanceActionCard(
											background: AppTokens.whiteSurface,
											foreground: Colors.black87,
											border: Border.all(color: Colors.black87, width: 1.2),
											icon: Icons.folder_open_outlined,
											title: "HISTORIAL DE PEDIDOS",
											subtitle: "Ver pedidos, envíos y productos",
											onTap: () {
												final h = onOpenHistorial;
												if (h != null) {
													h();
												} else {
													_soon(context, "Historial de pedidos");
												}
											},
										),
										const SizedBox(height: 12),
										_MaintenanceActionCard(
											background: AppTokens.blackNav,
											foreground: Colors.white,
											icon: Icons.settings_suggest_outlined,
											title: "SEGUIMIENTO",
											subtitle: "Seguimiento de pedidos y órdenes",
											onTap: () => _soon(context, "Seguimiento"),
										),
									],
								),
							),
						),
					),
				),
			],
		);
	}
}

class _MaintenanceBienvenidoHeader extends StatelessWidget {
	const _MaintenanceBienvenidoHeader();

	@override
	Widget build(BuildContext context) {
		return Container(
			width: double.infinity,
			color: AppTokens.yellowHeader,
			child: SafeArea(
				bottom: false,
				child: SizedBox(
					height: 52,
					child: Center(
						child: Text(
							"BIENVENIDO",
							style: TextStyle(
								fontWeight: FontWeight.bold,
								fontSize: 17,
								letterSpacing: 1.0,
								color: Colors.black87,
							),
						),
					),
				),
			),
		);
	}
}

class _MaintenanceActionCard extends StatelessWidget {
	const _MaintenanceActionCard({
		required this.background,
		required this.foreground,
		required this.icon,
		required this.title,
		required this.subtitle,
		required this.onTap,
		this.border,
	});

	final Color background;
	final Color foreground;
	final IconData icon;
	final String title;
	final String subtitle;
	final VoidCallback onTap;
	final BoxBorder? border;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: background,
			borderRadius: BorderRadius.circular(AppTokens.radiusLg),
			elevation: 1,
			shadowColor: Colors.black12,
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(AppTokens.radiusLg),
				child: Ink(
					decoration: BoxDecoration(
						borderRadius: BorderRadius.circular(AppTokens.radiusLg),
						border: border,
					),
					child: Padding(
						padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
						child: Row(
							children: [
								Icon(icon, color: foreground, size: 32),
								const SizedBox(width: 16),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												title,
												style: TextStyle(
													fontWeight: FontWeight.bold,
													fontSize: 14,
													letterSpacing: 0.4,
													color: foreground,
												),
											),
											const SizedBox(height: 4),
											Text(
												subtitle,
												style: TextStyle(
													fontSize: 12.5,
													height: 1.25,
													color: foreground.withValues(alpha: 0.92),
												),
											),
										],
									),
								),
								Icon(
									Icons.chevron_right,
									color: foreground,
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
