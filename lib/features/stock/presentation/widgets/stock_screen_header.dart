import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Cabecera amarilla con atrás y título centrado (hub Stock y pantallas hijas).
class StockScreenHeader extends StatelessWidget {
	const StockScreenHeader({
		super.key,
		required this.title,
		required this.onBack,
	});

	final String title;
	final VoidCallback onBack;

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
				child: SizedBox(
					height: 56,
					child: Stack(
						alignment: Alignment.center,
						children: [
							Align(
								alignment: Alignment.centerLeft,
								child: IconButton(
									icon: const Icon(Icons.arrow_back, color: Colors.black87),
									onPressed: onBack,
								),
							),
							Padding(
								padding: const EdgeInsets.symmetric(horizontal: 48),
								child: Text(
									title,
									textAlign: TextAlign.center,
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
									style: const TextStyle(
										fontWeight: FontWeight.bold,
										fontSize: 17,
										letterSpacing: 0.8,
										color: Colors.black87,
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
