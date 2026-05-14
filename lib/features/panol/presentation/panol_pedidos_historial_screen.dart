import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/format/argentina_datetime.dart";
import "../../../core/theme/app_tokens.dart";
import "../../orders/presentation/widgets/maintenance_order_seguimiento_sheet.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "../../supervisor/domain/completed_maintenance_record.dart";
import "../../supervisor/domain/maintenance_order.dart";
import "../application/panol_order_history_provider.dart";

/// Historial de pedidos gestionados por pañol (entregados / cancelados).
class PanolPedidosHistorialScreen extends ConsumerStatefulWidget {
	const PanolPedidosHistorialScreen({super.key});

	static String _formatFechaHora(DateTime d) => ArgentinaDateTime.formatDateTime(d);

	@override
	ConsumerState<PanolPedidosHistorialScreen> createState() =>
			_PanolPedidosHistorialScreenState();
}

class _PanolPedidosHistorialScreenState extends ConsumerState<PanolPedidosHistorialScreen> {
	final _numeroCtrl = TextEditingController();
	final _nombreCtrl = TextEditingController();

	@override
	void dispose() {
		_numeroCtrl.dispose();
		_nombreCtrl.dispose();
		super.dispose();
	}

	void _back(BuildContext context) {
		if (context.canPop()) {
			context.pop();
		} else {
			context.go("/panol/pedidos");
		}
	}

	List<CompletedMaintenanceRecord> _filtrar(List<CompletedMaintenanceRecord> todos) {
		final qNum = _numeroCtrl.text.trim().toLowerCase();
		final qNom = _nombreCtrl.text.trim().toLowerCase();

		return todos.where((r) {
			final o = r.pedido;
			if (qNum.isNotEmpty && !o.numeroOrden.toLowerCase().contains(qNum)) {
				return false;
			}
			if (qNom.isNotEmpty) {
				final ok = o.solicitante.toLowerCase().contains(qNom) ||
						o.producto.toLowerCase().contains(qNom);
				if (!ok) return false;
			}
			return true;
		}).toList()
			..sort((a, b) => b.fechaCierre.compareTo(a.fechaCierre));
	}

	@override
	Widget build(BuildContext context) {
		final asyncHistorial = ref.watch(panolOrderHistoryProvider);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "HISTORIAL PEDIDOS",
						onBack: () => _back(context),
					),
					Padding(
						padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
						child: Row(
							children: [
								Expanded(
									child: TextField(
										controller: _numeroCtrl,
										decoration: const InputDecoration(
											labelText: "N° pedido",
											border: OutlineInputBorder(),
											isDense: true,
										),
										onChanged: (_) => setState(() {}),
									),
								),
								const SizedBox(width: 10),
								Expanded(
									flex: 2,
									child: TextField(
										controller: _nombreCtrl,
										decoration: const InputDecoration(
											labelText: "Producto o solicitante",
											border: OutlineInputBorder(),
											isDense: true,
										),
										onChanged: (_) => setState(() {}),
									),
								),
							],
						),
					),
					Expanded(
						child: asyncHistorial.when(
							loading: () => const Center(child: CircularProgressIndicator()),
							error: (e, _) => Center(
								child: Padding(
									padding: const EdgeInsets.all(24),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											Text("No se pudo cargar el historial.\n$e", textAlign: TextAlign.center),
											const SizedBox(height: 12),
											FilledButton(
												onPressed: () => ref.invalidate(panolOrderHistoryProvider),
												child: const Text("Reintentar"),
											),
										],
									),
								),
							),
							data: (todos) {
								final filtrados = _filtrar(todos);
								if (filtrados.isEmpty) {
									return Center(
										child: Text(
											"No hay pedidos en el historial.",
											style: TextStyle(color: Colors.grey.shade700),
										),
									);
								}
								return RefreshIndicator(
									onRefresh: () async {
										ref.invalidate(panolOrderHistoryProvider);
										await ref.read(panolOrderHistoryProvider.future);
									},
									child: ListView.separated(
										padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
										itemCount: filtrados.length,
										separatorBuilder: (_, __) => const SizedBox(height: 10),
										itemBuilder: (context, i) {
											final r = filtrados[i];
											return _PanolHistorialCard(record: r);
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

class _PanolHistorialCard extends StatelessWidget {
	const _PanolHistorialCard({required this.record});

	final CompletedMaintenanceRecord record;

	@override
	Widget build(BuildContext context) {
		final o = record.pedido;
		final entregado = o.workflowStatus == MaintenanceWorkflowStatus.completed;
		final bg = entregado ? const Color(0xFFE8F5E9) : Colors.grey.shade100;
		final borde = entregado ? const Color(0xFF2E7D32) : Colors.grey.shade600;

		return Material(
			color: bg,
			borderRadius: BorderRadius.circular(AppTokens.radiusMd),
			child: InkWell(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				onTap: () => showMaintenanceOrderSeguimientoSheet(context, o),
				child: Container(
					padding: const EdgeInsets.all(14),
					decoration: BoxDecoration(
						borderRadius: BorderRadius.circular(AppTokens.radiusMd),
						border: Border.all(color: borde, width: 1.2),
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								children: [
									Expanded(
										child: Text(
											o.numeroOrden,
											style: TextStyle(
												fontWeight: FontWeight.bold,
												fontSize: 15,
												color: entregado
														? const Color(0xFF1B5E20)
														: Colors.black87,
											),
										),
									),
									Container(
										padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
										decoration: BoxDecoration(
											color: entregado
													? const Color(0xFF2E7D32)
													: Colors.grey.shade700,
											borderRadius: BorderRadius.circular(6),
										),
										child: Text(
											record.motivoCierre.toUpperCase(),
											style: const TextStyle(
												fontSize: 10,
												fontWeight: FontWeight.w800,
												color: Colors.white,
											),
										),
									),
								],
							),
							const SizedBox(height: 8),
							Text(
								"${PanolPedidosHistorialScreen._formatFechaHora(record.fechaCierre)} · ${o.producto}",
								style: TextStyle(
									fontSize: 13,
									color: Colors.grey.shade800,
									height: 1.35,
								),
							),
							const SizedBox(height: 4),
							Text(
								o.solicitante,
								style: TextStyle(
									fontSize: 12,
									color: Colors.grey.shade700,
									fontWeight: FontWeight.w600,
								),
							),
						],
					),
				),
			),
		);
	}
}
