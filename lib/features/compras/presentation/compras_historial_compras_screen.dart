import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "widgets/compras_pagination_bar.dart";
import "widgets/compras_screen_metrics.dart";

/// Evento en la línea de tiempo de una compra.
class _PasoLineaTiempo {
	const _PasoLineaTiempo({
		required this.titulo,
		required this.fecha,
		required this.icon,
	});

	final String titulo;
	final DateTime fecha;
	final IconData icon;
}

/// Fila del historial de compras (demo; sustituir por datos reales / Supabase).
class _CompraHistorialRow {
	_CompraHistorialRow({
		required this.producto,
		required this.fechaSolicitud,
		required this.fechaCompra,
		required this.fechaEntrega,
	});

	final String producto;
	final DateTime fechaSolicitud;
	final DateTime fechaCompra;
	final DateTime fechaEntrega;

	List<_PasoLineaTiempo> pasosLineaTiempo() {
		final t1 = fechaSolicitud;
		final t2 = fechaCompra;
		final midDays = fechaEntrega.difference(t2).inDays;
		final entre = t2.add(Duration(days: midDays <= 1 ? 1 : midDays ~/ 2));
		var transito = fechaEntrega.subtract(const Duration(days: 1));
		if (!transito.isAfter(t2)) transito = entre;
		if (transito.isAfter(fechaEntrega)) transito = fechaEntrega;
		return [
			_PasoLineaTiempo(
				titulo: "Solicitud registrada",
				fecha: t1,
				icon: Icons.edit_calendar_outlined,
			),
			_PasoLineaTiempo(
				titulo: "Orden de compra emitida",
				fecha: t2,
				icon: Icons.receipt_long_outlined,
			),
			_PasoLineaTiempo(
				titulo: "Confirmación proveedor",
				fecha: entre,
				icon: Icons.verified_outlined,
			),
			_PasoLineaTiempo(
				titulo: "Despacho / en tránsito",
				fecha: transito,
				icon: Icons.local_shipping_outlined,
			),
			_PasoLineaTiempo(
				titulo: "Entregado",
				fecha: fechaEntrega,
				icon: Icons.inventory_2_outlined,
			),
		];
	}
}

/// **Historial de compras**: listado + línea de tiempo desde solicitud hasta entrega.
class ComprasHistorialComprasScreen extends ConsumerStatefulWidget {
	const ComprasHistorialComprasScreen({super.key});

	@override
	ConsumerState<ComprasHistorialComprasScreen> createState() =>
			_ComprasHistorialComprasScreenState();
}

class _ComprasHistorialComprasScreenState
		extends ConsumerState<ComprasHistorialComprasScreen> {
	final _buscarCtrl = TextEditingController();
	int _paginaActual = 0;
	static const int _itemsPorPagina = 10;

	static final List<String> _productosDemo = [
		"Filtro de aire",
		"Aceite hidráulico",
		"Rodamiento 6205",
		"Casco seguridad",
		"Guantes nitrilo L",
		"Cable flexible 2,5 mm²",
		"Grasa litio EP2",
		"Llave allen 10 mm",
		"Perno hexagonal M16",
		"Chaleco reflectivo XL",
	];

	static List<_CompraHistorialRow> _generarDemo() {
		final out = <_CompraHistorialRow>[];
		for (var i = 0; i < 95; i++) {
			final base = DateTime(2024, 5, 12).subtract(Duration(days: i % 60));
			final compra = base.add(const Duration(days: 2));
			final entrega = compra.add(const Duration(days: 3));
			out.add(
				_CompraHistorialRow(
					producto: _productosDemo[i % _productosDemo.length],
					fechaSolicitud: base,
					fechaCompra: compra,
					fechaEntrega: entrega,
				),
			);
		}
		return out;
	}

	@override
	void dispose() {
		_buscarCtrl.dispose();
		super.dispose();
	}

	String _fmt(DateTime d) {
		return "${d.day.toString().padLeft(2, "0")}/"
			"${d.month.toString().padLeft(2, "0")}/"
			"${d.year}";
	}

	List<_CompraHistorialRow> _filtrar(List<_CompraHistorialRow> todos) {
		final q = _buscarCtrl.text.trim().toLowerCase();
		if (q.isEmpty) return todos;
		return todos.where((r) => r.producto.toLowerCase().contains(q)).toList();
	}

	void _mostrarLineaTiempo(_CompraHistorialRow row) {
		final pasos = row.pasosLineaTiempo();
		showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			showDragHandle: true,
			backgroundColor: AppTokens.whiteSurface,
			shape: const RoundedRectangleBorder(
				borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
			),
			builder: (ctx) {
				final maxH = MediaQuery.sizeOf(ctx).height * 0.55;
				return Padding(
					padding: EdgeInsets.only(
						left: 20,
						right: 20,
						top: 8,
						bottom: MediaQuery.paddingOf(ctx).bottom + 16,
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Text(
								row.producto,
								style: const TextStyle(
									fontWeight: FontWeight.bold,
									fontSize: 17,
									color: Colors.black87,
								),
							),
							const SizedBox(height: 4),
							Text(
								"Desde la solicitud hasta la entrega",
								style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
							),
							const SizedBox(height: 16),
							ConstrainedBox(
								constraints: BoxConstraints(maxHeight: maxH),
								child: SingleChildScrollView(
									child: _LineaTiempoVertical(pasos: pasos, fmt: _fmt),
								),
							),
						],
					),
				);
			},
		);
	}

	Widget _compraCardMovil(_CompraHistorialRow row) {
		return Card(
			margin: EdgeInsets.zero,
			elevation: 0,
			color: AppTokens.whiteSurface,
			shape: RoundedRectangleBorder(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				side: const BorderSide(color: AppTokens.greyBorder),
			),
			child: InkWell(
				onTap: () => _mostrarLineaTiempo(row),
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				child: Padding(
					padding: const EdgeInsets.all(14),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Row(
								children: [
									Expanded(
										child: Text(
											row.producto,
											style: const TextStyle(
												fontWeight: FontWeight.w700,
												fontSize: 16,
												color: Colors.black87,
											),
										),
									),
									Icon(
										Icons.chevron_right,
										color: Colors.grey.shade700,
									),
								],
							),
							const SizedBox(height: 12),
							_rowFechaMovil(
								Icons.edit_calendar_outlined,
								"Solicitud",
								_fmt(row.fechaSolicitud),
							),
							const SizedBox(height: 8),
							_rowFechaMovil(
								Icons.receipt_long_outlined,
								"Compra",
								_fmt(row.fechaCompra),
							),
							const SizedBox(height: 8),
							_rowFechaMovil(
								Icons.inventory_2_outlined,
								"Entrega",
								_fmt(row.fechaEntrega),
							),
						],
					),
				),
			),
		);
	}

	Widget _rowFechaMovil(IconData icon, String etiqueta, String texto) {
		return Row(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Icon(icon, size: 18, color: Colors.grey.shade700),
				const SizedBox(width: 10),
				Expanded(
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text(
								etiqueta,
								style: TextStyle(
									fontSize: 12,
									color: Colors.grey.shade600,
								),
							),
							const SizedBox(height: 2),
							Text(
								texto,
								style: const TextStyle(
									fontWeight: FontWeight.w600,
									fontSize: 14,
									color: Colors.black87,
								),
							),
						],
					),
				),
			],
		);
	}

	Widget _tablaComprasDesktop(
		List<_CompraHistorialRow> paginaItems,
		double minTableWidth,
	) {
		// Espacio fijo aproximado: fechas + columna ruta (evita que el producto empuje la flecha fuera de vista).
		const reservaSinProducto = 600.0;
		final productoAncho = math.max(
			160.0,
			minTableWidth - reservaSinProducto,
		);
		return Scrollbar(
			child: SingleChildScrollView(
				scrollDirection: Axis.horizontal,
				child: ConstrainedBox(
					constraints: BoxConstraints(minWidth: minTableWidth),
					child: SingleChildScrollView(
						child: DataTable(
								headingRowColor: WidgetStateProperty.all(
									AppTokens.yellowHeader,
								),
								dataRowMinHeight: 48,
								dataRowMaxHeight: 64,
								horizontalMargin: 12,
								columnSpacing: 14,
								columns: [
									const DataColumn(label: Text("FECHA")),
									const DataColumn(label: Text("PRODUCTO")),
									const DataColumn(label: Text("FECHA DE COMPRA")),
									const DataColumn(label: Text("FECHA DE ENTREGA")),
									DataColumn(
										label: Tooltip(
											message: "Ver ruta de compra",
											child: const Padding(
												padding: EdgeInsets.only(left: 4),
												child: Icon(
													Icons.alt_route,
													size: 20,
													color: Colors.black87,
												),
											),
										),
									),
								],
								rows: [
									for (final row in paginaItems)
										DataRow(
											cells: [
												DataCell(
													Row(
														mainAxisSize: MainAxisSize.min,
														children: [
															Icon(
																Icons.calendar_today_outlined,
																size: 16,
																color: Colors.grey.shade800,
															),
															const SizedBox(width: 6),
															Text(_fmt(row.fechaSolicitud)),
														],
													),
												),
												DataCell(
													SizedBox(
														width: productoAncho,
														child: Text(
															row.producto,
															overflow: TextOverflow.ellipsis,
														),
													),
												),
												DataCell(Text(_fmt(row.fechaCompra))),
												DataCell(Text(_fmt(row.fechaEntrega))),
												DataCell(
													SizedBox(
														width: 52,
														child: Align(
															alignment: Alignment.centerRight,
															child: IconButton(
																padding: EdgeInsets.zero,
																constraints: const BoxConstraints(
																	minWidth: 48,
																	minHeight: 40,
																),
																icon: const Icon(
																	Icons.chevron_right,
																	color: Colors.black87,
																),
																tooltip: "Ver ruta de compra",
																onPressed: () =>
																		_mostrarLineaTiempo(row),
															),
														),
													),
												),
											],
										),
								],
							),
						),
					),
				),
		);
	}

	Future<void> _mostrarFiltro() async {
		await showModalBottomSheet<void>(
			context: context,
			builder: (ctx) => SafeArea(
				child: Padding(
					padding: const EdgeInsets.all(16),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							const Text(
								"Filtros — próximamente",
								style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
							),
							const SizedBox(height: 8),
							Text(
								"Acá podrás filtrar por rango de fechas o estado.",
								style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
							),
							const SizedBox(height: 16),
							FilledButton(
								onPressed: () => Navigator.pop(ctx),
								child: const Text("Cerrar"),
							),
						],
					),
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final todos = _generarDemo();
		final filtrados = _filtrar(todos);
		final totalPaginas = filtrados.isEmpty
			? 1
			: (filtrados.length / _itemsPorPagina).ceil().clamp(1, 999);
		final paginaSegura =
			totalPaginas <= 1 ? 0 : _paginaActual.clamp(0, totalPaginas - 1);
		final inicio = paginaSegura * _itemsPorPagina;
		final paginaItems =
			filtrados.skip(inicio).take(_itemsPorPagina).toList();

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "HISTORIAL DE COMPRAS",
						onBack: () {
							if (context.canPop()) {
								context.pop();
							} else {
								context.go("/home");
							}
						},
						onRefresh: () => ScreenRefresh.compras(ref),
					),
					Padding(
						padding: ComprasScreenMetrics.horizontalPadding(context).copyWith(
							top: 12,
							bottom: 8,
						),
						child: LayoutBuilder(
							builder: (context, c) {
								final stackToolbar = c.maxWidth < 520;
								final search = TextField(
									controller: _buscarCtrl,
									onChanged: (_) => setState(() => _paginaActual = 0),
									decoration: InputDecoration(
										isDense: true,
										hintText: "Buscar producto…",
										prefixIcon: const Icon(Icons.search, size: 22),
										filled: true,
										fillColor: AppTokens.whiteSurface,
										border: OutlineInputBorder(
											borderRadius:
													BorderRadius.circular(AppTokens.radiusMd),
											borderSide:
													const BorderSide(color: AppTokens.greyBorder),
										),
										contentPadding: const EdgeInsets.symmetric(
											horizontal: 12,
											vertical: 12,
										),
									),
								);
								final filtro = OutlinedButton.icon(
									onPressed: _mostrarFiltro,
									icon: const Icon(Icons.filter_list, size: 20),
									label: const Text(
										"FILTRAR",
										style: TextStyle(fontWeight: FontWeight.bold),
									),
									style: OutlinedButton.styleFrom(
										foregroundColor: Colors.black87,
										side: const BorderSide(color: Colors.black54),
										padding: const EdgeInsets.symmetric(
											horizontal: 12,
											vertical: 12,
										),
									),
								);
								if (stackToolbar) {
									return Column(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: [
											search,
											const SizedBox(height: 10),
											SizedBox(width: double.infinity, child: filtro),
										],
									);
								}
								return Row(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Expanded(child: search),
										const SizedBox(width: 10),
										filtro,
									],
								);
							},
						),
					),
					Expanded(
						child: filtrados.isEmpty
							? Center(
									child: Text(
										"No hay compras con la búsqueda actual.",
										style: TextStyle(color: Colors.grey.shade600),
									),
								)
							: LayoutBuilder(
									builder: (context, constraints) {
										final wide =
												ComprasScreenMetrics.useWideTableFromConstraints(
													constraints.maxWidth,
												);
										final pad =
												ComprasScreenMetrics.horizontalPadding(context);
										if (!wide) {
											return ListView.separated(
												padding: EdgeInsets.fromLTRB(
													pad.left,
													8,
													pad.right,
													16,
												),
												itemCount: paginaItems.length,
												separatorBuilder: (_, __) =>
														const SizedBox(height: 12),
												itemBuilder: (ctx, i) =>
														_compraCardMovil(paginaItems[i]),
											);
										}
										return Scrollbar(
											child: SingleChildScrollView(
												padding: EdgeInsets.fromLTRB(
													pad.left,
													0,
													pad.right,
													16,
												),
												child: _tablaComprasDesktop(
													paginaItems,
													math.max(
														0.0,
														constraints.maxWidth - pad.horizontal,
													),
												),
											),
										);
									},
								),
					),
					if (filtrados.isNotEmpty && totalPaginas > 1)
						ComprasPaginationBar(
							currentPage: paginaSegura,
							totalPages: totalPaginas,
							onPage: (i) => setState(() => _paginaActual = i),
						),
				],
			),
		);
	}
}

class _LineaTiempoVertical extends StatelessWidget {
	const _LineaTiempoVertical({
		required this.pasos,
		required this.fmt,
	});

	final List<_PasoLineaTiempo> pasos;
	final String Function(DateTime d) fmt;

	@override
	Widget build(BuildContext context) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				for (var i = 0; i < pasos.length; i++) ...[
					Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Column(
								children: [
									CircleAvatar(
										radius: 18,
										backgroundColor: AppTokens.yellowHeader,
										child: Icon(pasos[i].icon, size: 18, color: Colors.black87),
									),
									if (i < pasos.length - 1)
										Container(
											width: 2,
											height: 36,
											margin: const EdgeInsets.symmetric(vertical: 2),
											color: Colors.grey.shade400,
										),
								],
							),
							const SizedBox(width: 12),
							Expanded(
								child: Padding(
									padding: const EdgeInsets.only(bottom: 12),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												pasos[i].titulo,
												style: const TextStyle(
													fontWeight: FontWeight.w700,
													fontSize: 14,
													color: Colors.black87,
												),
											),
											const SizedBox(height: 2),
											Text(
												fmt(pasos[i].fecha),
												style: TextStyle(
													fontSize: 13,
													color: Colors.grey.shade700,
												),
											),
										],
									),
								),
							),
						],
					),
				],
			],
		);
	}
}
