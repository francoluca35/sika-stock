import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";

/// Pantalla **Seguimiento** Pañol.
class PanolSeguimientoScreen extends StatelessWidget {
	const PanolSeguimientoScreen({super.key});

	void _back(BuildContext context) {
		if (context.canPop()) {
			context.pop();
		} else {
			context.go("/home");
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "SEGUIMIENTO",
						onBack: () => _back(context),
					),
					Expanded(
						child: Center(
							child: ConstrainedBox(
								constraints: const BoxConstraints(maxWidth: 420),
								child: Padding(
									padding: const EdgeInsets.all(24),
									child: Column(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(Icons.show_chart, size: 64, color: Colors.grey.shade600),
											const SizedBox(height: 16),
											Text(
												"SEGUIMIENTO",
												style: TextStyle(
													fontSize: 20,
													fontWeight: FontWeight.bold,
													color: Colors.grey.shade800,
												),
											),
											const SizedBox(height: 8),
											Text(
												"Próximamente verás el seguimiento de pedidos y métricas.",
												textAlign: TextAlign.center,
												style: TextStyle(
													fontSize: 14,
													color: Colors.grey.shade700,
													height: 1.35,
												),
											),
										],
									),
								),
							),
						),
					),
				],
			),
		);
	}
}
