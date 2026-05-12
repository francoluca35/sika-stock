import "dart:math" as math;

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "widgets/compras_pagination_bar.dart";
import "widgets/compras_screen_metrics.dart";

enum _PrioridadPedido { alta, media, baja }

/// Progreso del aviso por pedido: OC emitida → llegada a planta.
enum _EstadoAvisoPedido {
	pendiente,
	ordenEmitidaAvisada,
	enPlanta,
}

/// Solicitud externa mostrada en historial (la OC la emite otro sistema).
class _SolicitudCompraRow {
	_SolicitudCompraRow({
		required this.numeroOrden,
		required this.producto,
		required this.cantidad,
		required this.prioridad,
		required this.fecha,
		required this.sectorSolicitante,
		required this.solicitante,
		this.observaciones,
		this.codigoInterno,
		this.unidadMedida = "unid.",
		this.imagenUrl,
	});

	final String numeroOrden;
	final String producto;
	final int cantidad;
	final _PrioridadPedido prioridad;
	final DateTime fecha;
	final String sectorSolicitante;
	final String solicitante;
	final String? observaciones;
	final String? codigoInterno;
	final String unidadMedida;
	/// URL pública del ítem (opcional); si viene vacía no se muestra bloque de imagen.
	final String? imagenUrl;
}

/// Listado de pedidos solicitados por otros sectores; **Aviso** notifica emisión de OC.
class ComprasHistorialPedidosScreen extends StatefulWidget {
	const ComprasHistorialPedidosScreen({super.key});

	@override
	State<ComprasHistorialPedidosScreen> createState() =>
			_ComprasHistorialPedidosScreenState();
}

class _ComprasHistorialPedidosScreenState
		extends State<ComprasHistorialPedidosScreen> {
	final _buscarCtrl = TextEditingController();
	_PrioridadPedido? _filtroPrioridad;
	int _paginaActual = 0;
	static const int _itemsPorPagina = 5;

	final Map<String, _EstadoAvisoPedido> _estadoAvisoPorOrden = {};

	_EstadoAvisoPedido _estadoAviso(_SolicitudCompraRow row) =>
			_estadoAvisoPorOrden[row.numeroOrden] ?? _EstadoAvisoPedido.pendiente;

	static List<_SolicitudCompraRow> _demo() {
		return [
			_SolicitudCompraRow(
				numeroOrden: "OC-0001",
				producto: "Filtro de aire",
				cantidad: 10,
				prioridad: _PrioridadPedido.alta,
				fecha: DateTime(2026, 5, 2),
				sectorSolicitante: "Producción — Línea 2",
				solicitante: "María González",
				observaciones:
						"Repuesto crítico. Mismo fabricante que el stock anterior (referencia en almacén A-12).",
				codigoInterno: "MAT-FLT-001",
				unidadMedida: "unid.",
				imagenUrl: "https://picsum.photos/seed/sika_oc1/640/400",
			),
			_SolicitudCompraRow(
				numeroOrden: "OC-0002",
				producto: "Aceite hidráulico",
				cantidad: 20,
				prioridad: _PrioridadPedido.media,
				fecha: DateTime(2026, 5, 1),
				sectorSolicitante: "Mantenimiento",
				solicitante: "Carlos Ruiz",
				observaciones: "ISO VG 46. Entrega en bidones de 20 L.",
				codigoInterno: "LUB-HYD-046",
				unidadMedida: "L",
			),
			_SolicitudCompraRow(
				numeroOrden: "OC-0003",
				producto: "Rodamiento 6205",
				cantidad: 15,
				prioridad: _PrioridadPedido.baja,
				fecha: DateTime(2026, 4, 28),
				sectorSolicitante: "Taller mecánico",
				solicitante: "Ana Ferreyra",
				codigoInterno: "ROD-6205-2RS",
				unidadMedida: "unid.",
				imagenUrl: "https://picsum.photos/seed/sika_oc3/640/400",
			),
			_SolicitudCompraRow(
				numeroOrden: "OC-0004",
				producto: "Casco seguridad",
				cantidad: 8,
				prioridad: _PrioridadPedido.alta,
				fecha: DateTime(2026, 4, 25),
				sectorSolicitante: "Higiene y seguridad",
				solicitante: "Lucía Pérez",
				observaciones: "Clase E. Talle M y L por igual si es posible.",
				codigoInterno: "EPP-CAS-E",
				unidadMedida: "unid.",
			),
			_SolicitudCompraRow(
				numeroOrden: "OC-0005",
				producto: "Guantes nitrilo L",
				cantidad: 50,
				prioridad: _PrioridadPedido.media,
				fecha: DateTime(2026, 4, 22),
				sectorSolicitante: "Laboratorio",
				solicitante: "Diego Martín",
				codigoInterno: "EPP-GNT-L",
				unidadMedida: "par",
			),
			_SolicitudCompraRow(
				numeroOrden: "OC-0006",
				producto: "Cable flexible 2,5 mm²",
				cantidad: 100,
				prioridad: _PrioridadPedido.baja,
				fecha: DateTime(2026, 4, 20),
				sectorSolicitante: "Instalaciones",
				solicitante: "Fernando Costa",
				observaciones: "Color negro, H07V-K.",
				codigoInterno: "EL-CAB-2.5",
				unidadMedida: "m",
				imagenUrl: "https://picsum.photos/seed/sika_oc6/640/400",
			),
			_SolicitudCompraRow(
				numeroOrden: "OC-0007",
				producto: "Grasa litio EP2",
				cantidad: 12,
				prioridad: _PrioridadPedido.alta,
				fecha: DateTime(2026, 4, 18),
				sectorSolicitante: "Mantenimiento",
				solicitante: "Carlos Ruiz",
				codigoInterno: "LUB-GRS-EP2",
				unidadMedida: "kg",
			),
			_SolicitudCompraRow(
				numeroOrden: "OC-0008",
				producto: "Llave allen 10 mm",
				cantidad: 6,
				prioridad: _PrioridadPedido.media,
				fecha: DateTime(2026, 4, 15),
				sectorSolicitante: "Taller mecánico",
				solicitante: "Ana Ferreyra",
				codigoInterno: "HERR-ALL-10",
				unidadMedida: "unid.",
			),
		];
	}

	@override
	void dispose() {
		_buscarCtrl.dispose();
		super.dispose();
	}

	List<_SolicitudCompraRow> _filtrar(List<_SolicitudCompraRow> todos) {
		final q = _buscarCtrl.text.trim().toLowerCase();
		return todos.where((r) {
			if (_filtroPrioridad != null && r.prioridad != _filtroPrioridad) {
				return false;
			}
			if (q.isEmpty) return true;
			return r.numeroOrden.toLowerCase().contains(q) ||
					r.producto.toLowerCase().contains(q) ||
					r.sectorSolicitante.toLowerCase().contains(q) ||
					r.solicitante.toLowerCase().contains(q) ||
					(r.codigoInterno?.toLowerCase().contains(q) ?? false) ||
					(r.observaciones?.toLowerCase().contains(q) ?? false);
		}).toList();
	}

	String _fmtFecha(DateTime d) {
		return "${d.day.toString().padLeft(2, "0")}/"
			"${d.month.toString().padLeft(2, "0")}/"
			"${d.year}";
	}

	void _mostrarSnackOrdenEmitida(_SolicitudCompraRow row) {
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					"Notificación enviada: se emitió orden de compra ${row.numeroOrden} · ${row.producto}.",
				),
				action: SnackBarAction(
					label: "OK",
					textColor: AppTokens.yellowAccent,
					onPressed: () {},
				),
			),
		);
	}

	void _mostrarSnackLlegadaPlanta(_SolicitudCompraRow row) {
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					"Aviso: el pedido ${row.numeroOrden} (${row.producto}) ya llegó a planta.",
				),
				action: SnackBarAction(
					label: "OK",
					textColor: AppTokens.yellowAccent,
					onPressed: () {},
				),
			),
		);
	}

	void _onPasoAviso(_SolicitudCompraRow row) {
		final key = row.numeroOrden;
		final actual = _estadoAviso(row);
		if (actual == _EstadoAvisoPedido.pendiente) {
			setState(() {
				_estadoAvisoPorOrden[key] = _EstadoAvisoPedido.ordenEmitidaAvisada;
			});
			_mostrarSnackOrdenEmitida(row);
			return;
		}
		if (actual == _EstadoAvisoPedido.ordenEmitidaAvisada) {
			setState(() {
				_estadoAvisoPorOrden[key] = _EstadoAvisoPedido.enPlanta;
			});
			_mostrarSnackLlegadaPlanta(row);
		}
	}

	String _estadoAvisoDetalleText(_SolicitudCompraRow row) {
		switch (_estadoAviso(row)) {
			case _EstadoAvisoPedido.pendiente:
				return "Pendiente: aún no se envió aviso de OC emitida.";
			case _EstadoAvisoPedido.ordenEmitidaAvisada:
				return "Aviso enviado: OC emitida. Pendiente aviso de llegada a planta.";
			case _EstadoAvisoPedido.enPlanta:
				return "Material registrado en planta.";
		}
	}

	Widget _dialogCampo(String titulo, String texto) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 10),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						titulo,
						style: TextStyle(
							fontSize: 12,
							color: Colors.grey.shade700,
							fontWeight: FontWeight.w600,
						),
					),
					const SizedBox(height: 2),
					SelectableText(
						texto,
						style: const TextStyle(fontSize: 15, height: 1.35),
					),
				],
			),
		);
	}

	Widget? _dialogImagenSiHay(String? url, double anchoMax) {
		final u = url?.trim();
		if (u == null || u.isEmpty) return null;
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				const Divider(height: 24),
				Text(
					"Imagen del ítem",
					style: TextStyle(
						fontSize: 12,
						color: Colors.grey.shade700,
						fontWeight: FontWeight.w600,
					),
				),
				const SizedBox(height: 8),
				ClipRRect(
					borderRadius: BorderRadius.circular(AppTokens.radiusMd),
					child: Image.network(
						u,
						width: anchoMax,
						fit: BoxFit.fitWidth,
						loadingBuilder: (context, child, loadingProgress) {
							if (loadingProgress == null) return child;
							return SizedBox(
								height: 200,
								width: anchoMax,
								child: const Center(child: CircularProgressIndicator()),
							);
						},
						errorBuilder: (context, error, stackTrace) => Container(
							width: anchoMax,
							padding: const EdgeInsets.all(16),
							color: Colors.grey.shade200,
							child: Text(
								"No se pudo cargar la imagen.\nComprobá la URL o la conexión.",
								style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
							),
						),
					),
				),
			],
		);
	}

	void _ver(_SolicitudCompraRow row) {
		final anchoDialog = math.min(
			520.0,
			math.max(280.0, MediaQuery.sizeOf(context).width - 48),
		);
		final bloqueImagen = _dialogImagenSiHay(row.imagenUrl, anchoDialog);
		showDialog<void>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: Text(row.numeroOrden),
				content: SizedBox(
					width: anchoDialog,
					child: SingleChildScrollView(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								_dialogCampo("Producto", row.producto),
								if (row.codigoInterno != null &&
										row.codigoInterno!.trim().isNotEmpty)
									_dialogCampo("Código interno", row.codigoInterno!.trim()),
								_dialogCampo(
									"Cantidad",
									"${row.cantidad} ${row.unidadMedida}",
								),
								_dialogCampo("Prioridad", _prioridadLabel(row.prioridad)),
								_dialogCampo("Fecha de solicitud", _fmtFecha(row.fecha)),
								_dialogCampo("Sector solicitante", row.sectorSolicitante),
								_dialogCampo("Solicitante", row.solicitante),
								if (row.observaciones != null &&
										row.observaciones!.trim().isNotEmpty)
									_dialogCampo("Observaciones", row.observaciones!.trim()),
								_dialogCampo("Estado de avisos (esta app)", _estadoAvisoDetalleText(row)),
								const Divider(height: 20),
								Text(
									"Solicitud registrada por otro sector. La orden de compra "
									"se gestiona en el sistema externo; desde acá solo se envían avisos.",
									style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
								),
								if (bloqueImagen != null) bloqueImagen,
							],
						),
					),
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

	Future<void> _mostrarFiltroPrioridad() async {
		await showModalBottomSheet<void>(
			context: context,
			builder: (ctx) => SafeArea(
				child: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						const ListTile(title: Text("Filtrar por prioridad")),
						ListTile(
							title: const Text("Todas"),
							onTap: () {
								setState(() {
									_filtroPrioridad = null;
									_paginaActual = 0;
								});
								Navigator.pop(ctx);
							},
						),
						ListTile(
							title: const Text("Alta"),
							onTap: () {
								setState(() {
									_filtroPrioridad = _PrioridadPedido.alta;
									_paginaActual = 0;
								});
								Navigator.pop(ctx);
							},
						),
						ListTile(
							title: const Text("Media"),
							onTap: () {
								setState(() {
									_filtroPrioridad = _PrioridadPedido.media;
									_paginaActual = 0;
								});
								Navigator.pop(ctx);
							},
						),
						ListTile(
							title: const Text("Baja"),
							onTap: () {
								setState(() {
									_filtroPrioridad = _PrioridadPedido.baja;
									_paginaActual = 0;
								});
								Navigator.pop(ctx);
							},
						),
					],
				),
			),
		);
	}

	String _prioridadLabel(_PrioridadPedido p) {
		switch (p) {
			case _PrioridadPedido.alta:
				return "ALTA";
			case _PrioridadPedido.media:
				return "MEDIA";
			case _PrioridadPedido.baja:
				return "BAJA";
		}
	}

	Widget _prioridadBadge(_PrioridadPedido p) {
		Color bg;
		Color fg;
		switch (p) {
			case _PrioridadPedido.alta:
				bg = AppTokens.redAction;
				fg = Colors.white;
				break;
			case _PrioridadPedido.media:
				bg = AppTokens.statusWarn;
				fg = Colors.black87;
				break;
			case _PrioridadPedido.baja:
				bg = Colors.grey.shade400;
				fg = Colors.black87;
				break;
		}
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
			decoration: BoxDecoration(
				color: bg,
				borderRadius: BorderRadius.circular(6),
			),
			child: Text(
				_prioridadLabel(p),
				style: TextStyle(
					color: fg,
					fontSize: 11,
					fontWeight: FontWeight.bold,
				),
			),
		);
	}

	ButtonStyle _styleAvisoTabla(Color bg, Color fg) => FilledButton.styleFrom(
				backgroundColor: bg,
				foregroundColor: fg,
				elevation: 0,
				padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
				minimumSize: const Size(118, 46),
				tapTargetSize: MaterialTapTargetSize.padded,
				textStyle: TextStyle(
					fontWeight: FontWeight.w700,
					fontSize: 13,
					color: fg,
				),
			);

	ButtonStyle _styleAvisoCard(Color bg, Color fg) => FilledButton.styleFrom(
				backgroundColor: bg,
				foregroundColor: fg,
				elevation: 0,
				padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
				minimumSize: const Size(120, 48),
				textStyle: TextStyle(
					fontWeight: FontWeight.w700,
					fontSize: 14,
					color: fg,
				),
			);

	ButtonStyle get _styleVerTabla => OutlinedButton.styleFrom(
				foregroundColor: Colors.black87,
				side: const BorderSide(color: Colors.black54, width: 1.25),
				padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
				minimumSize: const Size(92, 46),
				tapTargetSize: MaterialTapTargetSize.padded,
				textStyle: const TextStyle(
					fontWeight: FontWeight.w700,
					fontSize: 13,
				),
			);

	Widget _botonVerTabla(_SolicitudCompraRow row) {
		return OutlinedButton.icon(
			onPressed: () => _ver(row),
			icon: const Icon(Icons.visibility_outlined, size: 20),
			label: const Text("Ver"),
			style: _styleVerTabla,
		);
	}

	Widget _widgetBotonAviso(_SolicitudCompraRow row, {required bool compact}) {
		final estado = _estadoAviso(row);
		switch (estado) {
			case _EstadoAvisoPedido.pendiente:
				return FilledButton.icon(
					onPressed: () => _onPasoAviso(row),
					icon: const Icon(Icons.campaign, size: 22, color: Colors.black87),
					label: const Text("Aviso"),
					style: compact
							? _styleAvisoTabla(AppTokens.yellowHeader, Colors.black87)
							: _styleAvisoCard(AppTokens.yellowHeader, Colors.black87),
				);
			case _EstadoAvisoPedido.ordenEmitidaAvisada:
				return FilledButton.icon(
					onPressed: () => _onPasoAviso(row),
					icon: const Icon(Icons.inventory_2, size: 22, color: Colors.white),
					label: const Text("Avisar llegada"),
					style: compact
							? _styleAvisoTabla(AppTokens.statusOk, Colors.white)
							: _styleAvisoCard(AppTokens.statusOk, Colors.white),
				);
			case _EstadoAvisoPedido.enPlanta:
				return Padding(
					padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Icon(
								Icons.check_circle,
								size: compact ? 22 : 24,
								color: AppTokens.statusOk,
							),
							SizedBox(width: compact ? 6 : 8),
							Text(
								"En planta",
								style: TextStyle(
									color: AppTokens.statusOk,
									fontWeight: FontWeight.w700,
									fontSize: compact ? 13 : 14,
								),
							),
						],
					),
				);
		}
	}

	Widget _pedidoCardMovil(_SolicitudCompraRow row) {
		return Card(
			margin: EdgeInsets.zero,
			elevation: 0,
			color: AppTokens.whiteSurface,
			shape: RoundedRectangleBorder(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				side: const BorderSide(color: AppTokens.greyBorder),
			),
			child: Padding(
				padding: const EdgeInsets.all(14),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Expanded(
									child: Text(
										row.numeroOrden,
										style: const TextStyle(
											fontWeight: FontWeight.w700,
											fontSize: 16,
											color: Colors.black87,
										),
									),
								),
								_prioridadBadge(row.prioridad),
							],
						),
						const SizedBox(height: 8),
						Text(
							row.producto,
							style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
						),
						const SizedBox(height: 10),
						Row(
							children: [
								Icon(
									Icons.calendar_today_outlined,
									size: 16,
									color: Colors.grey.shade700,
								),
								const SizedBox(width: 6),
								Text(
									_fmtFecha(row.fecha),
									style: TextStyle(
										fontSize: 13,
										color: Colors.grey.shade700,
									),
								),
								const Spacer(),
								Text(
									"Cant. ${row.cantidad}",
									style: const TextStyle(
										fontWeight: FontWeight.w600,
										fontSize: 13,
									),
								),
							],
						),
						const SizedBox(height: 12),
						Wrap(
							spacing: 8,
							runSpacing: 8,
							alignment: WrapAlignment.end,
							children: [
								OutlinedButton.icon(
									onPressed: () => _ver(row),
									icon: const Icon(Icons.visibility_outlined, size: 22),
									label: const Text("Ver"),
									style: OutlinedButton.styleFrom(
										foregroundColor: Colors.black87,
										side: const BorderSide(color: Colors.black54, width: 1.25),
										padding: const EdgeInsets.symmetric(
											horizontal: 18,
											vertical: 14,
										),
										minimumSize: const Size(100, 48),
										textStyle: const TextStyle(
											fontWeight: FontWeight.w700,
											fontSize: 14,
										),
									),
								),
								_widgetBotonAviso(row, compact: false),
							],
						),
					],
				),
			),
		);
	}

	Widget _tablaPedidosDesktop(
		List<_SolicitudCompraRow> paginaItems,
		double minTableWidth,
	) {
		// Deja ~660px a orden, cantidad, prioridad, fecha y acciones (botones más grandes).
		final productoAncho = math.max(140.0, minTableWidth - 660);
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
								dataRowMinHeight: 64,
								dataRowMaxHeight: 96,
								horizontalMargin: 12,
								columnSpacing: 12,
								columns: const [
									DataColumn(label: Text("N° ORDEN")),
									DataColumn(label: Text("PRODUCTO")),
									DataColumn(label: Text("CANTIDAD"), numeric: true),
									DataColumn(label: Text("PRIORIDAD")),
									DataColumn(label: Text("FECHA")),
									DataColumn(label: Text("ACCIONES")),
								],
								rows: [
									for (final row in paginaItems)
										DataRow(
											cells: [
												DataCell(Text(
													row.numeroOrden,
													style: const TextStyle(
														fontWeight: FontWeight.w600,
													),
												)),
												DataCell(
													SizedBox(
														width: productoAncho,
														child: Text(
															row.producto,
															overflow: TextOverflow.ellipsis,
														),
													),
												),
												DataCell(Text("${row.cantidad}")),
												DataCell(_prioridadBadge(row.prioridad)),
												DataCell(Text(_fmtFecha(row.fecha))),
												DataCell(
													Padding(
														padding: const EdgeInsets.symmetric(vertical: 6),
														child: Row(
															mainAxisSize: MainAxisSize.min,
															crossAxisAlignment:
																	CrossAxisAlignment.center,
															children: [
																_botonVerTabla(row),
																const SizedBox(width: 10),
																_widgetBotonAviso(row, compact: true),
															],
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

	@override
	Widget build(BuildContext context) {
		final todos = _demo();
		final filtrados = _filtrar(todos);
		final totalPaginas = filtrados.isEmpty
			? 1
			: (filtrados.length / _itemsPorPagina).ceil().clamp(1, 999);
		final paginaSegura =
			totalPaginas <= 1 ? 0 : _paginaActual.clamp(0, totalPaginas - 1);
		final inicio = paginaSegura * _itemsPorPagina;
		final paginaItems = filtrados.skip(inicio).take(_itemsPorPagina).toList();

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "HISTORIAL DE PEDIDOS",
						onBack: () {
							if (context.canPop()) {
								context.pop();
							} else {
								context.go("/home");
							}
						},
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
									onChanged: (_) => setState(() {
										_paginaActual = 0;
									}),
									decoration: InputDecoration(
										isDense: true,
										hintText: "Buscar pedido…",
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
								final filtro = OutlinedButton(
									onPressed: _mostrarFiltroPrioridad,
									style: OutlinedButton.styleFrom(
										foregroundColor: Colors.black87,
										side: const BorderSide(color: Colors.black54),
										padding: const EdgeInsets.symmetric(
											horizontal: 14,
											vertical: 12,
										),
									),
									child: const Text(
										"FILTRAR",
										style: TextStyle(fontWeight: FontWeight.bold),
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
					Padding(
						padding: ComprasScreenMetrics.horizontalPadding(context),
						child: Text(
							"Solicitudes de otros sectores (sin alta de OC desde esta app).",
							style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
						),
					),
					const SizedBox(height: 8),
					Expanded(
						child: filtrados.isEmpty
							? Center(
									child: Text(
										"No hay pedidos con los filtros actuales.",
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
														_pedidoCardMovil(paginaItems[i]),
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
												child: _tablaPedidosDesktop(
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
