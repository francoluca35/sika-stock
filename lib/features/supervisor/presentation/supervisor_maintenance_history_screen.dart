import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/format/argentina_datetime.dart";
import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../orders/presentation/widgets/maintenance_order_seguimiento_sheet.dart";
import "../../orders/presentation/widgets/retiro_producto_detail_sheet.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "../application/supervisor_maintenance_history_provider.dart";
import "../domain/completed_maintenance_record.dart";
import "../domain/maintenance_order.dart";

/// Historial de pedidos de mantenimiento (Supabase): entregados en verde, consulta pañol en naranja.
class SupervisorMaintenanceHistoryScreen extends ConsumerStatefulWidget {
	const SupervisorMaintenanceHistoryScreen({super.key});

	static String _formatFechaHora(DateTime d) => ArgentinaDateTime.formatDateTime(d);
	static String _formatSoloFecha(DateTime d) => ArgentinaDateTime.formatDateOnly(d);

	@override
	ConsumerState<SupervisorMaintenanceHistoryScreen> createState() =>
			_SupervisorMaintenanceHistoryScreenState();
}

class _SupervisorMaintenanceHistoryScreenState
		extends ConsumerState<SupervisorMaintenanceHistoryScreen> {
	final _numeroCtrl = TextEditingController();
	final _nombreCtrl = TextEditingController();
	DateTime? _desde;
	DateTime? _hasta;

	@override
	void dispose() {
		_numeroCtrl.dispose();
		_nombreCtrl.dispose();
		super.dispose();
	}

	void _limpiarFiltros() {
		setState(() {
			_numeroCtrl.clear();
			_nombreCtrl.clear();
			_desde = null;
			_hasta = null;
		});
	}

	List<CompletedMaintenanceRecord> _filtrar(List<CompletedMaintenanceRecord> todos) {
		final qNum = _numeroCtrl.text.trim().toLowerCase();
		final qNom = _nombreCtrl.text.trim().toLowerCase();

		final filtrados = todos.where((r) {
			final o = r.pedido;
			if (qNum.isNotEmpty &&
					!o.numeroOrden.toLowerCase().contains(qNum)) {
				return false;
			}
			if (qNom.isNotEmpty) {
				final porSolicitante =
						o.solicitante.toLowerCase().contains(qNom);
				final porProducto = o.producto.toLowerCase().contains(qNom);
				if (!porSolicitante && !porProducto) return false;
			}
			final fc = r.fechaCierre;
			if (_desde != null) {
				final inicio = DateTime(_desde!.year, _desde!.month, _desde!.day);
				if (fc.isBefore(inicio)) return false;
			}
			if (_hasta != null) {
				final fin = DateTime(
					_hasta!.year,
					_hasta!.month,
					_hasta!.day,
					23,
					59,
					59,
				);
				if (fc.isAfter(fin)) return false;
			}
			return true;
		}).toList();

		filtrados.sort((a, b) => b.fechaCierre.compareTo(a.fechaCierre));
		return filtrados;
	}

	Future<void> _elegirDesde() async {
		final now = DateTime.now();
		final d = await showDatePicker(
			context: context,
			initialDate: _desde ?? now,
			firstDate: DateTime(2020),
			lastDate: DateTime(now.year + 2),
		);
		if (d != null && mounted) setState(() => _desde = d);
	}

	Future<void> _elegirHasta() async {
		final now = DateTime.now();
		final d = await showDatePicker(
			context: context,
			initialDate: _hasta ?? now,
			firstDate: DateTime(2020),
			lastDate: DateTime(now.year + 2),
		);
		if (d != null && mounted) setState(() => _hasta = d);
	}

	Future<void> _refrescarHistorial() async {
		ref.invalidate(supervisorMaintenanceHistoryProvider);
		await ref.read(supervisorMaintenanceHistoryProvider.future);
	}

	@override
	Widget build(BuildContext context) {
		final asyncHistorial = ref.watch(supervisorMaintenanceHistoryProvider);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "HISTORIAL MANTENIMIENTO",
						onBack: () {
							if (context.canPop()) {
								context.pop();
							} else {
								context.go("/home");
							}
						},
						onRefresh: () => ScreenRefresh.historialMantenimiento(ref),
					),
					Expanded(
						child: Align(
							alignment: Alignment.topCenter,
							child: ConstrainedBox(
								constraints: const BoxConstraints(maxWidth: 960),
								child: asyncHistorial.when(
									data: (registros) {
										final filtrados = _filtrar(registros);
										return Padding(
											padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.stretch,
												children: [
													Text(
														"Filtrar",
														style: TextStyle(
															fontWeight: FontWeight.bold,
															fontSize: 14,
															color: Colors.grey.shade800,
														),
													),
													const SizedBox(height: 10),
													TextField(
														controller: _numeroCtrl,
														onChanged: (_) => setState(() {}),
														decoration: InputDecoration(
															isDense: true,
															labelText: "N° de orden",
															hintText: "Ej. ORD-0001",
															filled: true,
															fillColor: AppTokens.whiteSurface,
															border: OutlineInputBorder(
																borderRadius: BorderRadius.circular(
																	AppTokens.radiusMd,
																),
																borderSide: const BorderSide(
																	color: AppTokens.greyBorder,
																),
															),
															enabledBorder: OutlineInputBorder(
																borderRadius: BorderRadius.circular(
																	AppTokens.radiusMd,
																),
																borderSide: const BorderSide(
																	color: AppTokens.greyBorder,
																),
															),
														),
													),
													const SizedBox(height: 10),
													TextField(
														controller: _nombreCtrl,
														onChanged: (_) => setState(() {}),
														decoration: InputDecoration(
															isDense: true,
															labelText: "Nombre / producto",
															hintText: "Solicitante o producto…",
															filled: true,
															fillColor: AppTokens.whiteSurface,
															border: OutlineInputBorder(
																borderRadius: BorderRadius.circular(
																	AppTokens.radiusMd,
																),
																borderSide: const BorderSide(
																	color: AppTokens.greyBorder,
																),
															),
															enabledBorder: OutlineInputBorder(
																borderRadius: BorderRadius.circular(
																	AppTokens.radiusMd,
																),
																borderSide: const BorderSide(
																	color: AppTokens.greyBorder,
																),
															),
														),
													),
													const SizedBox(height: 12),
													Wrap(
														spacing: 10,
														runSpacing: 10,
														crossAxisAlignment: WrapCrossAlignment.center,
														children: [
															OutlinedButton.icon(
																onPressed: _elegirDesde,
																icon: const Icon(Icons.calendar_today_outlined, size: 18),
																label: Text(
																	_desde == null
																			? "Fecha desde"
																			: "Desde: ${SupervisorMaintenanceHistoryScreen._formatSoloFecha(_desde!)}",
																),
															),
															OutlinedButton.icon(
																onPressed: _elegirHasta,
																icon: const Icon(Icons.event_outlined, size: 18),
																label: Text(
																	_hasta == null
																			? "Fecha hasta"
																			: "Hasta: ${SupervisorMaintenanceHistoryScreen._formatSoloFecha(_hasta!)}",
																),
															),
															TextButton(
																onPressed: _limpiarFiltros,
																child: const Text("Limpiar filtros"),
															),
														],
													),
													const SizedBox(height: 14),
													Text(
														registros.isEmpty
																? "Sin registros en historial."
																: "Mostrando ${filtrados.length} de ${registros.length}",
														style: TextStyle(
															fontSize: 13,
															color: Colors.grey.shade700,
														),
													),
													const SizedBox(height: 10),
													Expanded(
														child: RefreshIndicator(
															onRefresh: _refrescarHistorial,
															child: filtrados.isEmpty
																	? ListView(
																			physics: const AlwaysScrollableScrollPhysics(),
																			children: [
																				SizedBox(
																					height: MediaQuery.sizeOf(context).height * 0.25,
																					child: Center(
																						child: Text(
																							registros.isEmpty
																									? "Aún no hay pedidos entregados ni enviados a pañol.\nCuando un pedido se complete o pase a consulta con pañol,\naparecerá aquí."
																									: "No hay resultados con estos filtros.",
																							textAlign: TextAlign.center,
																							style: TextStyle(
																								fontSize: 15,
																								color: Colors.grey.shade600,
																								height: 1.35,
																							),
																						),
																					),
																				),
																			],
																		)
																	: ListView.separated(
																			physics: const AlwaysScrollableScrollPhysics(),
																			itemCount: filtrados.length,
																			separatorBuilder: (_, __) =>
																					const SizedBox(height: 10),
																			itemBuilder: (context, index) {
																				return _HistorialPedidoCard(
																					record: filtrados[index],
																				);
																			},
																		),
														),
													),
												],
											),
										);
									},
									loading: () => const Center(child: CircularProgressIndicator()),
									error: (e, _) => Center(
										child: Padding(
											padding: AppTokens.padScreen,
											child: Column(
												mainAxisAlignment: MainAxisAlignment.center,
												children: [
													Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
													const SizedBox(height: 12),
													Text(
														"No se pudo cargar el historial",
														style: Theme.of(context).textTheme.titleMedium,
														textAlign: TextAlign.center,
													),
													const SizedBox(height: 8),
													Text(
														"$e",
														textAlign: TextAlign.center,
														style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
													),
													const SizedBox(height: 16),
													FilledButton(
														onPressed: _refrescarHistorial,
														child: const Text("Reintentar"),
													),
												],
											),
										),
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

class _HistorialPedidoCard extends StatelessWidget {
	const _HistorialPedidoCard({required this.record});

	final CompletedMaintenanceRecord record;

	static const Color _verdeFondo = Color(0xFFE8F5E9);
	static const Color _verdeBorde = Color(0xFF2E7D32);
	static const Color _verdeTexto = Color(0xFF1B5E20);

	static String _leyendaFlujo(MaintenanceWorkflowStatus ws, String fechaFmt) {
		switch (ws) {
			case MaintenanceWorkflowStatus.forwardedToPanol:
				return "En consulta con pañol: $fechaFmt";
			case MaintenanceWorkflowStatus.panolRequestedCompras:
			case MaintenanceWorkflowStatus.comprasOcNotified:
			case MaintenanceWorkflowStatus.comprasPurchaseDone:
				return "Pedido a compras: $fechaFmt";
			case MaintenanceWorkflowStatus.comprasArrivedNotified:
				return "Listo para retirar: $fechaFmt";
			default:
				return "Última actualización: $fechaFmt";
		}
	}

	@override
	Widget build(BuildContext context) {
		final o = record.pedido;
		final ws = o.workflowStatus;

		final bool esEntregado = ws == MaintenanceWorkflowStatus.completed;
		final bool esFlujoConsultaCompras = switch (ws) {
			MaintenanceWorkflowStatus.forwardedToPanol ||
			MaintenanceWorkflowStatus.panolRequestedCompras ||
			MaintenanceWorkflowStatus.comprasOcNotified ||
			MaintenanceWorkflowStatus.comprasPurchaseDone ||
			MaintenanceWorkflowStatus.comprasArrivedNotified =>
				true,
			_ => false,
		};

		final Color fondo;
		final Color borde;
		final Color tituloColor;
		final Color secundario;

		if (esEntregado) {
			fondo = _verdeFondo;
			borde = _verdeBorde;
			tituloColor = _verdeTexto;
			secundario = _verdeTexto.withValues(alpha: 0.85);
		} else if (esFlujoConsultaCompras) {
			fondo = Colors.orange.shade50;
			borde = Colors.orange.shade800;
			tituloColor = Colors.orange.shade900;
			secundario = Colors.orange.shade900.withValues(alpha: 0.88);
		} else {
			fondo = Colors.grey.shade100;
			borde = Colors.grey.shade600;
			tituloColor = Colors.black87;
			secundario = Colors.grey.shade800;
		}

		final fechaFmt = SupervisorMaintenanceHistoryScreen._formatFechaHora(record.fechaCierre);
		final fechaLinea = esEntregado
				? "Entregado: $fechaFmt"
				: esFlujoConsultaCompras
						? _HistorialPedidoCard._leyendaFlujo(ws, fechaFmt)
						: "Última actualización: $fechaFmt";

		return Material(
			color: fondo,
			borderRadius: BorderRadius.circular(AppTokens.radiusMd),
			elevation: 0,
			child: InkWell(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				onTap: () => showMaintenanceOrderSeguimientoSheet(context, o),
				child: Container(
					padding: const EdgeInsets.all(14),
					decoration: BoxDecoration(
						borderRadius: BorderRadius.circular(AppTokens.radiusMd),
						border: Border.all(color: borde, width: 1.4),
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Expanded(
										child: Text(
											o.numeroOrden,
											style: TextStyle(
												fontWeight: FontWeight.bold,
												fontSize: 16,
												color: tituloColor,
											),
										),
									),
									Container(
										padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
										decoration: BoxDecoration(
											color: esEntregado
													? _verdeBorde
													: esFlujoConsultaCompras
															? Colors.orange.shade800
															: Colors.grey.shade700,
											borderRadius: BorderRadius.circular(6),
										),
										child: Text(
											record.motivoCierre.toUpperCase(),
											style: const TextStyle(
												fontSize: 10.5,
												fontWeight: FontWeight.w800,
												letterSpacing: 0.3,
												color: Colors.white,
											),
										),
									),
									if (esEntregado) ...[
										const SizedBox(width: 8),
										OutlinedButton.icon(
											onPressed: () => showRetiroProductoDetailSheet(context, o),
											style: OutlinedButton.styleFrom(
												foregroundColor: _verdeTexto,
												side: const BorderSide(color: _verdeBorde, width: 1.4),
												padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
												minimumSize: Size.zero,
												tapTargetSize: MaterialTapTargetSize.shrinkWrap,
											),
											icon: Icon(Icons.inventory_2_outlined, size: 18, color: _verdeTexto),
											label: Text(
												"VER PRODUCTO",
												style: TextStyle(
													fontWeight: FontWeight.w800,
													fontSize: 11,
													color: _verdeTexto,
												),
											),
										),
									],
									if (esFlujoConsultaCompras) ...[
										const SizedBox(width: 8),
										OutlinedButton.icon(
											onPressed: () => showMaintenanceOrderSeguimientoSheet(context, o),
											style: OutlinedButton.styleFrom(
												foregroundColor: Colors.orange.shade900,
												side: BorderSide(color: Colors.orange.shade800, width: 1.4),
												padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
												minimumSize: Size.zero,
												tapTargetSize: MaterialTapTargetSize.shrinkWrap,
											),
											icon: Icon(Icons.track_changes_outlined, size: 18, color: Colors.orange.shade900),
											label: Text(
												"SEGUIMIENTO",
												style: TextStyle(
													fontWeight: FontWeight.w800,
													fontSize: 11,
													color: Colors.orange.shade900,
												),
											),
										),
									],
								],
							),
							const SizedBox(height: 8),
							Text(
								fechaLinea,
								style: TextStyle(
									fontSize: 13,
									color: secundario,
									fontWeight: FontWeight.w600,
								),
							),
							const SizedBox(height: 4),
							Text(
								"Pedido: ${SupervisorMaintenanceHistoryScreen._formatFechaHora(o.fechaPedido)}",
								style: TextStyle(
									fontSize: 12,
									color: secundario.withValues(alpha: 0.9),
								),
							),
							const SizedBox(height: 10),
							Text(
								o.solicitante,
								style: TextStyle(
									fontSize: 14,
									fontWeight: FontWeight.w600,
									color: tituloColor,
								),
							),
							const SizedBox(height: 4),
							Text(
								o.producto,
								style: TextStyle(
									fontSize: 13,
									color: tituloColor,
								),
							),
						],
					),
				),
			),
		);
	}
}
