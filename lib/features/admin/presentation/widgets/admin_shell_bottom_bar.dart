import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Barra inferior negra del panel admin (Crear orden / Inicio / Configuración).
class AdminShellBottomBar extends StatelessWidget {
	const AdminShellBottomBar({
		super.key,
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
