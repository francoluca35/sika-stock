import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "../../supervisor/domain/maintenance_order.dart";
import "../application/mis_pedidos_mantenimiento_provider.dart";
import "widgets/maintenance_order_seguimiento_sheet.dart";
import "widgets/maintenance_order_timeline.dart";

String _estadoMantenimientoTexto(MaintenanceWorkflowStatus w) {
	switch (w) {
		case MaintenanceWorkflowStatus.pendingSupervisor:
			return "Enviado — esperando supervisor";
		case MaintenanceWorkflowStatus.supervisorStockOk:
			return "Stock confirmado — podés retirar";
		case MaintenanceWorkflowStatus.forwardedToPanol:
			return "En pañol (sin stock) — consulta";
		case MaintenanceWorkflowStatus.panolRequestedCompras:
			return "Pedido a compras (pañol gestiona)";
		case MaintenanceWorkflowStatus.comprasOcNotified:
		case MaintenanceWorkflowStatus.comprasPurchaseDone:
			return "Pedido a compras (en gestión)";
		case MaintenanceWorkflowStatus.comprasArrivedNotified:
			return "Listo para retirar en pañol";
		case MaintenanceWorkflowStatus.completed:
			return "Completado";
		case MaintenanceWorkflowStatus.cancelled:
			return "Cancelado";
	}
}

/// Listado de pedidos del usuario **Mantenimiento** (lectura desde Supabase).
class MyMaintenanceOrdersScreen extends ConsumerWidget {
	const MyMaintenanceOrdersScreen({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final async = ref.watch(misPedidosMantenimientoProvider);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "MIS PEDIDOS",
						onBack: () {
							if (context.canPop()) {
								context.pop();
							} else {
								context.go("/home");
							}
						},
						onRefresh: () => ScreenRefresh.misPedidos(ref),
					),
					Expanded(
						child: async.when(
							loading: () => const Center(child: CircularProgressIndicator()),
							error: (e, _) => Center(
								child: Padding(
									padding: const EdgeInsets.all(24),
									child: Text(
										"No se pudieron cargar los pedidos.\n$e",
										textAlign: TextAlign.center,
									),
								),
							),
							data: (lista) {
								if (lista.isEmpty) {
									return Center(
										child: Text(
											"Todavía no registraste pedidos.",
											style: TextStyle(color: Colors.grey.shade700),
										),
									);
								}
								return RefreshIndicator(
									onRefresh: () async {
										ref.invalidate(misPedidosMantenimientoProvider);
										await ref.read(misPedidosMantenimientoProvider.future);
									},
									child: ListView.separated(
										padding: const EdgeInsets.all(16),
										itemCount: lista.length,
										separatorBuilder: (_, __) => const SizedBox(height: 10),
										itemBuilder: (ctx, i) {
											final o = lista[i];
											return Material(
												color: Colors.transparent,
												child: InkWell(
													borderRadius: BorderRadius.circular(
														AppTokens.radiusMd,
													),
													onTap: () => showMaintenanceOrderSeguimientoSheet(
														context,
														o,
														ref: ref,
													),
													child: Card(
														elevation: 0,
														color: AppTokens.whiteSurface,
														shape: RoundedRectangleBorder(
															borderRadius: BorderRadius.circular(
																AppTokens.radiusMd,
															),
															side: const BorderSide(color: AppTokens.greyBorder),
														),
														child: Padding(
															padding: const EdgeInsets.all(14),
															child: Column(
																crossAxisAlignment: CrossAxisAlignment.start,
																children: [
																	Text(
																		o.numeroOrden,
																		style: const TextStyle(
																			fontWeight: FontWeight.bold,
																			fontSize: 15,
																		),
																	),
																	const SizedBox(height: 6),
																	Text(
																		o.producto,
																		style: const TextStyle(fontSize: 14),
																	),
																	const SizedBox(height: 8),
																	MaintenanceOrderProgressBar(
																		status: o.workflowStatus,
																	),
																	const SizedBox(height: 6),
																	Text(
																		_estadoMantenimientoTexto(o.workflowStatus),
																		style: TextStyle(
																			fontSize: 13,
																			color: Colors.grey.shade800,
																			fontWeight: FontWeight.w600,
																		),
																	),
																],
															),
														),
													),
												),
											);
										},
									),
								);
							},
						),
					),
				],
			),
		);
	}
}
