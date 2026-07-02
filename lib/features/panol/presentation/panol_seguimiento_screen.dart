import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../compras/presentation/widgets/compras_screen_metrics.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "../application/panol_seguimiento_compras_provider.dart";
import "widgets/producto_seguimiento_panel.dart";

/// Pantalla **Seguimiento** Pañol: productos con OC en curso (datos reales de compras).
class PanolSeguimientoScreen extends ConsumerWidget {
	const PanolSeguimientoScreen({super.key});

	void _back(BuildContext context) {
		if (context.canPop()) {
			context.pop();
		} else {
			context.go("/home");
		}
	}

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final asyncItems = ref.watch(panolSeguimientoComprasProvider);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "SEGUIMIENTO",
						onBack: () => _back(context),
						onRefresh: () => ScreenRefresh.seguimiento(ref),
					),
					Padding(
						padding: ComprasScreenMetrics.horizontalPadding(context).copyWith(
							top: 12,
							bottom: 8,
						),
						child: Row(
							children: [
								Icon(Icons.info_outline, size: 20, color: Colors.grey.shade700),
								const SizedBox(width: 8),
								Expanded(
									child: Text(
										"Productos pedidos a compras desde pañol. "
										"Amarillo: pedido registrado · Verde: listo para retirar. "
										"Tocá un ítem para ver el trayecto o avisar cuando esté listo.",
										style: TextStyle(
											fontSize: 13,
											color: Colors.grey.shade800,
											height: 1.35,
										),
									),
								),
							],
						),
					),
					Expanded(
						child: asyncItems.when(
							loading: () => const Center(child: CircularProgressIndicator()),
							error: (e, _) => Center(
								child: Padding(
									padding: const EdgeInsets.all(24),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											Text(
												"No se pudo cargar el seguimiento.\n$e",
												textAlign: TextAlign.center,
											),
											const SizedBox(height: 12),
											FilledButton(
												onPressed: () =>
														ref.invalidate(panolSeguimientoComprasProvider),
												child: const Text("Reintentar"),
											),
										],
									),
								),
							),
							data: (items) => RefreshIndicator(
								onRefresh: () async {
									ref.invalidate(panolSeguimientoComprasProvider);
									await ref.read(panolSeguimientoComprasProvider.future);
								},
								child: Center(
									child: ConstrainedBox(
										constraints: const BoxConstraints(maxWidth: AppTokens.maxContentWidth),
										child: ProductoSeguimientoPanel(items: items),
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
