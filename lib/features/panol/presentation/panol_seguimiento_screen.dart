import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../compras/presentation/widgets/compras_screen_metrics.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "widgets/producto_seguimiento_panel.dart";

/// Pantalla **Seguimiento** Pañol: listado por estado de compra y detalle de trayecto.
class PanolSeguimientoScreen extends StatelessWidget {
	const PanolSeguimientoScreen({super.key});

	void _back(BuildContext context) {
		if (context.canPop()) {
			context.pop();
		} else {
			context.go("/home");
		}
	}

	static DateTime _dt(int day, int hour, [int minute = 0]) =>
			DateTime(2026, 5, day, hour, minute);

	/// Demo local; sustituir por datos reales (p. ej. Supabase).
	static List<ProductoSeguimiento> _itemsDemo() {
		return [
			ProductoSeguimiento(
				id: "1",
				producto: "Filtro de aire industrial",
				referenciaPedido: "SC-2026-0142",
				estado: SeguimientoCompraEstado.pendienteCompra,
				trayecto: [
					SeguimientoEvento(titulo: "Solicitud registrada", cuando: _dt(2, 8, 12)),
					SeguimientoEvento(
						titulo: "Derivado a compras",
						cuando: _dt(2, 9, 45),
					),
					SeguimientoEvento(
						titulo: "En cotización proveedor",
						cuando: _dt(3, 11, 20),
					),
				],
			),
			ProductoSeguimiento(
				id: "2",
				producto: "Aceite hidráulico ISO VG 46",
				referenciaPedido: "SC-2026-0138",
				estado: SeguimientoCompraEstado.pendienteCompra,
				trayecto: [
					SeguimientoEvento(titulo: "Solicitud registrada", cuando: _dt(5, 7, 30)),
					SeguimientoEvento(
						titulo: "Pendiente aprobación presupuesto",
						cuando: _dt(5, 15, 5),
					),
				],
			),
			ProductoSeguimiento(
				id: "3",
				producto: "Rodamiento 6205-2RS",
				referenciaPedido: "SC-2026-0110",
				estado: SeguimientoCompraEstado.comprado,
				trayecto: [
					SeguimientoEvento(titulo: "Solicitud registrada", cuando: _dt(8, 10, 0)),
					SeguimientoEvento(
						titulo: "Orden de compra emitida",
						cuando: _dt(9, 14, 22),
					),
					SeguimientoEvento(
						titulo: "Confirmación proveedor",
						cuando: _dt(10, 9, 18),
					),
					SeguimientoEvento(
						titulo: "Despacho / en tránsito",
						cuando: _dt(11, 16, 40),
					),
				],
			),
			ProductoSeguimiento(
				id: "4",
				producto: "Cable H07V-K 2,5 mm² (negro)",
				referenciaPedido: "SC-2026-0099",
				estado: SeguimientoCompraEstado.comprado,
				trayecto: [
					SeguimientoEvento(titulo: "Solicitud registrada", cuando: _dt(1, 8, 5)),
					SeguimientoEvento(
						titulo: "Orden de compra emitida",
						cuando: _dt(2, 11, 10),
					),
					SeguimientoEvento(
						titulo: "En tránsito — depósito central",
						cuando: _dt(10, 7, 55),
					),
				],
			),
			ProductoSeguimiento(
				id: "5",
				producto: "Grasa litio EP2",
				referenciaPedido: "SC-2026-0088",
				estado: SeguimientoCompraEstado.entregado,
				trayecto: [
					SeguimientoEvento(titulo: "Solicitud registrada", cuando: _dt(4, 9, 0)),
					SeguimientoEvento(
						titulo: "Orden de compra emitida",
						cuando: _dt(5, 13, 15),
					),
					SeguimientoEvento(
						titulo: "Recepción parcial en planta",
						cuando: _dt(9, 10, 30),
					),
					SeguimientoEvento(
						titulo: "Entrega completa — recepción cerrada",
						cuando: _dt(9, 14, 8),
					),
				],
			),
			ProductoSeguimiento(
				id: "6",
				producto: "Casco seguridad clase E",
				referenciaPedido: "SC-2026-0075",
				estado: SeguimientoCompraEstado.entregado,
				trayecto: [
					SeguimientoEvento(titulo: "Solicitud registrada", cuando: _dt(6, 8, 40)),
					SeguimientoEvento(
						titulo: "Orden de compra emitida",
						cuando: _dt(6, 16, 12),
					),
					SeguimientoEvento(
						titulo: "Entregado en almacén pañol",
						cuando: _dt(8, 11, 3),
					),
				],
			),
			ProductoSeguimiento(
				id: "7",
				producto: "Guantes nitrilo talla L",
				referenciaPedido: "SC-2026-0061",
				estado: SeguimientoCompraEstado.comprado,
				trayecto: [
					SeguimientoEvento(titulo: "Solicitud registrada", cuando: _dt(11, 7, 15)),
					SeguimientoEvento(
						titulo: "Orden de compra emitida",
						cuando: _dt(11, 12, 0),
					),
					SeguimientoEvento(
						titulo: "Listo para retiro proveedor",
						cuando: _dt(12, 8, 45),
					),
				],
			),
		];
	}

	@override
	Widget build(BuildContext context) {
		final items = _itemsDemo();
		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "SEGUIMIENTO",
						onBack: () => _back(context),
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
										"Rojo: sin comprar · Amarillo: comprado · Verde: entregado. "
										"Tocá un producto para ver fechas y horas de cada cambio.",
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
						child: Center(
							child: ConstrainedBox(
								constraints: const BoxConstraints(maxWidth: AppTokens.maxContentWidth),
								child: ProductoSeguimientoPanel(items: items),
							),
						),
					),
				],
			),
		);
	}
}
