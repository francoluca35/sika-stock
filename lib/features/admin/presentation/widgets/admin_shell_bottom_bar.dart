import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Barra inferior negra (Crear orden / Inicio / Configuración).
///
/// [showCrearOrdenCompra]: solo **ADMIN**, **SUPERADMIN** y **COMPRAS** deben verlo;
/// el resto de roles usan [showCrearOrdenCompra]: false (solo Inicio + Configuración).
class AdminShellBottomBar extends StatelessWidget {
	const AdminShellBottomBar({
		super.key,
		required this.bottomPadding,
		required this.onInicio,
		required this.onOrdenCompra,
		required this.onConfig,
		this.showCrearOrdenCompra = true,
	});

	final double bottomPadding;
	final VoidCallback onInicio;
	final VoidCallback onOrdenCompra;
	final VoidCallback onConfig;

	/// Si es false, no se muestra el botón «CREAR ORDEN DE COMPRA».
	final bool showCrearOrdenCompra;

	static Widget _divider() =>
		Container(width: 1, height: 36, color: Colors.white24);

	@override
	Widget build(BuildContext context) {
		final crearOrden = showCrearOrdenCompra
				? <Widget>[
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
					]
				: <Widget>[];

		return Container(
			padding: EdgeInsets.only(bottom: bottomPadding),
			color: AppTokens.blackNav,
			child: SafeArea(
				top: false,
				child: SizedBox(
					height: 58,
					child: Row(
						children: [
							...crearOrden,
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
