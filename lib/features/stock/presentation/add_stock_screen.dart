import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";
import "widgets/add_stock_form_panel.dart";
import "widgets/stock_screen_header.dart";

/// Pantalla completa: alta de stock (mismo formulario que el panel en línea de Pañol).
class AddStockScreen extends ConsumerWidget {
	const AddStockScreen({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final puede = ref.watch(currentProfileProvider).maybeWhen(
			data: (p) => appRolePuedeGestionarStock(p?.rol),
			orElse: () => false,
		);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "AGREGAR STOCK",
						onBack: () {
							if (context.canPop()) {
								context.pop();
							} else {
								context.go("/stock");
							}
						},
					),
					Expanded(
						child: puede
								? SingleChildScrollView(
										padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
										child: Center(
											child: ConstrainedBox(
												constraints: const BoxConstraints(maxWidth: 480),
												child: const AddStockFormPanel(),
											),
										),
									)
								: Center(
										child: Padding(
											padding: const EdgeInsets.all(24),
											child: Text(
												"Solo usuarios con rol Pañol pueden registrar stock.",
												textAlign: TextAlign.center,
												style: TextStyle(
													fontSize: 15,
													height: 1.35,
													color: Colors.grey.shade800,
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
