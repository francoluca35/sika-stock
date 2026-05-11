import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Barra inferior rol **Mantenimiento**: Pedido · Historial · Perfil (activo en amarillo).
class MaintenanceBottomNavBar extends StatelessWidget {
	const MaintenanceBottomNavBar({
		super.key,
		required this.currentIndex,
		required this.onTap,
		required this.bottomPadding,
	});

	final int currentIndex;
	final ValueChanged<int> onTap;
	final double bottomPadding;

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
								child: _NavItem(
									icon: Icons.inventory_2_outlined,
									label: "PEDIDO",
									selected: currentIndex == 0,
									onTap: () => onTap(0),
								),
							),
							Container(width: 1, height: 36, color: Colors.white24),
							Expanded(
								child: _NavItem(
									icon: Icons.history,
									label: "HISTORIAL",
									selected: currentIndex == 1,
									onTap: () => onTap(1),
								),
							),
							Container(width: 1, height: 36, color: Colors.white24),
							Expanded(
								child: _NavItem(
									icon: Icons.person_outline,
									label: "PERFIL",
									selected: currentIndex == 2,
									onTap: () => onTap(2),
								),
							),
						],
					),
				),
			),
		);
	}
}

class _NavItem extends StatelessWidget {
	const _NavItem({
		required this.icon,
		required this.label,
		required this.selected,
		required this.onTap,
	});

	final IconData icon;
	final String label;
	final bool selected;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		final color = selected ? AppTokens.yellowAccent : Colors.white;
		return InkWell(
			onTap: onTap,
			child: Column(
				mainAxisAlignment: MainAxisAlignment.center,
				children: [
					Icon(icon, color: color, size: 24),
					const SizedBox(height: 2),
					Text(
						label,
						style: TextStyle(
							color: color,
							fontWeight: FontWeight.bold,
							fontSize: 10,
							letterSpacing: 0.3,
						),
					),
				],
			),
		);
	}
}
