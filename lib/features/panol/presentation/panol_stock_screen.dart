import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/domain/stock_product.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";

/// Pantalla **Stock** Pañol: acciones + tabla (navegación desde la home).
class PanolStockScreen extends ConsumerWidget {
	const PanolStockScreen({super.key});

	void _soon(BuildContext context, String msg) {
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text("$msg — próximamente.")),
		);
	}

	String _codigoStock(StockProduct p) {
		if (p.codigo != null && p.codigo!.trim().isNotEmpty) {
			return p.codigo!.trim();
		}
		final n = int.tryParse(p.id) ?? 0;
		return "STK-${n.toString().padLeft(3, "0")}";
	}

	bool _bajoStock(StockProduct p) => p.cantidad == 0 || p.cantidad < 15;

	void _back(BuildContext context) {
		if (context.canPop()) {
			context.pop();
		} else {
			context.go("/home");
		}
	}

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final productos = ref.watch(supervisorStockCatalogProvider);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "STOCK",
						onBack: () => _back(context),
					),
					Padding(
						padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
						child: Align(
							alignment: Alignment.centerRight,
							child: TextButton.icon(
								onPressed: () => context.push("/panol/stock-opciones"),
								icon: const Icon(Icons.tune, size: 20, color: Colors.black87),
								label: const Text(
									"Opciones (categorías, alertas…)",
									style: TextStyle(
										fontWeight: FontWeight.w600,
										color: Colors.black87,
									),
								),
							),
						),
					),
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
							child: Center(
								child: ConstrainedBox(
									constraints: const BoxConstraints(maxWidth: 960),
									child: Material(
										color: AppTokens.whiteSurface,
										borderRadius: BorderRadius.circular(AppTokens.radiusLg),
										clipBehavior: Clip.antiAlias,
										elevation: 1,
										shadowColor: Colors.black12,
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.stretch,
											mainAxisSize: MainAxisSize.min,
											children: [
												Padding(
													padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
													child: Wrap(
														spacing: 8,
														runSpacing: 8,
														alignment: WrapAlignment.start,
														children: [
															_PanolToolbarBtn(
																label: "EDITAR",
																icon: Icons.edit_outlined,
																bg: AppTokens.yellowHeader,
																fg: Colors.black87,
																onPressed: () => _soon(context, "Editar ítem"),
															),
															_PanolToolbarBtn(
																label: "AÑADIR",
																icon: Icons.add,
																bg: AppTokens.yellowHeader,
																fg: Colors.black87,
																onPressed: () => context.push("/stock/agregar"),
															),
															_PanolToolbarBtn(
																label: "ELIMINAR",
																icon: Icons.delete_outline,
																bg: AppTokens.redAction,
																fg: Colors.white,
																onPressed: () => _soon(context, "Eliminar ítem"),
															),
															_PanolToolbarBtn(
																label: "UTILIZAR",
																icon: Icons.build_outlined,
																bg: AppTokens.yellowHeader,
																fg: Colors.black87,
																onPressed: () => _soon(context, "Utilizar material"),
															),
														],
													),
												),
												const Divider(height: 1),
												LayoutBuilder(
													builder: (context, constraints) {
														return SingleChildScrollView(
															scrollDirection: Axis.horizontal,
															child: ConstrainedBox(
																constraints: BoxConstraints(
																	minWidth: constraints.maxWidth,
																),
																child: DataTable(
																	headingRowColor: WidgetStateProperty.all(
																		AppTokens.surfaceMuted,
																	),
																	dataRowMinHeight: 44,
																	horizontalMargin: 12,
																	columnSpacing: 16,
																	columns: const [
																		DataColumn(label: Text("CÓDIGO")),
																		DataColumn(label: Text("NOMBRE")),
																		DataColumn(label: Text("USO")),
																		DataColumn(
																			label: Text("CANTIDAD"),
																			numeric: true,
																		),
																		DataColumn(label: Text("ESTADO")),
																	],
																	rows: [
																		for (final p in productos)
																			DataRow(
																				cells: [
																					DataCell(Text(_codigoStock(p))),
																					DataCell(
																						Text(
																							p.nombre,
																							overflow: TextOverflow.ellipsis,
																						),
																					),
																					DataCell(Text(p.categoria)),
																					DataCell(Text("${p.cantidad}")),
																					DataCell(
																						_EstadoStockChip(bajo: _bajoStock(p)),
																					),
																				],
																			),
																	],
																),
															),
														);
													},
												),
												const SizedBox(height: 8),
											],
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

class _PanolToolbarBtn extends StatelessWidget {
	const _PanolToolbarBtn({
		required this.label,
		required this.icon,
		required this.bg,
		required this.fg,
		required this.onPressed,
	});

	final String label;
	final IconData icon;
	final Color bg;
	final Color fg;
	final VoidCallback onPressed;

	@override
	Widget build(BuildContext context) {
		return FilledButton.icon(
			style: FilledButton.styleFrom(
				backgroundColor: bg,
				foregroundColor: fg,
				padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
				shape: RoundedRectangleBorder(
					borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				),
			),
			onPressed: onPressed,
			icon: Icon(icon, size: 18),
			label: Text(
				label,
				style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
			),
		);
	}
}

class _EstadoStockChip extends StatelessWidget {
	const _EstadoStockChip({required this.bajo});

	final bool bajo;

	@override
	Widget build(BuildContext context) {
		final text = bajo ? "BAJO STOCK" : "OK";
		final bg = bajo ? AppTokens.redAction : AppTokens.statusOk;
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
			decoration: BoxDecoration(
				color: bg,
				borderRadius: BorderRadius.circular(6),
			),
			child: Text(
				text,
				style: const TextStyle(
					color: Colors.white,
					fontSize: 11,
					fontWeight: FontWeight.bold,
				),
			),
		);
	}
}
