import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "widgets/compras_pagination_bar.dart";
import "widgets/compras_screen_metrics.dart";
import "../application/compras_in_app_notifications_provider.dart";
import "../application/compras_panol_stock_requests_provider.dart";
import "../application/compras_stock_repository_provider.dart";
import "../domain/compras_panol_stock_request_row.dart";
import "../../orders/application/mantenimiento_notificaciones_provider.dart";
import "../../orders/application/mis_pedidos_mantenimiento_provider.dart";
import "../../panol/application/panol_forwarded_orders_provider.dart";
import "../../supervisor/application/supervisor_maintenance_history_provider.dart";

enum _PrioridadPedido { alta, media, baja }

_PrioridadPedido _prioridadPedidoDesdeString(String raw) {
	final p = raw.trim().toLowerCase();
	if (p.contains("alta") || p == "a" || p == "1") {
		return _PrioridadPedido.alta;
	}
	if (p.contains("baja") || p == "c" || p == "3") {
		return _PrioridadPedido.baja;
	}
	return _PrioridadPedido.media;
}

/// Progreso del aviso por pedido: OC → compra realizada → llegada a planta.
enum _EstadoAvisoPedido {
	pendiente,
	ocEmitida,
	compraRealizada,
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
		this.maintenanceOrderId,
		this.workflowStatusDb,
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
	final String? maintenanceOrderId;
	final String? workflowStatusDb;

	factory _SolicitudCompraRow.fromPanolRequest(ComprasPanolStockRequestRow r) {
		final img = r.imagenUrl?.trim();
		return _SolicitudCompraRow(
			numeroOrden: r.orderNumber,
			producto: r.productName,
			cantidad: r.quantity,
			prioridad: _prioridadPedidoDesdeString(r.priority),
			fecha: r.createdAt,
			sectorSolicitante: r.destination,
			solicitante: r.solicitanteDisplay,
			observaciones:
					"Solicitud enviada desde pañol por falta de stock en depósito.",
			codigoInterno: null,
			unidadMedida: "unid.",
			imagenUrl: (img != null && img.isNotEmpty) ? img : null,
			maintenanceOrderId: r.maintenanceOrderId,
			workflowStatusDb: r.maintenanceWorkflowStatus,
		);
	}
}

/// Historial de solicitudes enviadas desde pañol por falta de stock (orden más reciente primero).
class ComprasHistorialPedidosScreen extends ConsumerStatefulWidget {
	const ComprasHistorialPedidosScreen({super.key});

	@override
	ConsumerState<ComprasHistorialPedidosScreen> createState() =>
			_ComprasHistorialPedidosScreenState();
}

class _ComprasHistorialPedidosScreenState
		extends ConsumerState<ComprasHistorialPedidosScreen> {
	final _buscarCtrl = TextEditingController();
	_PrioridadPedido? _filtroPrioridad;
	int _paginaActual = 0;
	static const int _itemsPorPagina = 10;

	final Map<String, _EstadoAvisoPedido> _estadoAvisoPorOrden = {};

	_EstadoAvisoPedido _estadoAviso(_SolicitudCompraRow row) {
		final ws = row.workflowStatusDb;
		if (ws != null) {
			switch (ws) {
				case "panol_requested_compras":
					return _EstadoAvisoPedido.pendiente;
				case "compras_oc_notified":
					return _EstadoAvisoPedido.ocEmitida;
				case "compras_purchase_done":
					return _EstadoAvisoPedido.compraRealizada;
				case "compras_arrived_notified":
					return _EstadoAvisoPedido.enPlanta;
				default:
					break;
			}
		}
		return _estadoAvisoPorOrden[row.numeroOrden] ?? _EstadoAvisoPedido.pendiente;
	}

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) async {
			await ref.read(comprasStockRepositoryProvider).markAllPanolStockNotificationsRead();
			if (!mounted) return;
			ref.invalidate(comprasInAppNotificationsProvider);
		});
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

	void _popHistorial() {
		if (!context.mounted) return;
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

	void _mostrarSnackCompraRealizada(_SolicitudCompraRow row) {
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					"Compra realizada registrada: ${row.numeroOrden} · ${row.producto}.",
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

	Future<void> _onPasoAviso(_SolicitudCompraRow row) async {
		final oid = row.maintenanceOrderId;
		final ws = row.workflowStatusDb;
		if (oid != null && ws != null) {
			try {
				final repo = ref.read(comprasStockRepositoryProvider);
				if (ws == "panol_requested_compras") {
					await repo.comprasNotifyOcEmitted(oid);
					if (mounted) _mostrarSnackOrdenEmitida(row);
				} else if (ws == "compras_oc_notified") {
					await repo.comprasNotifyPurchaseDone(oid);
					if (mounted) _mostrarSnackCompraRealizada(row);
				} else if (ws == "compras_purchase_done") {
					await repo.comprasNotifyMaterialArrived(oid);
					if (mounted) _mostrarSnackLlegadaPlanta(row);
				}
				ref.invalidate(comprasPanolStockRequestsProvider);
				ref.invalidate(comprasInAppNotificationsProvider);
				ref.invalidate(mantenimientoNotificacionesProvider);
				ref.invalidate(panolForwardedOrdersProvider);
				ref.invalidate(supervisorMaintenanceHistoryProvider);
				ref.invalidate(misPedidosMantenimientoProvider);
				if (mounted) setState(() {});
			} catch (e) {
				if (!mounted) return;
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text("No se pudo registrar el aviso: $e")),
				);
			}
			return;
		}
		final key = row.numeroOrden;
		final actual = _estadoAviso(row);
		if (actual == _EstadoAvisoPedido.pendiente) {
			setState(() {
				_estadoAvisoPorOrden[key] = _EstadoAvisoPedido.ocEmitida;
			});
			_mostrarSnackOrdenEmitida(row);
			return;
		}
		if (actual == _EstadoAvisoPedido.ocEmitida) {
			setState(() {
				_estadoAvisoPorOrden[key] = _EstadoAvisoPedido.compraRealizada;
			});
			_mostrarSnackCompraRealizada(row);
			return;
		}
		if (actual == _EstadoAvisoPedido.compraRealizada) {
			setState(() {
				_estadoAvisoPorOrden[key] = _EstadoAvisoPedido.enPlanta;
			});
			_mostrarSnackLlegadaPlanta(row);
		}
	}

	String _estadoAvisoDetalleText(_SolicitudCompraRow row) {
		switch (_estadoAviso(row)) {
			case _EstadoAvisoPedido.pendiente:
				return "Pendiente: emitir aviso de OC / pre-aprobación.";
			case _EstadoAvisoPedido.ocEmitida:
				return "OC emitida. Pendiente registrar compra realizada.";
			case _EstadoAvisoPedido.compraRealizada:
				return "Compra realizada. Pendiente aviso de llegada a planta (Compras o Pañol).";
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

	void _mostrarDetallePedidoSheet(_SolicitudCompraRow row) {
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
				return StatefulBuilder(
					builder: (ctx, setModal) {
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
										row.numeroOrden,
										style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
									),
									const SizedBox(height: 8),
									Text(
										"Solicitud y seguimiento de avisos",
										style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
									),
									const SizedBox(height: 12),
									ConstrainedBox(
										constraints: BoxConstraints(maxHeight: maxH),
										child: SingleChildScrollView(
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													_rowFechaMovil(
														Icons.edit_calendar_outlined,
														"Fecha solicitud",
														_fmtFecha(row.fecha),
													),
													const SizedBox(height: 8),
													_rowFechaMovil(
														Icons.inventory_outlined,
														"Cantidad",
														"${row.cantidad} ${row.unidadMedida}",
													),
													const SizedBox(height: 8),
													_rowFechaMovil(
														Icons.corporate_fare_outlined,
														"Sector",
														row.sectorSolicitante,
													),
													const SizedBox(height: 8),
													_rowFechaMovil(
														Icons.person_outline,
														"Solicitante",
														row.solicitante,
													),
													const SizedBox(height: 8),
													_rowFechaMovil(
														Icons.flag_outlined,
														"Prioridad",
														_prioridadLabel(row.prioridad),
													),
													const SizedBox(height: 8),
													_rowFechaMovil(
														Icons.notifications_active_outlined,
														"Estado avisos",
														_estadoAvisoDetalleText(row),
													),
													if (row.codigoInterno != null &&
															row.codigoInterno!.trim().isNotEmpty) ...[
														const SizedBox(height: 8),
														_rowFechaMovil(
															Icons.tag_outlined,
															"Código interno",
															row.codigoInterno!.trim(),
														),
													],
													if (row.observaciones != null &&
															row.observaciones!.trim().isNotEmpty) ...[
														const SizedBox(height: 8),
														_rowFechaMovil(
															Icons.notes_outlined,
															"Observaciones",
															row.observaciones!.trim(),
														),
													],
												],
											),
										),
									),
									const SizedBox(height: 16),
									Wrap(
										spacing: 8,
										runSpacing: 8,
										children: [
											OutlinedButton.icon(
												onPressed: () {
													Navigator.pop(ctx);
													WidgetsBinding.instance.addPostFrameCallback((_) {
														if (mounted) _ver(row);
													});
												},
												icon: const Icon(Icons.visibility_outlined, size: 20),
												label: const Text("Ver todo"),
												style: OutlinedButton.styleFrom(
													foregroundColor: Colors.black87,
													side: const BorderSide(color: Colors.black54),
													padding: const EdgeInsets.symmetric(
														horizontal: 12,
														vertical: 12,
													),
												),
											),
											_widgetBotonAviso(
												row,
												compact: false,
												onAfter: () => setModal(() {}),
											),
										],
									),
								],
							),
						);
					},
				);
			},
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

	Widget _widgetBotonAviso(
		_SolicitudCompraRow row, {
		required bool compact,
		VoidCallback? onAfter,
	}) {
		final estado = _estadoAviso(row);
		switch (estado) {
			case _EstadoAvisoPedido.pendiente:
				return FilledButton.icon(
					onPressed: () async {
						await _onPasoAviso(row);
						onAfter?.call();
					},
					icon: const Icon(Icons.campaign, size: 22, color: Colors.black87),
					label: const Text("OC emitida"),
					style: compact
							? _styleAvisoTabla(AppTokens.yellowHeader, Colors.black87)
							: _styleAvisoCard(AppTokens.yellowHeader, Colors.black87),
				);
			case _EstadoAvisoPedido.ocEmitida:
				return FilledButton.icon(
					onPressed: () async {
						await _onPasoAviso(row);
						onAfter?.call();
					},
					icon: const Icon(Icons.shopping_cart_checkout, size: 22, color: Colors.black87),
					label: const Text("Compra realizada"),
					style: compact
							? _styleAvisoTabla(AppTokens.yellowHeader, Colors.black87)
							: _styleAvisoCard(AppTokens.yellowHeader, Colors.black87),
				);
			case _EstadoAvisoPedido.compraRealizada:
				return FilledButton.icon(
					onPressed: () async {
						await _onPasoAviso(row);
						onAfter?.call();
					},
					icon: const Icon(Icons.inventory_2, size: 22, color: Colors.white),
					label: const Text("En planta"),
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
			child: InkWell(
				onTap: () => _mostrarDetallePedidoSheet(row),
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
								Icons.receipt_long_outlined,
								"N° orden",
								row.numeroOrden,
							),
							const SizedBox(height: 8),
							_rowFechaMovil(
								Icons.edit_calendar_outlined,
								"Fecha solicitud",
								_fmtFecha(row.fecha),
							),
							const SizedBox(height: 8),
							_rowFechaMovil(
								Icons.inventory_outlined,
								"Cantidad",
								"${row.cantidad} ${row.unidadMedida}",
							),
							const SizedBox(height: 8),
							_rowFechaMovil(
								Icons.corporate_fare_outlined,
								"Sector",
								row.sectorSolicitante,
							),
							const SizedBox(height: 8),
							_rowFechaMovil(
								Icons.flag_outlined,
								"Prioridad",
								_prioridadLabel(row.prioridad),
							),
						],
					),
				),
			),
		);
	}

	Widget _tablaPedidosDesktop(
		List<_SolicitudCompraRow> paginaItems,
		double minTableWidth,
	) {
		const reservaSinProducto = 640.0;
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
								columns: const [
									DataColumn(label: Text("FECHA")),
									DataColumn(label: Text("PRODUCTO")),
									DataColumn(label: Text("N° ORDEN")),
									DataColumn(label: Text("CANTIDAD"), numeric: true),
									DataColumn(label: Text("PRIORIDAD")),
									DataColumn(
										label: Tooltip(
											message: "Detalle y avisos",
											child: Padding(
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
															Text(_fmtFecha(row.fecha)),
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
												DataCell(
													Text(
														row.numeroOrden,
														style: const TextStyle(
															fontWeight: FontWeight.w600,
														),
													),
												),
												DataCell(Text("${row.cantidad} ${row.unidadMedida}")),
												DataCell(_prioridadBadge(row.prioridad)),
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
																tooltip: "Detalle y avisos",
																onPressed: () =>
																		_mostrarDetallePedidoSheet(row),
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

	@override
	Widget build(BuildContext context) {
		return ref.watch(comprasPanolStockRequestsProvider).when(
			data: (rows) {
				final todos = rows
						.map((r) => _SolicitudCompraRow.fromPanolRequest(r))
						.toList();
				return _scaffoldHistorial(context, todos);
			},
			loading: () => Scaffold(
				backgroundColor: AppTokens.surfacePage,
				body: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						StockScreenHeader(
							title: "HISTORIAL DE PEDIDOS",
							onBack: _popHistorial,
							onRefresh: () => ScreenRefresh.compras(ref),
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
							title: "HISTORIAL DE PEDIDOS",
							onBack: _popHistorial,
							onRefresh: () => ScreenRefresh.compras(ref),
						),
						Expanded(
							child: Center(
								child: Padding(
									padding: const EdgeInsets.all(24),
									child: Text(
										"No se pudo cargar el historial.\n$e",
										textAlign: TextAlign.center,
										style: TextStyle(color: Colors.grey.shade800),
									),
								),
							),
						),
					],
				),
			),
		);
	}

	Widget _scaffoldHistorial(BuildContext context, List<_SolicitudCompraRow> todos) {
		final filtrados = _filtrar(todos);
		final totalPaginas = filtrados.isEmpty
				? 1
				: (filtrados.length / _itemsPorPagina).ceil().clamp(1, 999);
		final paginaSegura =
				totalPaginas <= 1 ? 0 : _paginaActual.clamp(0, totalPaginas - 1);
		final inicio = paginaSegura * _itemsPorPagina;
		final paginaItems = filtrados.skip(inicio).take(_itemsPorPagina).toList();
		final emptyMsg = todos.isEmpty
				? "Todavía no hay solicitudes desde pañol."
				: "No hay pedidos con la búsqueda o filtros actuales.";

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "HISTORIAL DE PEDIDOS",
						onBack: _popHistorial,
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
								final filtro = OutlinedButton.icon(
									onPressed: _mostrarFiltroPrioridad,
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
											emptyMsg,
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
