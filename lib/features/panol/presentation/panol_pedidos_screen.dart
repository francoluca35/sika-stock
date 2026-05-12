import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../application/panol_forwarded_orders_provider.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/domain/stock_product.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "../../supervisor/domain/maintenance_order.dart";

class _PanolPedidoDemo {
	_PanolPedidoDemo({
		required this.numero,
		required this.fecha,
		required this.producto,
		required this.estado,
	});

	final String numero;
	final DateTime fecha;
	final String producto;
	final _EstadoPedidoPanol estado;
}

enum _EstadoPedidoPanol {
	enProceso,
	pendiente,
	completado,
	consultaMantenimiento
}

List<_PanolPedidoDemo> _demoPedidos() {
	return [
		_PanolPedidoDemo(
			numero: "PED-1042",
			fecha: DateTime(2026, 5, 2),
			producto: "Filtro de aceite",
			estado: _EstadoPedidoPanol.enProceso,
		),
		_PanolPedidoDemo(
			numero: "PED-1038",
			fecha: DateTime(2026, 5, 1),
			producto: "Grasa litio EP2",
			estado: _EstadoPedidoPanol.pendiente,
		),
		_PanolPedidoDemo(
			numero: "PED-1021",
			fecha: DateTime(2026, 4, 28),
			producto: "Casco seguridad blanco",
			estado: _EstadoPedidoPanol.completado,
		),
	];
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

	int _calcularCantidadStock(
		_PanolPedidoDemo pedido,
		List<StockProduct> stocks,
	) {
		final match = stocks.where(
			(p) => _productoCoincideConStock(
				pedidoProducto: pedido.producto,
				stockProducto: p,
			),
		);
		return match.fold<int>(0, (acc, p) => acc + p.cantidad);
	}

	_PanolPedidoDemo _fromMaintenanceConsulta(MaintenanceOrder mo) {
		return _PanolPedidoDemo(
			numero: mo.numeroOrden,
			fecha: mo.fechaPedido,
			producto: "${mo.producto}\n${mo.solicitante}",
			estado: _EstadoPedidoPanol.consultaMantenimiento,
		);
	}

	@override
	Widget build(BuildContext context) {
		final pedidosDemo = _demoPedidos();
		final stocks = ref.watch(supervisorStockCatalogProvider);
		final consultar = ref.watch(panolForwardedOrdersProvider);
		final consultas = consultar.maybeWhen(
			data: (v) => v,
			orElse: () => <MaintenanceOrder>[],
		);
		final merged = [
			...consultas.map(_fromMaintenanceConsulta),
			...pedidosDemo,
		];
		final consultasCount = consultas.length;

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "PEDIDOS",
						onBack: () => _back(context),
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
																			onPressed: () {
																				ScaffoldMessenger.of(context)
																						.showSnackBar(
																					const SnackBar(
																						content: Text(
																							"Historial de pedidos — próximamente.",
																						),
																					),
																				);
																			},
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
															_PanolPedidosHeaderRow(),
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
																	final tieneStock = cantidadStock > 0;

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
																						stockCantidad: cantidadStock,
																						onVer: () {
																							if (esConsulta) {
																								final mo = consultas[idx];
																								ScaffoldMessenger.of(context)
																										.showSnackBar(
																									SnackBar(
																										content: Text(
																											"${mo.numeroOrden}\n${mo.motivo}\nDestino: ${mo.destination}",
																										),
																									),
																								);
																								return;
																							}
																							ScaffoldMessenger.of(context)
																									.showSnackBar(
																								SnackBar(
																									content: Text(
																										"Pedido ${o.numero}: ${o.producto} · ${o.estado.name.toUpperCase()}",
																									),
																								),
																							);
																						},
																						onTercero: () {
																							ScaffoldMessenger.of(context)
																									.showSnackBar(
																								SnackBar(
																									content: Text(
																										tieneStock
																												? "Retirar pedido ${o.numero} (stock OK)."
																												: "Pedido ${o.numero}: pedir a compras (stock no disponible).",
																									),
																								),
																							);
																						},
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
	const _PanolPedidosActions({
		required this.stockCantidad,
		required this.onVer,
		required this.onTercero,
	});

	final int stockCantidad;
	final VoidCallback onVer;
	final VoidCallback onTercero;

	@override
	Widget build(BuildContext context) {
		final tieneStock = stockCantidad > 0;
		final stockBg = tieneStock ? AppTokens.statusOk : Colors.grey.shade300;
		final stockIcon =
				tieneStock ? Icons.inventory_2_outlined : Icons.remove_circle_outline;
		final stockText = stockCantidad == 0 ? "0" : stockCantidad.toString();

		final terceroTexto = tieneStock ? "RETIRAR" : "PEDIR A\nCOMPRAS";
		final terceroBg = tieneStock ? AppTokens.statusOk : AppTokens.redAction;
		final terceroIcon = tieneStock
				? Icons.download_done_outlined
				: Icons.shopping_cart_outlined;

		return Row(
			children: [
				Expanded(
					child: OutlinedButton.icon(
						onPressed: onVer,
						icon: const Icon(Icons.visibility_outlined, size: 18),
						label: const Text("VER",
								style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
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
						onPressed: onTercero,
						icon: Icon(terceroIcon, size: 18),
						label: Text(
							terceroTexto,
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
			case _EstadoPedidoPanol.completado:
				return _chip("COMPLETADO", AppTokens.statusOk, Colors.white);
		}
	}

	Widget _chip(String text, Color bg, Color fg) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
			decoration: BoxDecoration(
				color: bg,
				borderRadius: BorderRadius.circular(6),
			),
			child: Text(
				text,
				style: TextStyle(
					color: fg,
					fontSize: 11,
					fontWeight: FontWeight.bold,
				),
			),
		);
	}
}
