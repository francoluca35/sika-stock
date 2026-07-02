import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../application/panol_forwarded_orders_provider.dart";
import "../application/panol_order_history_provider.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/domain/stock_product.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "../../orders/application/order_navigation_target_provider.dart";
import "../../orders/presentation/widgets/maintenance_order_seguimiento_sheet.dart";
import "../../supervisor/domain/maintenance_order.dart";
import "../../compras/application/compras_stock_repository_provider.dart";
import "../../orders/presentation/widgets/maintenance_order_detail_dialog.dart";
import "../../supervisor/application/maintenance_orders_provider.dart";
import "widgets/panol_agregar_stock_dialog.dart";

bool _panolPedidosLayoutCompact(BuildContext context) =>
		MediaQuery.sizeOf(context).width < 720;

_EstadoPedidoPanol _panolBadgeDesdeWorkflow(MaintenanceWorkflowStatus w) {
	switch (w) {
		case MaintenanceWorkflowStatus.forwardedToPanol:
			return _EstadoPedidoPanol.consultaMantenimiento;
		case MaintenanceWorkflowStatus.panolRequestedCompras:
			return _EstadoPedidoPanol.enTramiteCompras;
		case MaintenanceWorkflowStatus.comprasOcNotified:
			return _EstadoPedidoPanol.enTramiteCompras;
		case MaintenanceWorkflowStatus.comprasPurchaseDone:
			return _EstadoPedidoPanol.enTramiteCompras;
		case MaintenanceWorkflowStatus.comprasArrivedNotified:
			return _EstadoPedidoPanol.materialEnPlanta;
		case MaintenanceWorkflowStatus.supervisorStockOk:
			return _EstadoPedidoPanol.listoParaRetiro;
		default:
			return _EstadoPedidoPanol.consultaMantenimiento;
	}
}

class _PanolPedidoDemo {
	_PanolPedidoDemo({
		required this.numero,
		required this.fecha,
		required this.producto,
		required this.estado,
		this.workflowMo,
	});

	final String numero;
	final DateTime fecha;
	final String producto;
	final _EstadoPedidoPanol estado;
	final MaintenanceWorkflowStatus? workflowMo;
}

enum _EstadoPedidoPanol {
	enProceso,
	pendiente,
	completado,
	consultaMantenimiento,
	enTramiteCompras,
	materialEnPlanta,
	listoParaRetiro,
}

/// Pantalla **Pedidos** Pañol.
class PanolPedidosScreen extends ConsumerStatefulWidget {
	const PanolPedidosScreen({super.key});

	@override
	ConsumerState<PanolPedidosScreen> createState() => _PanolPedidosScreenState();
}

class _PanolPedidosScreenState extends ConsumerState<PanolPedidosScreen> {
	void _back(BuildContext context) {
		if (context.canPop()) {
			context.pop();
		} else {
			context.go("/home");
		}
	}

	String _fmtFecha(DateTime d) {
		return "${d.day.toString().padLeft(2, "0")}/"
				"${d.month.toString().padLeft(2, "0")}/"
				"${d.year}";
	}

	bool _productoCoincideConStock({
		required String pedidoProducto,
		required StockProduct stockProducto,
	}) {
		final pedido = pedidoProducto.toLowerCase().trim();
		final nombreStock = stockProducto.nombre.toLowerCase();

		if (pedido.isEmpty) return false;
		if (nombreStock.contains(pedido)) return true;

		final tokens = pedido.split(RegExp(r"\s+")).where((t) => t.length >= 3);
		for (final t in tokens.take(3)) {
			if (nombreStock.contains(t)) return true;
		}
		return false;
	}

	StockProduct? _buscarStockMatch({
		required String pedidoProducto,
		required List<StockProduct> stocks,
	}) {
		final pedido = pedidoProducto.split(RegExp(r"[\r\n]+")).first.trim();
		StockProduct? mejor;
		for (final p in stocks) {
			if (!_productoCoincideConStock(pedidoProducto: pedido, stockProducto: p)) {
				continue;
			}
			mejor ??= p;
			if (p.cantidad > mejor.cantidad) mejor = p;
		}
		return mejor;
	}

	int _calcularCantidadStock(
		_PanolPedidoDemo pedido,
		List<StockProduct> stocks,
	) {
		final nombrePedido =
				pedido.producto.split(RegExp(r"[\r\n]+")).first.trim();
		final match = stocks.where(
			(p) => _productoCoincideConStock(
				pedidoProducto: nombrePedido,
				stockProducto: p,
			),
		);
		return match.fold<int>(0, (acc, p) => acc + p.cantidad);
	}

	/// Texto bajo el producto en pañol: el ingreso a pañol lo dispara el supervisor,
	/// no un envío directo desde mantenimiento.
	String _panolPedidoSubtitulo(MaintenanceOrder mo) {
		final s = mo.solicitante.trim();
		final sinEtiquetaMant = s
				.replaceFirst(
					RegExp(r"\s*·\s*Mantenimiento\s*$", caseSensitive: false),
					"",
				)
				.trim();
		final origen = sinEtiquetaMant.isEmpty ? s : sinEtiquetaMant;
		return "Derivado a pañol por supervisor · $origen";
	}

	_PanolPedidoDemo _fromMaintenanceOrder(MaintenanceOrder mo) {
		return _PanolPedidoDemo(
			numero: mo.numeroOrden,
			fecha: mo.fechaPedido,
			producto: "${mo.producto}\n${_panolPedidoSubtitulo(mo)}",
			estado: _panolBadgeDesdeWorkflow(mo.workflowStatus),
			workflowMo: mo.workflowStatus,
		);
	}

	@override
	Widget build(BuildContext context) {
		ref.listen<String?>(orderNavigationTargetProvider, (prev, next) {
			if (next == null || next == prev) return;
			final orders = ref.read(panolForwardedOrdersProvider).value;
			if (orders == null) return;
			final match = orders.where((o) => o.id == next).firstOrNull;
			if (match == null) return;
			ref.read(orderNavigationTargetProvider.notifier).setTarget(null);
			WidgetsBinding.instance.addPostFrameCallback((_) {
				if (!mounted) return;
				showMaintenanceOrderSeguimientoSheet(context, match, ref: ref);
			});
		});

		final stocksAsync = ref.watch(supervisorStockCatalogProvider);
		final consultar = ref.watch(panolForwardedOrdersProvider);
		final consultas = consultar.maybeWhen(
			data: (v) => v,
			orElse: () => <MaintenanceOrder>[],
		);
		final merged = consultas.map(_fromMaintenanceOrder).toList();
		final consultasCount = consultas.length;

		return stocksAsync.when(
			loading: () => Scaffold(
				backgroundColor: AppTokens.surfacePage,
				body: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						StockScreenHeader(
							title: "PEDIDOS",
							onBack: () => _back(context),
							onRefresh: () => ScreenRefresh.pedidosPanol(ref),
						),
						const Expanded(
							child: Center(child: CircularProgressIndicator()),
						),
					],
				),
			),
			error: (e, _) => Scaffold(
				backgroundColor: AppTokens.surfacePage,
				body: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						StockScreenHeader(
							title: "PEDIDOS",
							onBack: () => _back(context),
							onRefresh: () => ScreenRefresh.pedidosPanol(ref),
						),
						Expanded(
							child: Center(
								child: Padding(
									padding: const EdgeInsets.all(24),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											const Text(
												"No se pudo cargar el stock.",
												textAlign: TextAlign.center,
											),
											const SizedBox(height: 8),
											Text(
												"$e",
												textAlign: TextAlign.center,
												style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
											),
											const SizedBox(height: 16),
											FilledButton(
												onPressed: () =>
														ref.invalidate(supervisorStockCatalogProvider),
												child: const Text("Reintentar"),
											),
										],
									),
								),
							),
						),
					],
				),
			),
			data: (stocks) {
				return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "PEDIDOS",
						onBack: () => _back(context),
						onRefresh: () => ScreenRefresh.pedidosPanol(ref),
					),
					Expanded(
						child: Column(
							children: [
								if (consultar.isLoading)
									const LinearProgressIndicator(minHeight: 2),
								Expanded(
									child: SingleChildScrollView(
										padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
										child: Center(
											child: ConstrainedBox(
												constraints: const BoxConstraints(maxWidth: 980),
												child: Material(
													color: AppTokens.whiteSurface,
													borderRadius:
															BorderRadius.circular(AppTokens.radiusLg),
													clipBehavior: Clip.antiAlias,
													elevation: 1,
													shadowColor: Colors.black12,
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.stretch,
														mainAxisSize: MainAxisSize.min,
														children: [
															Padding(
																padding:
																		const EdgeInsets.fromLTRB(16, 14, 16, 10),
																child: Row(
																	crossAxisAlignment: CrossAxisAlignment.center,
																	children: [
																		const Expanded(
																			child: Text(
																				"ÚLTIMOS PEDIDOS",
																				style: TextStyle(
																					fontWeight: FontWeight.bold,
																					fontSize: 13,
																					color: Colors.grey,
																				),
																			),
																		),
																		TextButton.icon(
																			onPressed: () => context.push("/panol/pedidos-historial"),
																			icon: const Icon(Icons.history_outlined,
																					size: 18),
																			label: const Text(
																				"HISTORIAL",
																				style: TextStyle(
																					fontWeight: FontWeight.w700,
																					fontSize: 12,
																				),
																			),
																			style: TextButton.styleFrom(
																				foregroundColor: Colors.black87,
																				padding: EdgeInsets.zero,
																				minimumSize: const Size(0, 0),
																			),
																		),
																	],
																),
															),
															const Divider(height: 1),
															if (!_panolPedidosLayoutCompact(context))
																const _PanolPedidosHeaderRow(),
															if (!_panolPedidosLayoutCompact(context))
																const Divider(height: 1),
															ListView.separated(
																padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
																shrinkWrap: true,
																physics: const NeverScrollableScrollPhysics(),
																itemCount: merged.length,
																separatorBuilder: (_, __) =>
																		const Divider(height: 1),
																itemBuilder: (context, i) {
																	final idx = i;
																	final o = merged[idx];
																	final esConsulta = idx < consultasCount;
																	final cantidadStock =
																			_calcularCantidadStock(o, stocks);
																	final compact =
																			_panolPedidosLayoutCompact(context);
																	final MaintenanceOrder? moRow =
																			esConsulta ? consultas[idx] : null;
																	final tresBotonesPanolPendiente =
																			moRow != null &&
																					moRow.workflowStatus ==
																							MaintenanceWorkflowStatus
																									.forwardedToPanol;
																	final listoParaRetiro =
																			moRow != null &&
																					(moRow.workflowStatus ==
																							MaintenanceWorkflowStatus
																									.supervisorStockOk ||
																						moRow.workflowStatus ==
																								MaintenanceWorkflowStatus
																										.comprasArrivedNotified);

																	void onVer() {
																		if (esConsulta) {
																			final mo = consultas[idx];
																			showMaintenanceOrderDetalleDialog(
																				context,
																				mo,
																				stockCatalogoCantidad: cantidadStock,
																			);
																			return;
																		}
																		showDialog<void>(
																			context: context,
																			builder: (ctx) => AlertDialog(
																				title: const Text("Detalle del pedido"),
																				content: Text(
																					"Pedido ${o.numero}\n"
																					"Fecha: ${_fmtFecha(o.fecha)}\n"
																					"Producto: ${o.producto}\n"
																					"Estado: ${o.estado.name}",
																				),
																				actions: [
																					TextButton(
																						onPressed: () => Navigator.pop(ctx),
																						child: const Text("Cerrar"),
																					),
																				],
																			),
																		);
																	}

																	Future<void> onTercero() async {
																		if (!esConsulta) {
																			if (!context.mounted) return;
																			ScaffoldMessenger.of(context).showSnackBar(
																				const SnackBar(
																					content: Text(
																						"Solo los pedidos que el supervisor derivó a pañol "
																						"pueden pedirse a compras.",
																					),
																				),
																			);
																			return;
																		}
																		final mo = consultas[idx];
																		if (mo.workflowStatus !=
																				MaintenanceWorkflowStatus.forwardedToPanol) {
																			if (!context.mounted) return;
																			ScaffoldMessenger.of(context).showSnackBar(
																				const SnackBar(
																					content: Text(
																						"Este pedido ya fue enviado a compras o está en otro estado.",
																					),
																				),
																			);
																			return;
																		}
																		try {
																			await ref
																					.read(comprasStockRepositoryProvider)
																					.createPanolStockRequestFromMaintenanceOrder(
																						mo,
																					);
																			await ref
																					.read(panolForwardedOrdersProvider.notifier)
																					.refresh(silent: true);
																			if (!context.mounted) return;
																			ScaffoldMessenger.of(context).showSnackBar(
																				SnackBar(
																					content: Text(
																						"Pedido registrado para compra: ${mo.numeroOrden} · ${mo.producto}",
																					),
																				),
																			);
																		} catch (e) {
																			final s = e.toString().toLowerCase();
																			if (!context.mounted) return;
																			if (s.contains("duplicate") ||
																					s.contains("unique") ||
																					s.contains("23505")) {
																				ScaffoldMessenger.of(context).showSnackBar(
																					const SnackBar(
																						content: Text(
																							"Este pedido ya fue enviado a compras.",
																						),
																					),
																				);
																				return;
																			}
																			ScaffoldMessenger.of(context).showSnackBar(
																				SnackBar(
																					content: Text("No se pudo enviar a compras: $e"),
																				),
																			);
																		}
																	}

																	Future<void> onAgregarStock() async {
																		if (!esConsulta || !context.mounted) return;
																		final mo = consultas[idx];
																		if (mo.workflowStatus !=
																				MaintenanceWorkflowStatus
																						.forwardedToPanol) {
																			return;
																		}
																		final nombrePedido = mo.producto.trim();
																		final match = _buscarStockMatch(
																			pedidoProducto: nombrePedido,
																			stocks: stocks,
																		);
																		final dialogResult =
																				await showPanolAgregarStockDialog(
																			context: context,
																			order: mo,
																			matchedProduct: match,
																		);
																		if (dialogResult == null || !context.mounted) {
																			return;
																		}
																		try {
																			await ref
																					.read(
																						maintenanceOrdersRepositoryProvider,
																					)
																					.panolConfirmCatalogStock(
																						orderId: mo.id,
																						stockItemId:
																								dialogResult.stockItemId,
																						cantidad: dialogResult.cantidad,
																					);
																			await ref
																					.read(panolForwardedOrdersProvider.notifier)
																					.refresh(silent: true);
																			await ref
																					.read(supervisorStockCatalogProvider.notifier)
																					.refresh();
																			if (!context.mounted) return;
																			ScaffoldMessenger.of(context).showSnackBar(
																				SnackBar(
																					content: Text(
																						"Stock registrado · listo para retiro: "
																						"${mo.numeroOrden} · ${mo.producto}",
																					),
																				),
																			);
																		} catch (e) {
																			if (!context.mounted) return;
																			ScaffoldMessenger.of(context).showSnackBar(
																				SnackBar(
																					content: Text(
																						"No se pudo registrar el stock: $e",
																					),
																				),
																			);
																		}
																	}

																	void onAgregarStockSync() {
																		unawaited(onAgregarStock());
																	}

																	Future<void> onRetiro() async {
																		if (!esConsulta || !context.mounted) return;
																		final mo = consultas[idx];
																		if (mo.workflowStatus !=
																				MaintenanceWorkflowStatus
																						.supervisorStockOk &&
																			mo.workflowStatus !=
																					MaintenanceWorkflowStatus
																							.comprasArrivedNotified) {
																			return;
																		}
																		try {
																			await ref
																					.read(
																						maintenanceOrdersRepositoryProvider,
																					)
																					.markCompleted(mo.id);
																			await ref
																					.read(panolForwardedOrdersProvider.notifier)
																					.refresh(silent: true);
																			ref.invalidate(panolOrderHistoryProvider);
																			ref.read(panolOrderHistoryProvider);
																			if (mo.stockItemId != null &&
																					mo.stockItemId!.isNotEmpty) {
																				await ref
																						.read(
																							supervisorStockCatalogProvider
																									.notifier,
																						)
																						.refresh();
																			}
																			if (!context.mounted) return;
																			final desconto = mo.stockItemId != null &&
																					mo.stockItemId!.isNotEmpty;
																			ScaffoldMessenger.of(context).showSnackBar(
																				SnackBar(
																					content: Text(
																						desconto
																								? "Retiro registrado: ${mo.numeroOrden} · "
																										"se descontaron ${mo.quantity} u. del inventario."
																								: "Retiro registrado: ${mo.numeroOrden}.",
																					),
																				),
																			);
																		} catch (e) {
																			if (!context.mounted) return;
																			ScaffoldMessenger.of(context).showSnackBar(
																				SnackBar(
																					content: Text(
																						"No se pudo registrar el retiro: $e",
																					),
																				),
																			);
																		}
																	}

																	void onRetiroSync() {
																		unawaited(onRetiro());
																	}

																	void onTerceroSync() {
																		unawaited(onTercero());
																	}

																	void onSeguimiento() {
																		if (!context.mounted) return;
																		context.push("/panol/seguimiento");
																	}

																	if (compact) {
																		return _PanolPedidoCardMobile(
																			pedido: o,
																			fmtFecha: _fmtFecha,
																			stockCantidad: cantidadStock,
																			onVer: onVer,
																			onTercero: onTerceroSync,
																			workflowMo: moRow?.workflowStatus,
																			onSeguimiento: moRow == null ? null : onSeguimiento,
																			tresBotonesPanolPendiente: tresBotonesPanolPendiente,
																			onAgregarStock: tresBotonesPanolPendiente
																					? onAgregarStockSync
																					: null,
																			listoParaRetiro: listoParaRetiro,
																			onRetiro: listoParaRetiro ? onRetiroSync : null,
																		);
																	}

																	return Padding(
																		padding: const EdgeInsets.symmetric(
																			horizontal: 12,
																			vertical: 10,
																		),
																		child: Row(
																			crossAxisAlignment:
																					CrossAxisAlignment.center,
																			children: [
																				Expanded(
																					flex: 1,
																					child: Text(
																						o.numero,
																						style: const TextStyle(
																							fontWeight: FontWeight.w700,
																							color: Colors.black87,
																						),
																					),
																				),
																				Expanded(
																					flex: 1,
																					child: Text(
																						_fmtFecha(o.fecha),
																						style: TextStyle(
																							color: Colors.grey.shade700,
																							fontWeight: FontWeight.w600,
																							fontSize: 12.5,
																						),
																					),
																				),
																				Expanded(
																					flex: 3,
																					child: Text(
																						o.producto,
																						overflow: TextOverflow.ellipsis,
																						style: const TextStyle(
																							fontWeight: FontWeight.w600,
																							color: Colors.black87,
																						),
																					),
																				),
																				Expanded(
																					flex: 2,
																					child: Align(
																						alignment: Alignment.centerLeft,
																						child: _PedidoBadge(
																							estado: o.estado,
																						),
																					),
																				),
																				Expanded(
																					flex: 3,
																					child: _PanolPedidosActions(
																						compact: false,
																						stockCantidad: cantidadStock,
																						onVer: onVer,
																						onTercero: onTerceroSync,
																						workflowMo: moRow?.workflowStatus,
																						onSeguimiento:
																								moRow == null ? null : onSeguimiento,
																						tresBotonesPanolPendiente:
																								tresBotonesPanolPendiente,
																						onAgregarStock: tresBotonesPanolPendiente
																								? onAgregarStockSync
																								: null,
																						listoParaRetiro: listoParaRetiro,
																						onRetiro:
																								listoParaRetiro ? onRetiroSync : null,
																					),
																				),
																			],
																		),
																	);
																},
															),
														],
													),
												),
											),
										),
									),
								),
							],
						),
					),
				],
			),
		);
			},
		);
	}
}

/// Tarjeta de pedido si el ancho es menor a 720px (evita filas comprimidas).
class _PanolPedidoCardMobile extends StatelessWidget {
	const _PanolPedidoCardMobile({
		required this.pedido,
		required this.fmtFecha,
		required this.stockCantidad,
		required this.onVer,
		required this.onTercero,
		this.workflowMo,
		this.onSeguimiento,
		this.tresBotonesPanolPendiente = false,
		this.onAgregarStock,
		this.listoParaRetiro = false,
		this.onRetiro,
	});

	final _PanolPedidoDemo pedido;
	final String Function(DateTime d) fmtFecha;
	final int stockCantidad;
	final VoidCallback onVer;
	final VoidCallback onTercero;
	final MaintenanceWorkflowStatus? workflowMo;
	final VoidCallback? onSeguimiento;
	final bool tresBotonesPanolPendiente;
	final VoidCallback? onAgregarStock;
	final bool listoParaRetiro;
	final VoidCallback? onRetiro;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
			child: Material(
				color: AppTokens.whiteSurface,
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				clipBehavior: Clip.antiAlias,
				elevation: 1,
				shadowColor: Colors.black12,
				child: Padding(
					padding: const EdgeInsets.all(14),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Row(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text(
													pedido.numero,
													style: const TextStyle(
														fontWeight: FontWeight.w800,
														fontSize: 15,
														color: Colors.black87,
													),
												),
												const SizedBox(height: 4),
												Text(
													fmtFecha(pedido.fecha),
													style: TextStyle(
														color: Colors.grey.shade700,
														fontSize: 13,
														fontWeight: FontWeight.w600,
													),
												),
											],
										),
									),
									const SizedBox(width: 10),
									_PedidoBadge(estado: pedido.estado),
								],
							),
							const SizedBox(height: 12),
							Text(
								pedido.producto.replaceAll("\n", " · "),
								style: const TextStyle(
									fontWeight: FontWeight.w600,
									fontSize: 14,
									height: 1.4,
									color: Colors.black87,
								),
							),
							const SizedBox(height: 14),
							_PanolPedidosActions(
								compact: true,
								stockCantidad: stockCantidad,
								onVer: onVer,
								onTercero: onTercero,
								workflowMo: workflowMo,
								onSeguimiento: onSeguimiento,
								tresBotonesPanolPendiente: tresBotonesPanolPendiente,
								onAgregarStock: onAgregarStock,
								listoParaRetiro: listoParaRetiro,
								onRetiro: onRetiro,
							),
						],
					),
				),
			),
		);
	}
}

class _PanolPedidosHeaderRow extends StatelessWidget {
	const _PanolPedidosHeaderRow();

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.center,
				children: const [
					Expanded(
							flex: 1,
							child: Text("N° PEDIDO",
									style: TextStyle(fontWeight: FontWeight.w700))),
					Expanded(
							flex: 1,
							child:
									Text("FECHA", style: TextStyle(fontWeight: FontWeight.w700))),
					Expanded(
							flex: 3,
							child: Text("PRODUCTO",
									style: TextStyle(fontWeight: FontWeight.w700))),
					Expanded(
							flex: 2,
							child: Text("ESTADO",
									style: TextStyle(fontWeight: FontWeight.w700))),
					Expanded(flex: 3, child: SizedBox()),
				],
			),
		);
	}
}

class _PanolPedidosActions extends StatelessWidget {
	_PanolPedidosActions({
		this.compact = false,
		required this.stockCantidad,
		required this.onVer,
		required this.onTercero,
		this.workflowMo,
		this.onSeguimiento,
		this.tresBotonesPanolPendiente = false,
		this.onAgregarStock,
		this.listoParaRetiro = false,
		this.onRetiro,
	});

	final bool compact;
	final int stockCantidad;
	final VoidCallback onVer;
	final VoidCallback onTercero;
	final MaintenanceWorkflowStatus? workflowMo;
	final VoidCallback? onSeguimiento;
	final bool tresBotonesPanolPendiente;
	final VoidCallback? onAgregarStock;
	final bool listoParaRetiro;
	final VoidCallback? onRetiro;

	@override
	Widget build(BuildContext context) {
		final tieneStock = stockCantidad > 0;
		final stockBg = tieneStock ? AppTokens.statusOk : Colors.grey.shade300;
		final stockIcon =
				tieneStock ? Icons.inventory_2_outlined : Icons.remove_circle_outline;
		final stockText = stockCantidad == 0 ? "0" : stockCantidad.toString();

		final wf = workflowMo;
		final seguimientoCompras = !tieneStock &&
				wf != null &&
				wf != MaintenanceWorkflowStatus.forwardedToPanol &&
				(wf == MaintenanceWorkflowStatus.panolRequestedCompras ||
						wf == MaintenanceWorkflowStatus.comprasOcNotified ||
						wf == MaintenanceWorkflowStatus.comprasPurchaseDone ||
						wf == MaintenanceWorkflowStatus.comprasArrivedNotified);
		final mostrarSeguimientoExtra =
				onSeguimiento != null && !seguimientoCompras;

		if (listoParaRetiro && onRetiro != null) {
			final retiroLabel = wf == MaintenanceWorkflowStatus.comprasArrivedNotified
					? "COMPLETAR"
					: "RETIRAR";
			if (compact) {
				return Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						OutlinedButton.icon(
							onPressed: onVer,
							icon: const Icon(Icons.visibility_outlined, size: 20),
							label: const Text(
								"VER",
								style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
							),
							style: OutlinedButton.styleFrom(
								foregroundColor: Colors.black87,
								side: BorderSide(color: AppTokens.greyBorder),
								padding: const EdgeInsets.symmetric(vertical: 12),
							),
						),
						const SizedBox(height: 10),
						FilledButton.icon(
							onPressed: onRetiro,
							icon: const Icon(Icons.download_done_outlined, size: 22),
							label: Text(
								retiroLabel,
								style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
							),
							style: FilledButton.styleFrom(
								backgroundColor: AppTokens.redAction,
								foregroundColor: Colors.white,
								padding: const EdgeInsets.symmetric(vertical: 14),
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(AppTokens.radiusMd),
								),
							),
						),
					],
				);
			}
			return Row(
				children: [
					Expanded(
						child: OutlinedButton.icon(
							onPressed: onVer,
							icon: const Icon(Icons.visibility_outlined, size: 18),
							label: const Text(
								"VER",
								style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
							),
							style: OutlinedButton.styleFrom(
								padding: EdgeInsets.zero,
								foregroundColor: Colors.black87,
								side: BorderSide(color: AppTokens.greyBorder),
								minimumSize: const Size(0, 40),
							),
						),
					),
					const SizedBox(width: 8),
					Expanded(
						flex: 2,
						child: FilledButton.icon(
							onPressed: onRetiro,
							icon: const Icon(Icons.download_done_outlined, size: 18),
							label: Text(
								retiroLabel,
								textAlign: TextAlign.center,
								style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
							),
							style: FilledButton.styleFrom(
								padding: EdgeInsets.zero,
								backgroundColor: AppTokens.redAction,
								foregroundColor: Colors.white,
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(AppTokens.radiusMd),
								),
								minimumSize: const Size(0, 40),
							),
						),
					),
				],
			);
		}

		if (tresBotonesPanolPendiente && onAgregarStock != null) {
			if (compact) {
				return Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						OutlinedButton.icon(
							onPressed: onVer,
							icon: const Icon(Icons.visibility_outlined, size: 20),
							label: const Text(
								"VER",
								style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
							),
							style: OutlinedButton.styleFrom(
								foregroundColor: Colors.black87,
								side: BorderSide(color: AppTokens.greyBorder),
								padding: const EdgeInsets.symmetric(vertical: 12),
							),
						),
						const SizedBox(height: 10),
						FilledButton.icon(
							onPressed: onAgregarStock,
							icon: const Icon(Icons.add_box_outlined, size: 22),
							label: const Text(
								"AGREGAR NUEVO STOCK",
								style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
								textAlign: TextAlign.center,
							),
							style: FilledButton.styleFrom(
								backgroundColor: AppTokens.statusOk,
								foregroundColor: Colors.white,
								padding: const EdgeInsets.symmetric(vertical: 14),
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(AppTokens.radiusMd),
								),
							),
						),
						const SizedBox(height: 10),
						FilledButton.icon(
							onPressed: onTercero,
							icon: const Icon(Icons.shopping_cart_outlined, size: 22),
							label: const Text(
								"PEDIR A COMPRAS",
								style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
								textAlign: TextAlign.center,
							),
							style: FilledButton.styleFrom(
								backgroundColor: AppTokens.redAction,
								foregroundColor: Colors.white,
								padding: const EdgeInsets.symmetric(vertical: 14),
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(AppTokens.radiusMd),
								),
							),
						),
					],
				);
			}
			return Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				mainAxisSize: MainAxisSize.min,
				children: [
					Row(
						children: [
							Expanded(
								child: OutlinedButton.icon(
									onPressed: onVer,
									icon: const Icon(Icons.visibility_outlined, size: 18),
									label: const Text(
										"VER",
										style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
									),
									style: OutlinedButton.styleFrom(
										padding: EdgeInsets.zero,
										foregroundColor: Colors.black87,
										side: BorderSide(color: AppTokens.greyBorder),
										minimumSize: const Size(0, 40),
									),
								),
							),
							const SizedBox(width: 6),
							Expanded(
								flex: 2,
								child: FilledButton.icon(
									onPressed: onAgregarStock,
									icon: const Icon(Icons.add_box_outlined, size: 18),
									label: const Text(
										"AGREGAR\nSTOCK",
										textAlign: TextAlign.center,
										style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
									),
									style: FilledButton.styleFrom(
										padding: EdgeInsets.zero,
										backgroundColor: AppTokens.statusOk,
										foregroundColor: Colors.white,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(AppTokens.radiusMd),
										),
										minimumSize: const Size(0, 40),
									),
								),
							),
							const SizedBox(width: 6),
							Expanded(
								flex: 2,
								child: FilledButton.icon(
									onPressed: onTercero,
									icon: const Icon(Icons.shopping_cart_outlined, size: 18),
									label: const Text(
										"PEDIR A\nCOMPRAS",
										textAlign: TextAlign.center,
										style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
									),
									style: FilledButton.styleFrom(
										padding: EdgeInsets.zero,
										backgroundColor: AppTokens.redAction,
										foregroundColor: Colors.white,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(AppTokens.radiusMd),
										),
										minimumSize: const Size(0, 40),
									),
								),
							),
						],
					),
				],
			);
		}

		final String terceroLabel;
		final IconData terceroIcon;
		final Color terceroBg;
		final VoidCallback? terceroOn;

		if (tieneStock) {
			terceroLabel = compact ? "RETIRAR" : "RETIRAR";
			terceroIcon = Icons.download_done_outlined;
			terceroBg = AppTokens.statusOk;
			terceroOn = onTercero;
		} else if (seguimientoCompras) {
			terceroLabel = compact ? "SEGUIMIENTO" : "SEGUIMIENTO";
			terceroIcon = Icons.timeline;
			terceroBg = Colors.indigo.shade700;
			terceroOn = onSeguimiento;
		} else {
			terceroLabel = compact ? "PEDIR A COMPRAS" : "PEDIR A\nCOMPRAS";
			terceroIcon = Icons.shopping_cart_outlined;
			terceroBg = AppTokens.redAction;
			terceroOn = onTercero;
		}

		if (compact) {
			return Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Row(
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							Expanded(
								child: OutlinedButton.icon(
									onPressed: onVer,
									icon: const Icon(Icons.visibility_outlined, size: 20),
									label: const Text(
										"VER",
										style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
									),
									style: OutlinedButton.styleFrom(
										foregroundColor: Colors.black87,
										side: BorderSide(color: AppTokens.greyBorder),
										padding: const EdgeInsets.symmetric(vertical: 12),
									),
								),
							),
							const SizedBox(width: 10),
							_StockCantidadPill(
								cantidad: stockCantidad,
								icon: stockIcon,
								background: stockBg,
							),
						],
					),
					const SizedBox(height: 10),
					FilledButton.icon(
						onPressed: terceroOn,
						icon: Icon(terceroIcon, size: 22),
						label: Text(
							terceroLabel,
							style: const TextStyle(
								fontWeight: FontWeight.w800,
								fontSize: 14,
								letterSpacing: 0.2,
							),
						),
						style: FilledButton.styleFrom(
							backgroundColor: terceroBg,
							foregroundColor: Colors.white,
							padding: const EdgeInsets.symmetric(vertical: 14),
							shape: RoundedRectangleBorder(
								borderRadius: BorderRadius.circular(AppTokens.radiusMd),
							),
						),
					),
					if (mostrarSeguimientoExtra) ...[
						const SizedBox(height: 10),
						OutlinedButton.icon(
							onPressed: onSeguimiento!,
							icon: Icon(Icons.timeline_outlined, size: 20, color: Colors.indigo.shade800),
							label: Text(
								"SEGUIMIENTO",
								style: TextStyle(
									fontWeight: FontWeight.w800,
									fontSize: 13,
									color: Colors.indigo.shade900,
								),
							),
							style: OutlinedButton.styleFrom(
								foregroundColor: Colors.indigo.shade900,
								side: BorderSide(color: Colors.indigo.shade700, width: 1.2),
								padding: const EdgeInsets.symmetric(vertical: 12),
							),
						),
					],
				],
			);
		}

		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			mainAxisSize: MainAxisSize.min,
			children: [
				Row(
					children: [
						Expanded(
							child: OutlinedButton.icon(
								onPressed: onVer,
								icon: const Icon(Icons.visibility_outlined, size: 18),
								label: const Text(
									"VER",
									style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
								),
								style: OutlinedButton.styleFrom(
									padding: EdgeInsets.zero,
									foregroundColor: Colors.black87,
									side: BorderSide(color: AppTokens.greyBorder),
									minimumSize: const Size(0, 40),
								),
							),
						),
						const SizedBox(width: 8),
						Expanded(
							child: FilledButton.icon(
								onPressed: null,
								icon: Icon(stockIcon, size: 18),
								label: Text(
									"STOCK\n$stockText",
									textAlign: TextAlign.center,
									style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
								),
								style: FilledButton.styleFrom(
									padding: EdgeInsets.zero,
									backgroundColor: stockBg,
									foregroundColor: Colors.black87,
									shape: RoundedRectangleBorder(
										borderRadius: BorderRadius.circular(AppTokens.radiusMd),
									),
									minimumSize: const Size(0, 40),
								),
							),
						),
						const SizedBox(width: 8),
						Expanded(
							child: FilledButton.icon(
								onPressed: terceroOn,
								icon: Icon(terceroIcon, size: 18),
								label: Text(
									tieneStock
											? "RETIRAR"
											: seguimientoCompras
													? "SEGUIMIENTO"
													: "PEDIR A\nCOMPRAS",
									textAlign: TextAlign.center,
									style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
								),
								style: FilledButton.styleFrom(
									padding: EdgeInsets.zero,
									backgroundColor: terceroBg,
									foregroundColor: Colors.white,
									shape: RoundedRectangleBorder(
										borderRadius: BorderRadius.circular(AppTokens.radiusMd),
									),
									minimumSize: const Size(0, 40),
								),
							),
						),
					],
				),
				if (mostrarSeguimientoExtra) ...[
					const SizedBox(height: 8),
					OutlinedButton.icon(
						onPressed: onSeguimiento!,
						icon: Icon(Icons.timeline_outlined, size: 18, color: Colors.indigo.shade800),
						label: Text(
							"SEGUIMIENTO",
							style: TextStyle(
								fontWeight: FontWeight.w800,
								fontSize: 12,
								color: Colors.indigo.shade900,
							),
						),
						style: OutlinedButton.styleFrom(
							foregroundColor: Colors.indigo.shade900,
							side: BorderSide(color: Colors.indigo.shade700, width: 1.2),
							padding: const EdgeInsets.symmetric(vertical: 10),
						),
					),
				],
			],
		);
	}
}

/// Indicador de stock (solo lectura) para layout compacto.
class _StockCantidadPill extends StatelessWidget {
	const _StockCantidadPill({
		required this.cantidad,
		required this.icon,
		required this.background,
	});

	final int cantidad;
	final IconData icon;
	final Color background;

	@override
	Widget build(BuildContext context) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
			decoration: BoxDecoration(
				color: background,
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				border: Border.all(color: AppTokens.greyBorder),
			),
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(icon, size: 20, color: Colors.black87),
					const SizedBox(width: 6),
					Text(
						cantidad.toString(),
						style: const TextStyle(
							fontWeight: FontWeight.w800,
							fontSize: 16,
							color: Colors.black87,
						),
					),
				],
			),
		);
	}
}

class _PedidoBadge extends StatelessWidget {
	const _PedidoBadge({required this.estado});

	final _EstadoPedidoPanol estado;

	@override
	Widget build(BuildContext context) {
		switch (estado) {
			case _EstadoPedidoPanol.enProceso:
				return _chip("EN PROCESO", AppTokens.statusWarn, Colors.black87);
			case _EstadoPedidoPanol.pendiente:
				return _chip("PENDIENTE", AppTokens.statusPending, Colors.white);
			case _EstadoPedidoPanol.consultaMantenimiento:
				return _chip("CONSULTA", AppTokens.roleMantenimientoBg, Colors.white);
			case _EstadoPedidoPanol.enTramiteCompras:
				return _chip("EN COMPRAS", Colors.amber.shade800, Colors.black87);
			case _EstadoPedidoPanol.materialEnPlanta:
				return _chip("LISTO RETIRO", AppTokens.statusOk, Colors.white);
			case _EstadoPedidoPanol.listoParaRetiro:
				return _chip("LISTO RETIRO", AppTokens.statusOk, Colors.white);
			case _EstadoPedidoPanol.completado:
				return _chip("COMPLETADO", AppTokens.statusOk, Colors.white);
		}
	}

	Widget _chip(String text, Color bg, Color fg) {
		return Container(
			constraints: const BoxConstraints(maxWidth: 160),
			padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
			decoration: BoxDecoration(
				color: bg,
				borderRadius: BorderRadius.circular(6),
			),
			child: FittedBox(
				fit: BoxFit.scaleDown,
				alignment: Alignment.center,
				child: Text(
					text,
					maxLines: 1,
					style: TextStyle(
						color: fg,
						fontSize: 11,
						fontWeight: FontWeight.bold,
					),
				),
			),
		);
	}
}
