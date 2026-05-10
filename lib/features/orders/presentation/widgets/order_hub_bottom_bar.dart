import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Barra inferior estilo mockup: Pedido · Historial · Perfil.
class OrderHubBottomBar extends StatelessWidget {
	const OrderHubBottomBar({
		super.key,
		required this.bottomPadding,
		required this.selectedIndex,
		required this.onPedido,
		required this.onHistorial,
		required this.onPerfil,
	});

	final double bottomPadding;

	/// 0 = Pedido, 1 = Historial, 2 = Perfil
	final int selectedIndex;
	final VoidCallback onPedido;
	final VoidCallback onHistorial;
	final VoidCallback onPerfil;

	static Widget _divider() =>
		Container(width: 1, height: 36, color: Colors.white24);

	Color _itemColor(int index) =>
		selectedIndex == index ? AppTokens.yellowAccent : Colors.white;

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
									onTap: onPedido,
									child: Column(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(
												Icons.inventory_2_outlined,
												color: _itemColor(0),
												size: 24,
											),
											const SizedBox(height: 2),
											Text(
												"PEDIDO",
												style: TextStyle(
													color: _itemColor(0),
													fontWeight: FontWeight.bold,
													fontSize: 11,
													letterSpacing: 0.4,
												),
											),
										],
									),
								),
							),
							_divider(),
							Expanded(
								child: InkWell(
									onTap: onHistorial,
									child: Column(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(
												Icons.history,
												color: _itemColor(1),
												size: 24,
											),
											const SizedBox(height: 2),
											Text(
												"HISTORIAL",
												style: TextStyle(
													color: _itemColor(1),
													fontWeight: FontWeight.bold,
													fontSize: 11,
													letterSpacing: 0.4,
												),
											),
										],
									),
								),
							),
							_divider(),
							Expanded(
								child: InkWell(
									onTap: onPerfil,
									child: Column(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(
												Icons.person_outline,
												color: _itemColor(2),
												size: 24,
											),
											const SizedBox(height: 2),
											Text(
												"PERFIL",
												style: TextStyle(
													color: _itemColor(2),
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
