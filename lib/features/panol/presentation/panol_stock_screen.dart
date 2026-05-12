import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/domain/stock_product.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";

/// Pantalla **Stock** Pañol: acciones + tabla (navegación desde la home).
class PanolStockScreen extends ConsumerStatefulWidget {
	const PanolStockScreen({super.key});

	@override
	ConsumerState<PanolStockScreen> createState() => _PanolStockScreenState();
}

class _PanolStockScreenState extends ConsumerState<PanolStockScreen> {
	bool _modoEdicion = false;
	bool _modoEliminar = false;
	final Set<String> _idsSeleccionados = <String>{};

	void _setModoEdicion(bool activo) {
		setState(() {
			_modoEdicion = activo;
			if (activo) {
				_modoEliminar = false;
				_idsSeleccionados.clear();
			}
		});
	}

	void _setModoEliminar(bool activo) {
		setState(() {
			_modoEliminar = activo;
			if (activo) {
				_modoEdicion = false;
				_idsSeleccionados.clear();
			} else {
				_idsSeleccionados.clear();
			}
		});
	}

	void _toggleSeleccionFila(String id, bool? seleccionado) {
		setState(() {
			if (seleccionado == true) {
				_idsSeleccionados.add(id);
			} else {
				_idsSeleccionados.remove(id);
			}
		});
	}

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

	Future<void> _confirmarEliminarSeleccion() async {
		if (_idsSeleccionados.isEmpty) return;
		final ids = Set<String>.from(_idsSeleccionados);
		final n = ids.length;
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text("Eliminar productos"),
				content: Text(
					n == 1
							? "¿Eliminar este producto del listado?"
							: "¿Eliminar estos $n productos del listado?",
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text("Cancelar"),
					),
					FilledButton(
						style: FilledButton.styleFrom(backgroundColor: AppTokens.redAction),
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text("Eliminar"),
					),
				],
			),
		);
		if (!mounted || ok != true) return;
		ref.read(supervisorStockCatalogProvider.notifier).removeByIds(ids);
		setState(() {
			_idsSeleccionados.clear();
			_modoEliminar = false;
		});
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text(n == 1 ? "Producto eliminado." : "Se eliminaron $n productos.")),
		);
	}

	Future<void> _abrirModalEdicion(StockProduct producto) async {
		final guardado = await showDialog<StockProduct>(
			context: context,
			barrierDismissible: false,
			builder: (ctx) => _EditarProductoStockDialog(producto: producto),
		);
		if (!mounted || guardado == null) return;
		ref.read(supervisorStockCatalogProvider.notifier).replaceProduct(guardado);
		ScaffoldMessenger.of(context).showSnackBar(
			const SnackBar(content: Text("Cambios guardados.")),
		);
	}

	@override
	Widget build(BuildContext context) {
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
																label: _modoEdicion ? "LISTO" : "EDITAR",
																icon: _modoEdicion ? Icons.check : Icons.edit_outlined,
																bg: _modoEdicion
																		? AppTokens.statusOk
																		: AppTokens.yellowHeader,
																fg: _modoEdicion ? Colors.white : Colors.black87,
																onPressed: () => _setModoEdicion(!_modoEdicion),
															),
															_PanolToolbarBtn(
																label: "AÑADIR",
																icon: Icons.add,
																bg: AppTokens.yellowHeader,
																fg: Colors.black87,
																onPressed: () => context.push("/stock/agregar"),
															),
															_PanolToolbarBtn(
																label: _modoEliminar ? "LISTO" : "ELIMINAR",
																icon: _modoEliminar ? Icons.check : Icons.delete_outline,
																bg: _modoEliminar
																		? AppTokens.statusOk
																		: AppTokens.redAction,
																fg: Colors.white,
																onPressed: () => _setModoEliminar(!_modoEliminar),
															),
															if (_modoEliminar)
																_PanolToolbarBtn(
																	label: _idsSeleccionados.isEmpty
																			? "ELIMINAR SELECCIÓN"
																			: "ELIMINAR (${_idsSeleccionados.length})",
																	icon: Icons.delete_forever_outlined,
																	bg: AppTokens.redAction,
																	fg: Colors.white,
																	onPressed: _idsSeleccionados.isEmpty
																			? null
																			: () {
																					_confirmarEliminarSeleccion();
																				},
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
												if (_modoEdicion)
													Padding(
														padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
														child: DecoratedBox(
															decoration: BoxDecoration(
																color: AppTokens.yellowHeader.withValues(alpha: 0.35),
																borderRadius: BorderRadius.circular(
																	AppTokens.radiusMd,
																),
																border: Border.all(color: Colors.black26),
															),
															child: const Padding(
																padding: EdgeInsets.symmetric(
																	horizontal: 12,
																	vertical: 10,
																),
																child: Row(
																	children: [
																		Icon(Icons.touch_app, size: 22, color: Colors.black87),
																		SizedBox(width: 10),
																		Expanded(
																			child: Text(
																				"Modo edición: tocá una fila del producto que "
																				"quieras modificar.",
																				style: TextStyle(
																					fontSize: 13,
																					height: 1.3,
																					color: Colors.black87,
																					fontWeight: FontWeight.w600,
																				),
																			),
																		),
																	],
																),
															),
														),
													),
												if (_modoEliminar)
													Padding(
														padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
														child: DecoratedBox(
															decoration: BoxDecoration(
																color: AppTokens.redAction.withValues(alpha: 0.12),
																borderRadius: BorderRadius.circular(
																	AppTokens.radiusMd,
																),
																border: Border.all(color: AppTokens.redAction.withValues(alpha: 0.45)),
															),
															child: const Padding(
																padding: EdgeInsets.symmetric(
																	horizontal: 12,
																	vertical: 10,
																),
																child: Row(
																	children: [
																		Icon(Icons.checklist_rtl, size: 22, color: Colors.black87),
																		SizedBox(width: 10),
																		Expanded(
																			child: Text(
																				"Modo eliminar: marcá una o varias filas y "
																				"tocá «ELIMINAR (N)» para borrarlas.",
																				style: TextStyle(
																					fontSize: 13,
																					height: 1.3,
																					color: Colors.black87,
																					fontWeight: FontWeight.w600,
																				),
																			),
																		),
																	],
																),
															),
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
																	showCheckboxColumn: _modoEliminar,
																	headingRowColor: WidgetStateProperty.all(
																		AppTokens.surfaceMuted,
																	),
																	dataRowMinHeight:
																			_modoEdicion || _modoEliminar ? 48 : 44,
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
																				selected: _idsSeleccionados.contains(p.id),
																				onSelectChanged: _modoEliminar
																						? (v) => _toggleSeleccionFila(p.id, v)
																						: null,
																				cells: [
																					DataCell(
																						Text(_codigoStock(p)),
																						onTap: _modoEdicion && !_modoEliminar
																								? () => _abrirModalEdicion(p)
																								: null,
																					),
																					DataCell(
																						Text(
																							p.nombre,
																							overflow: TextOverflow.ellipsis,
																						),
																						onTap: _modoEdicion && !_modoEliminar
																								? () => _abrirModalEdicion(p)
																								: null,
																					),
																					DataCell(
																						Text(p.categoria),
																						onTap: _modoEdicion && !_modoEliminar
																								? () => _abrirModalEdicion(p)
																								: null,
																					),
																					DataCell(
																						Text("${p.cantidad}"),
																						onTap: _modoEdicion && !_modoEliminar
																								? () => _abrirModalEdicion(p)
																								: null,
																					),
																					DataCell(
																						_EstadoStockChip(bajo: _bajoStock(p)),
																						onTap: _modoEdicion && !_modoEliminar
																								? () => _abrirModalEdicion(p)
																								: null,
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

class _EditarProductoStockDialog extends StatefulWidget {
	const _EditarProductoStockDialog({required this.producto});

	final StockProduct producto;

	@override
	State<_EditarProductoStockDialog> createState() => _EditarProductoStockDialogState();
}

class _EditarProductoStockDialogState extends State<_EditarProductoStockDialog> {
	final _formKey = GlobalKey<FormState>();
	late final TextEditingController _codigo;
	late final TextEditingController _nombre;
	late final TextEditingController _categoria;
	late final TextEditingController _cantidad;

	@override
	void initState() {
		super.initState();
		final p = widget.producto;
		_codigo = TextEditingController(text: p.codigo?.trim() ?? "");
		_nombre = TextEditingController(text: p.nombre);
		_categoria = TextEditingController(text: p.categoria);
		_cantidad = TextEditingController(text: "${p.cantidad}");
	}

	@override
	void dispose() {
		_codigo.dispose();
		_nombre.dispose();
		_categoria.dispose();
		_cantidad.dispose();
		super.dispose();
	}

	void _guardar() {
		if (!_formKey.currentState!.validate()) return;
		final cant = int.tryParse(_cantidad.text.trim());
		if (cant == null || cant < 0) return;
		final cod = _codigo.text.trim();
		final actualizado = StockProduct(
			id: widget.producto.id,
			nombre: _nombre.text.trim(),
			categoria: _categoria.text.trim(),
			cantidad: cant,
			codigo: cod.isEmpty ? null : cod,
		);
		Navigator.of(context).pop(actualizado);
	}

	@override
	Widget build(BuildContext context) {
		final p = widget.producto;
		final codigoMostrado = p.codigo != null && p.codigo!.trim().isNotEmpty
				? p.codigo!.trim()
				: "STK-${(int.tryParse(p.id) ?? 0).toString().padLeft(3, "0")}";

		return AlertDialog(
			title: const Text("Editar producto"),
			content: SingleChildScrollView(
				child: Form(
					key: _formKey,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Text(
								"ID interno: ${p.id} · Código mostrado: $codigoMostrado",
								style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
							),
							const SizedBox(height: 16),
							TextFormField(
								controller: _codigo,
								decoration: const InputDecoration(
									labelText: "Código",
									border: OutlineInputBorder(),
									hintText: "Opcional; vacío = código generado",
								),
							),
							const SizedBox(height: 12),
							TextFormField(
								controller: _nombre,
								textCapitalization: TextCapitalization.sentences,
								decoration: const InputDecoration(
									labelText: "Nombre",
									border: OutlineInputBorder(),
								),
								validator: (v) {
									if (v == null || v.trim().isEmpty) {
										return "Ingresá el nombre";
									}
									return null;
								},
							),
							const SizedBox(height: 12),
							TextFormField(
								controller: _categoria,
								textCapitalization: TextCapitalization.words,
								decoration: const InputDecoration(
									labelText: "Uso / categoría",
									border: OutlineInputBorder(),
								),
								validator: (v) {
									if (v == null || v.trim().isEmpty) {
										return "Ingresá la categoría o uso";
									}
									return null;
								},
							),
							const SizedBox(height: 12),
							TextFormField(
								controller: _cantidad,
								keyboardType: TextInputType.number,
								inputFormatters: [FilteringTextInputFormatter.digitsOnly],
								decoration: const InputDecoration(
									labelText: "Cantidad",
									border: OutlineInputBorder(),
								),
								validator: (v) {
									if (v == null || v.trim().isEmpty) {
										return "Ingresá la cantidad";
									}
									final n = int.tryParse(v.trim());
									if (n == null) return "Número inválido";
									if (n < 0) return "La cantidad no puede ser negativa";
									return null;
								},
							),
						],
					),
				),
			),
			actions: [
				TextButton(
					onPressed: () => Navigator.of(context).pop(),
					child: const Text("Cancelar"),
				),
				FilledButton(
					onPressed: _guardar,
					child: const Text("Guardar"),
				),
			],
		);
	}
}

class _PanolToolbarBtn extends StatelessWidget {
	const _PanolToolbarBtn({
		required this.label,
		required this.icon,
		required this.bg,
		required this.fg,
		this.onPressed,
	});

	final String label;
	final IconData icon;
	final Color bg;
	final Color fg;
	final VoidCallback? onPressed;

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
				disabledBackgroundColor: Colors.grey.shade400,
				disabledForegroundColor: Colors.white70,
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
