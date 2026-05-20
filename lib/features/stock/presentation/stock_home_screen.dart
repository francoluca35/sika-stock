import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";
import "../../orders/presentation/widgets/order_hub_bottom_bar.dart";
import "widgets/stock_screen_header.dart";

void _stockHomeSoon(BuildContext context, String msg) {
	ScaffoldMessenger.of(context).showSnackBar(
		SnackBar(content: Text("$msg — próximamente.")),
	);
}

/// Hub **Stock**: AGREGAR / HISTORIAL / ALERTAS / CATEGORÍAS + barra inferior Pedido · Historial · Perfil.
/// Ruta dedicada `/stock`; Mantenimiento entra por su propia pantalla en `/home`.
class StockHomeScreen extends ConsumerWidget {
	const StockHomeScreen({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final bottomInset = MediaQuery.paddingOf(context).bottom;
		final puedeGestionarStock = ref.watch(currentProfileProvider).maybeWhen(
			data: (p) => appRolePuedeGestionarStock(p?.rol),
			orElse: () => false,
		);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "STOCK",
						onBack: () {
							if (context.canPop()) {
								context.pop();
							} else {
								context.go("/home");
							}
						},
						onRefresh: () => ScreenRefresh.stock(ref),
					),
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
							child: Center(
								child: ConstrainedBox(
									constraints: const BoxConstraints(maxWidth: 480),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: [
											_StockMenuCard(
												leadingDecoration: const BoxDecoration(
													color: AppTokens.redAction,
													borderRadius: BorderRadius.all(Radius.circular(12)),
												),
												leading: const _StockLeadingIcon(
													icon: Icons.inventory_2_outlined,
													iconColor: Colors.white,
													badge: true,
												),
												title: "AGREGAR STOCK",
												subtitle: puedeGestionarStock
														? "Registrar entradas y salidas de stock"
														: "Solo el rol Pañol puede registrar stock",
												onTap: () {
													if (!puedeGestionarStock) {
														ScaffoldMessenger.of(context).showSnackBar(
															const SnackBar(
																content: Text(
																	"Solo usuarios con rol Pañol pueden agregar stock.",
																),
															),
														);
														return;
													}
													context.push("/stock/agregar");
												},
											),
											const SizedBox(height: 16),
											_StockMenuCard(
												leadingDecoration: const BoxDecoration(
													color: Colors.black87,
													borderRadius: BorderRadius.all(Radius.circular(12)),
												),
												leading: const Icon(
													Icons.history,
													color: Colors.white,
													size: 28,
												),
												title: "HISTORIAL DE STOCK",
												subtitle: "Ver movimientos y registros de stock",
												onTap: () => _stockHomeSoon(context, "Historial de stock"),
											),
											const SizedBox(height: 16),
											_StockMenuCard(
												leadingDecoration: const BoxDecoration(
													color: AppTokens.yellowHeader,
													borderRadius: BorderRadius.all(Radius.circular(12)),
												),
												leading: const Icon(
													Icons.notifications_active_outlined,
													color: Colors.black87,
													size: 28,
												),
												title: "ALERTAS",
												subtitle: "Ver productos con stock bajo o crítico",
												onTap: () => _stockHomeSoon(context, "Alertas de stock"),
											),
											const SizedBox(height: 16),
											_StockMenuCard(
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
												subtitle: "Gestionar rubros y clasificación de productos",
												onTap: () => context.push("/stock/categorias"),
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
						onPerfil: () => _stockHomeSoon(context, "Perfil"),
					),
				],
			),
		);
	}
}

class _StockLeadingIcon extends StatelessWidget {
	const _StockLeadingIcon({
		required this.icon,
		required this.iconColor,
		this.badge = false,
	});

	final IconData icon;
	final Color iconColor;
	final bool badge;

	@override
	Widget build(BuildContext context) {
		if (!badge) {
			return Icon(icon, color: iconColor, size: 28);
		}
		return Stack(
			clipBehavior: Clip.none,
			alignment: Alignment.center,
			children: [
				Icon(icon, color: iconColor, size: 28),
				Positioned(
					right: 2,
					bottom: 2,
					child: Container(
						padding: const EdgeInsets.all(3),
						decoration: const BoxDecoration(
							color: Colors.white,
							shape: BoxShape.circle,
						),
						child: const Icon(
							Icons.add,
							color: AppTokens.redAction,
							size: 12,
						),
					),
				),
			],
		);
	}
}

class _StockMenuCard extends StatelessWidget {
	const _StockMenuCard({
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
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(AppTokens.radiusLg),
				child: Ink(
					decoration: BoxDecoration(
						color: AppTokens.whiteSurface,
						borderRadius: BorderRadius.circular(AppTokens.radiusLg),
						border: Border.all(color: Colors.black87, width: 1.2),
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
													fontSize: 14,
													letterSpacing: 0.35,
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
								const Icon(
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
