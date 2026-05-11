import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/theme/app_tokens.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "../application/maintenance_history_provider.dart";
import "../domain/completed_maintenance_record.dart";

/// Historial de pedidos de mantenimiento cerrados (p. ej. por retiro), con filtros.
class SupervisorMaintenanceHistoryScreen extends ConsumerStatefulWidget {
	const SupervisorMaintenanceHistoryScreen({super.key});

	static final DateFormat _fechaFmt = DateFormat("dd/MM/yyyy HH:mm");
	static final DateFormat _soloFecha = DateFormat("dd/MM/yyyy");

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

	@override
	Widget build(BuildContext context) {
		final registros = ref.watch(maintenanceHistoryProvider);
		final filtrados = _filtrar(registros);

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
					Expanded(
						child: Align(
							alignment: Alignment.topCenter,
							child: ConstrainedBox(
								constraints: const BoxConstraints(maxWidth: 960),
								child: Padding(
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
																	: "Desde: ${SupervisorMaintenanceHistoryScreen._soloFecha.format(_desde!)}",
														),
													),
													OutlinedButton.icon(
														onPressed: _elegirHasta,
														icon: const Icon(Icons.event_outlined, size: 18),
														label: Text(
															_hasta == null
																	? "Fecha hasta"
																	: "Hasta: ${SupervisorMaintenanceHistoryScreen._soloFecha.format(_hasta!)}",
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
												filtrados.isEmpty && registros.isEmpty
														? "Sin registros en historial."
														: "Mostrando ${filtrados.length} de ${registros.length}",
												style: TextStyle(
													fontSize: 13,
													color: Colors.grey.shade700,
												),
											),
											const SizedBox(height: 10),
											Expanded(
												child: filtrados.isEmpty
														? Center(
																child: Text(
																	registros.isEmpty
																			? "Cuando completes un pedido por retiro de stock,\naparecerá aquí."
																			: "No hay resultados con estos filtros.",
																	textAlign: TextAlign.center,
																	style: TextStyle(
																		fontSize: 15,
																		color: Colors.grey.shade600,
																		height: 1.35,
																	),
																),
															)
														: ListView.separated(
																itemCount: filtrados.length,
																separatorBuilder: (_, __) =>
																		const SizedBox(height: 10),
																itemBuilder: (context, index) {
																	final r = filtrados[index];
																	final o = r.pedido;
																	return Material(
																		color: AppTokens.whiteSurface,
																		borderRadius: BorderRadius.circular(
																			AppTokens.radiusMd,
																		),
																		elevation: 0,
																		child: Container(
																				padding: const EdgeInsets.all(14),
																				decoration: BoxDecoration(
																					borderRadius: BorderRadius.circular(
																						AppTokens.radiusMd,
																					),
																					border: Border.all(
																						color: AppTokens.greyBorder,
																					),
																				),
																				child: Column(
																					crossAxisAlignment:
																							CrossAxisAlignment.start,
																					children: [
																						Row(
																							crossAxisAlignment:
																									CrossAxisAlignment.start,
																							children: [
																								Expanded(
																									child: Text(
																										o.numeroOrden,
																										style: const TextStyle(
																											fontWeight:
																													FontWeight.bold,
																											fontSize: 16,
																											color: Colors.black87,
																										),
																									),
																								),
																								Container(
																									padding:
																											const EdgeInsets.symmetric(
																										horizontal: 8,
																										vertical: 4,
																									),
																									decoration: BoxDecoration(
																										color: AppTokens.surfaceMuted,
																										borderRadius:
																												BorderRadius.circular(6),
																									),
																									child: Text(
																										r.motivoCierre,
																										style: TextStyle(
																											fontSize: 11,
																											fontWeight:
																													FontWeight.w600,
																											color: Colors.grey.shade800,
																										),
																									),
																								),
																							],
																						),
																						const SizedBox(height: 8),
																						Text(
																							"Cierre: ${SupervisorMaintenanceHistoryScreen._fechaFmt.format(r.fechaCierre)}",
																							style: TextStyle(
																								fontSize: 13,
																								color: Colors.grey.shade700,
																							),
																						),
																						const SizedBox(height: 4),
																						Text(
																							"Pedido: ${SupervisorMaintenanceHistoryScreen._fechaFmt.format(o.fechaPedido)}",
																							style: TextStyle(
																								fontSize: 12,
																								color: Colors.grey.shade600,
																							),
																						),
																						const SizedBox(height: 10),
																						Text(
																							o.solicitante,
																							style: const TextStyle(
																								fontSize: 14,
																								fontWeight: FontWeight.w600,
																								color: Colors.black87,
																							),
																						),
																						const SizedBox(height: 4),
																						Text(
																							o.producto,
																							style: const TextStyle(
																								fontSize: 13,
																								color: Colors.black87,
																							),
																						),
																					],
																				),
																			),
																	);
																},
															),
											),
										],
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
