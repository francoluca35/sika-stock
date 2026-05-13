import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";
import "../../auth/domain/profile_row.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/domain/stock_product.dart";
import "../../stock/presentation/widgets/add_stock_form_panel.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";

/// Ancho por debajo del cual el stock Pañol usa layout compacto (escritorio ≥720px sin cambios).
bool _panolStockLayoutCompact(BuildContext context) =>
		MediaQuery.sizeOf(context).width < 720;

/// Orden / filtro de la lista de stock (pantalla Pañol).
enum _PanolStockFilterSort {
	/// Mismo orden que el catálogo.
	catalogo,
	mayorCantidad,
	menorCantidad,
	/// Solo filas con cantidad 0.
	soloSinStock,
	alfabeticoNombre,
}

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

	_PanolStockFilterSort _filtroOrden = _PanolStockFilterSort.catalogo;
	String _busqueda = "";

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

	Future<void> _abrirBottomSheetAgregar() async {
		setState(() {
			_modoEdicion = false;
			_modoEliminar = false;
			_idsSeleccionados.clear();
		});
		if (!mounted) return;
		await showModalBottomSheet<void>(
			context: context,
			isScrollControlled: true,
			useSafeArea: true,
			backgroundColor: Colors.transparent,
			builder: (ctx) => _PanolAddStockBottomSheet(
				onClose: () => Navigator.of(ctx).pop(),
			),
		);
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

	String _codigoStock(StockProduct p) {
		if (p.codigo != null && p.codigo!.trim().isNotEmpty) {
			return p.codigo!.trim();
		}
		final n = int.tryParse(p.id) ?? 0;
		return "STK-${n.toString().padLeft(3, "0")}";
	}

	bool _bajoStock(StockProduct p) => p.cantidad == 0 || p.cantidad < 15;

	bool get _hayFiltrosActivos =>
			_busqueda.trim().isNotEmpty || _filtroOrden != _PanolStockFilterSort.catalogo;

	List<StockProduct> _productosVisibles(List<StockProduct> todos) {
		final q = _busqueda.trim().toLowerCase();
		var list = List<StockProduct>.from(todos);
		if (q.isNotEmpty) {
			list = list.where((p) {
				final cod = _codigoStock(p).toLowerCase();
				return p.nombre.toLowerCase().contains(q) ||
						p.categoria.toLowerCase().contains(q) ||
						cod.contains(q);
			}).toList();
		}
		if (_filtroOrden == _PanolStockFilterSort.soloSinStock) {
			list = list.where((p) => p.cantidad == 0).toList();
		}
		switch (_filtroOrden) {
			case _PanolStockFilterSort.catalogo:
				break;
			case _PanolStockFilterSort.mayorCantidad:
				list.sort((a, b) {
					final c = b.cantidad.compareTo(a.cantidad);
					return c != 0 ? c : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
				});
				break;
			case _PanolStockFilterSort.menorCantidad:
				list.sort((a, b) {
					final c = a.cantidad.compareTo(b.cantidad);
					return c != 0 ? c : a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
				});
				break;
			case _PanolStockFilterSort.soloSinStock:
				list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
				break;
			case _PanolStockFilterSort.alfabeticoNombre:
				list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
				break;
		}
		return list;
	}

	Future<void> _abrirBottomSheetFiltros() async {
		final result = await showModalBottomSheet<({String q, _PanolStockFilterSort orden})>(
			context: context,
			isScrollControlled: true,
			useSafeArea: true,
			backgroundColor: Colors.transparent,
			builder: (ctx) => _PanolFiltrosStockBottomSheet(
				busquedaInicial: _busqueda,
				ordenInicial: _filtroOrden,
			),
		);
		if (!mounted || result == null) return;
		setState(() {
			_busqueda = result.q;
			_filtroOrden = result.orden;
		});
	}

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
		try {
			await ref.read(supervisorStockCatalogProvider.notifier).removeByIds(ids);
			if (!mounted) return;
			setState(() {
				_idsSeleccionados.clear();
				_modoEliminar = false;
			});
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(n == 1 ? "Producto eliminado." : "Se eliminaron $n productos.")),
			);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo eliminar: $e")),
			);
		}
	}

	Future<void> _abrirModalEdicion(StockProduct producto) async {
		final guardado = await showDialog<StockProduct>(
			context: context,
			barrierDismissible: false,
			builder: (ctx) => _EditarProductoStockDialog(producto: producto),
		);
		if (!mounted || guardado == null) return;
		try {
			await ref.read(supervisorStockCatalogProvider.notifier).replaceProduct(guardado);
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Cambios guardados.")),
			);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo guardar: $e")),
			);
		}
	}

	Widget _buildMobileProductCards(List<StockProduct> productos, bool puedeGestionar) {
		return Padding(
			padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					for (final p in productos)
						Padding(
							padding: const EdgeInsets.only(bottom: 10),
							child: _mobileProductCard(p, puedeGestionar),
						),
				],
			),
		);
	}

	Widget _mobileProductCard(StockProduct p, bool puedeGestionar) {
		final cod = _codigoStock(p);
		final sel = _idsSeleccionados.contains(p.id);
		return Material(
			color: sel ? AppTokens.redAction.withValues(alpha: 0.12) : AppTokens.surfaceMuted,
			shape: RoundedRectangleBorder(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				side: BorderSide(color: AppTokens.greyBorder),
			),
			child: InkWell(
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				onTap: !puedeGestionar
						? null
						: _modoEliminar
								? () {
										setState(() => _toggleSeleccionFila(p.id, !sel));
									}
								: _modoEdicion && !_modoEliminar
										? () => _abrirModalEdicion(p)
										: null,
				child: Padding(
					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							if (puedeGestionar && _modoEliminar) ...[
								Checkbox(
									value: sel,
									onChanged: (v) => setState(() => _toggleSeleccionFila(p.id, v)),
								),
								const SizedBox(width: 4),
							],
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											cod,
											style: const TextStyle(
												fontWeight: FontWeight.w800,
												fontSize: 12,
												letterSpacing: 0.4,
												color: Colors.black87,
											),
										),
										const SizedBox(height: 6),
										Text(
											p.nombre,
											style: const TextStyle(
												fontWeight: FontWeight.w600,
												fontSize: 16,
												height: 1.25,
												color: Colors.black87,
											),
										),
										const SizedBox(height: 4),
										Text(
											"USO · ${p.categoria}",
											style: TextStyle(
												fontSize: 13,
												height: 1.3,
												color: Colors.grey.shade700,
											),
											maxLines: 4,
											overflow: TextOverflow.ellipsis,
										),
										const SizedBox(height: 10),
										Row(
											children: [
												Text(
													"Cantidad: ${p.cantidad}",
													style: const TextStyle(
														fontWeight: FontWeight.w600,
														fontSize: 14,
														color: Colors.black87,
													),
												),
												const Spacer(),
												_EstadoStockChip(bajo: _bajoStock(p)),
											],
										),
									],
								),
							),
						],
					),
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		ref.listen<AsyncValue<ProfileRow?>>(currentProfileProvider, (prev, next) {
			next.whenData((p) {
				if (!appRolePuedeGestionarStock(p?.rol) && mounted) {
					setState(() {
						_modoEdicion = false;
						_modoEliminar = false;
						_idsSeleccionados.clear();
					});
				}
			});
		});
		final puedeGestionar = ref.watch(currentProfileProvider).maybeWhen(
			data: (p) => appRolePuedeGestionarStock(p?.rol),
			orElse: () => false,
		);
		final catalogAsync = ref.watch(supervisorStockCatalogProvider);
		final compact = _panolStockLayoutCompact(context);

		return catalogAsync.when(
			loading: () => Scaffold(
				backgroundColor: AppTokens.surfacePage,
				body: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						StockScreenHeader(
							title: "STOCK",
							onBack: () => _back(context),
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
							title: "STOCK",
							onBack: () => _back(context),
						),
						Expanded(
							child: Center(
								child: Padding(
									padding: const EdgeInsets.all(24),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											const Text(
												"No se pudo cargar el stock.",
												textAlign: TextAlign.center,
											),
											const SizedBox(height: 8),
											Text(
												"$e",
												textAlign: TextAlign.center,
												style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
											),
											const SizedBox(height: 16),
											FilledButton(
												onPressed: () =>
														ref.invalidate(supervisorStockCatalogProvider),
												child: const Text("Reintentar"),
											),
										],
									),
								),
							),
						),
					],
				),
			),
			data: (productos) {
				final visibles = _productosVisibles(productos);
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
							alignment: compact ? Alignment.center : Alignment.centerRight,
							child: TextButton.icon(
								onPressed: _abrirBottomSheetFiltros,
								icon: Icon(
									_hayFiltrosActivos ? Icons.filter_alt : Icons.tune,
									size: 20,
									color: Colors.black87,
								),
								label: Text(
									_hayFiltrosActivos
											? "Filtros y búsqueda (activos)"
											: "Filtros y búsqueda",
									style: TextStyle(
										fontWeight: FontWeight.w600,
										color: Colors.black87,
										fontSize: compact ? 13 : 14,
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
													child: !puedeGestionar
															? Align(
																	alignment: Alignment.centerLeft,
																	child: Padding(
																		padding: const EdgeInsets.symmetric(vertical: 6),
																		child: Text(
																			"Solo lectura. Agregar, editar o quitar productos "
																			"corresponde al rol Pañol.",
																			style: TextStyle(
																				fontSize: 13,
																				height: 1.35,
																				color: Colors.grey.shade800,
																				fontWeight: FontWeight.w600,
																			),
																		),
																	),
																)
															: compact
																	? LayoutBuilder(
																	builder: (context, c) {
																		final gap = 8.0;
																		final colW = (c.maxWidth - gap) / 2;
																		Widget cell(_PanolToolbarBtn btn) => SizedBox(
																					width: colW,
																					child: btn,
																				);
																		return Column(
																			crossAxisAlignment:
																					CrossAxisAlignment.stretch,
																			children: [
																				Row(
																					children: [
																						cell(
																							_PanolToolbarBtn(
																								stretch: true,
																								label: _modoEdicion
																										? "LISTO"
																										: "EDITAR",
																								icon: _modoEdicion
																										? Icons.check
																										: Icons.edit_outlined,
																								bg: _modoEdicion
																										? AppTokens.statusOk
																										: AppTokens.yellowHeader,
																								fg: _modoEdicion
																										? Colors.white
																										: Colors.black87,
																								onPressed: () =>
																										_setModoEdicion(
																											!_modoEdicion,
																										),
																							),
																						),
																						SizedBox(width: gap),
																						cell(
																							_PanolToolbarBtn(
																								stretch: true,
																								label: "AÑADIR",
																								icon: Icons.add,
																								bg: AppTokens.yellowHeader,
																								fg: Colors.black87,
																								onPressed:
																										_abrirBottomSheetAgregar,
																							),
																						),
																					],
																				),
																				SizedBox(height: gap),
																				Row(
																					children: [
																						Expanded(
																							child: _PanolToolbarBtn(
																								stretch: true,
																								label: _modoEliminar
																										? "LISTO"
																										: "ELIMINAR",
																								icon: _modoEliminar
																										? Icons.check
																										: Icons
																												.delete_outline,
																								bg: _modoEliminar
																										? AppTokens.statusOk
																										: AppTokens.redAction,
																								fg: Colors.white,
																								onPressed: () =>
																										_setModoEliminar(
																											!_modoEliminar,
																										),
																							),
																						),
																					],
																				),
																				if (_modoEliminar) ...[
																					SizedBox(height: gap),
																					_PanolToolbarBtn(
																						stretch: true,
																						label: _idsSeleccionados.isEmpty
																								? "ELIMINAR SELECCIÓN"
																								: "ELIMINAR (${_idsSeleccionados.length})",
																						icon: Icons.delete_forever_outlined,
																						bg: AppTokens.redAction,
																						fg: Colors.white,
																						onPressed: _idsSeleccionados.isEmpty
																								? null
																								: _confirmarEliminarSeleccion,
																					),
																				],
																			],
																		);
																	},
																)
															: Wrap(
																	spacing: 8,
																	runSpacing: 8,
																	alignment: WrapAlignment.start,
																	children: [
																		_PanolToolbarBtn(
																			label: _modoEdicion ? "LISTO" : "EDITAR",
																			icon: _modoEdicion
																					? Icons.check
																					: Icons.edit_outlined,
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
																			onPressed: _abrirBottomSheetAgregar,
																		),
																		_PanolToolbarBtn(
																			label: _modoEliminar ? "LISTO" : "ELIMINAR",
																			icon: _modoEliminar
																					? Icons.check
																					: Icons.delete_outline,
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
																	],
																),
												),
												if (_modoEdicion && puedeGestionar)
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
												if (_modoEliminar && puedeGestionar)
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
												if (visibles.isEmpty)
													Padding(
														padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
														child: Text(
															productos.isEmpty
																	? "No hay productos en el catálogo."
																	: "No hay productos que coincidan con los filtros o la búsqueda.",
															textAlign: TextAlign.center,
															style: TextStyle(
																fontSize: 14,
																height: 1.35,
																color: Colors.grey.shade700,
															),
														),
													)
												else if (compact)
													_buildMobileProductCards(visibles, puedeGestionar)
												else
													LayoutBuilder(
														builder: (context, constraints) {
															return SingleChildScrollView(
																scrollDirection: Axis.horizontal,
																child: ConstrainedBox(
																	constraints: BoxConstraints(
																		minWidth: constraints.maxWidth,
																	),
																	child: DataTable(
																	showCheckboxColumn: puedeGestionar && _modoEliminar,
																	headingRowColor: WidgetStateProperty.all(
																		AppTokens.surfaceMuted,
																	),
																	dataRowMinHeight:
																			puedeGestionar && (_modoEdicion || _modoEliminar)
																					? 48
																					: 44,
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
																		for (final p in visibles)
																			DataRow(
																				selected: _idsSeleccionados.contains(p.id),
																				onSelectChanged: puedeGestionar && _modoEliminar
																						? (v) => _toggleSeleccionFila(p.id, v)
																						: null,
																				cells: [
																					DataCell(
																						Text(_codigoStock(p)),
																						onTap: puedeGestionar && _modoEdicion && !_modoEliminar
																								? () => _abrirModalEdicion(p)
																								: null,
																					),
																					DataCell(
																						Text(
																							p.nombre,
																							overflow: TextOverflow.ellipsis,
																						),
																						onTap: puedeGestionar && _modoEdicion && !_modoEliminar
																								? () => _abrirModalEdicion(p)
																								: null,
																					),
																					DataCell(
																						Text(p.categoria),
																						onTap: puedeGestionar && _modoEdicion && !_modoEliminar
																								? () => _abrirModalEdicion(p)
																								: null,
																					),
																					DataCell(
																						Text("${p.cantidad}"),
																						onTap: puedeGestionar && _modoEdicion && !_modoEliminar
																								? () => _abrirModalEdicion(p)
																								: null,
																					),
																					DataCell(
																						_EstadoStockChip(bajo: _bajoStock(p)),
																						onTap: puedeGestionar && _modoEdicion && !_modoEliminar
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
			},
		);
	}
}

/// Bottom sheet: búsqueda + orden / filtro de la lista de stock.
class _PanolFiltrosStockBottomSheet extends StatefulWidget {
	const _PanolFiltrosStockBottomSheet({
		required this.busquedaInicial,
		required this.ordenInicial,
	});

	final String busquedaInicial;
	final _PanolStockFilterSort ordenInicial;

	@override
	State<_PanolFiltrosStockBottomSheet> createState() => _PanolFiltrosStockBottomSheetState();
}

class _PanolFiltrosStockBottomSheetState extends State<_PanolFiltrosStockBottomSheet> {
	late final TextEditingController _busquedaCtrl;
	late _PanolStockFilterSort _orden;

	@override
	void initState() {
		super.initState();
		_busquedaCtrl = TextEditingController(text: widget.busquedaInicial);
		_orden = widget.ordenInicial;
	}

	@override
	void dispose() {
		_busquedaCtrl.dispose();
		super.dispose();
	}

	void _aplicar() {
		Navigator.pop(
			context,
			(q: _busquedaCtrl.text.trim(), orden: _orden),
		);
	}

	void _restablecer() {
		Navigator.pop(
			context,
			(q: "", orden: _PanolStockFilterSort.catalogo),
		);
	}

	@override
	Widget build(BuildContext context) {
		final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

		return Padding(
			padding: EdgeInsets.only(bottom: bottomInset),
			child: Align(
				alignment: Alignment.bottomCenter,
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 560),
					child: Material(
						color: AppTokens.whiteSurface,
						borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
						clipBehavior: Clip.antiAlias,
						elevation: 12,
						shadowColor: Colors.black38,
						child: SafeArea(
							top: false,
							child: SingleChildScrollView(
								padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
								child: Column(
									mainAxisSize: MainAxisSize.min,
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: [
										Center(
											child: Container(
												width: 40,
												height: 4,
												margin: const EdgeInsets.only(bottom: 12),
												decoration: BoxDecoration(
													color: Colors.grey.shade400,
													borderRadius: BorderRadius.circular(2),
												),
											),
										),
										Row(
											children: [
												const Icon(Icons.filter_list, color: Colors.black87, size: 26),
												const SizedBox(width: 10),
												const Expanded(
													child: Text(
														"Filtros y búsqueda",
														style: TextStyle(
															fontWeight: FontWeight.bold,
															fontSize: 17,
															color: Colors.black87,
														),
													),
												),
												IconButton(
													tooltip: "Cerrar",
													onPressed: () => Navigator.pop(context),
													icon: const Icon(Icons.close, color: Colors.black87),
												),
											],
										),
										const SizedBox(height: 8),
										TextField(
											controller: _busquedaCtrl,
											textCapitalization: TextCapitalization.sentences,
											decoration: InputDecoration(
												isDense: true,
												prefixIcon: const Icon(Icons.search, color: Colors.black54),
												hintText: "Buscar por producto, código o categoría",
												border: OutlineInputBorder(
													borderRadius: BorderRadius.circular(AppTokens.radiusMd),
												),
												filled: true,
												fillColor: AppTokens.surfaceMuted,
											),
											onChanged: (_) => setState(() {}),
										),
										const SizedBox(height: 18),
										Text(
											"Orden y filtros",
											style: TextStyle(
												fontWeight: FontWeight.w700,
												fontSize: 13,
												color: Colors.grey.shade800,
											),
										),
										const SizedBox(height: 6),
										RadioListTile<_PanolStockFilterSort>(
											dense: true,
											title: const Text("Catálogo (orden por defecto)"),
											value: _PanolStockFilterSort.catalogo,
											groupValue: _orden,
											onChanged: (v) => setState(() => _orden = v ?? _PanolStockFilterSort.catalogo),
										),
										RadioListTile<_PanolStockFilterSort>(
											dense: true,
											title: const Text("Mayor stock (más unidades primero)"),
											value: _PanolStockFilterSort.mayorCantidad,
											groupValue: _orden,
											onChanged: (v) => setState(() => _orden = v ?? _PanolStockFilterSort.catalogo),
										),
										RadioListTile<_PanolStockFilterSort>(
											dense: true,
											title: const Text("Menor stock (menos unidades primero)"),
											value: _PanolStockFilterSort.menorCantidad,
											groupValue: _orden,
											onChanged: (v) => setState(() => _orden = v ?? _PanolStockFilterSort.catalogo),
										),
										RadioListTile<_PanolStockFilterSort>(
											dense: true,
											title: const Text("Sin stock (solo cantidad 0)"),
											value: _PanolStockFilterSort.soloSinStock,
											groupValue: _orden,
											onChanged: (v) => setState(() => _orden = v ?? _PanolStockFilterSort.catalogo),
										),
										RadioListTile<_PanolStockFilterSort>(
											dense: true,
											title: const Text("Orden alfabético (por nombre)"),
											value: _PanolStockFilterSort.alfabeticoNombre,
											groupValue: _orden,
											onChanged: (v) => setState(() => _orden = v ?? _PanolStockFilterSort.catalogo),
										),
										const SizedBox(height: 16),
										Row(
											children: [
												TextButton(
													onPressed: _restablecer,
													child: const Text("Restablecer"),
												),
												const Spacer(),
												FilledButton(
													style: FilledButton.styleFrom(
														backgroundColor: AppTokens.redAction,
														foregroundColor: Colors.white,
													),
													onPressed: _aplicar,
													child: const Text("Listo"),
												),
											],
										),
									],
								),
							),
						),
					),
				),
			),
		);
	}
}

/// Bottom sheet estilo Android: panel redondeado desde abajo con asa y scroll.
class _PanolAddStockBottomSheet extends StatelessWidget {
	const _PanolAddStockBottomSheet({required this.onClose});

	final VoidCallback onClose;

	@override
	Widget build(BuildContext context) {
		final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
		final maxH = MediaQuery.sizeOf(context).height * 0.88;

		return Padding(
			padding: EdgeInsets.only(bottom: bottomInset),
			child: Align(
				alignment: Alignment.bottomCenter,
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 560),
					child: SizedBox(
						height: maxH,
						child: Material(
							color: AppTokens.whiteSurface,
							borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
							clipBehavior: Clip.antiAlias,
							elevation: 12,
							shadowColor: Colors.black38,
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
								const SizedBox(height: 10),
								Center(
									child: Container(
										width: 40,
										height: 4,
										decoration: BoxDecoration(
											color: Colors.grey.shade400,
											borderRadius: BorderRadius.circular(2),
										),
									),
								),
								Padding(
									padding: const EdgeInsets.fromLTRB(16, 14, 4, 4),
									child: Row(
										children: [
											const Icon(Icons.add_box_outlined, color: Colors.black87, size: 26),
											const SizedBox(width: 10),
											const Expanded(
												child: Text(
													"AGREGAR STOCK",
													style: TextStyle(
														fontWeight: FontWeight.bold,
														fontSize: 17,
														letterSpacing: 0.4,
														color: Colors.black87,
													),
												),
											),
											IconButton(
												tooltip: "Cerrar",
												onPressed: onClose,
												icon: const Icon(Icons.close, color: Colors.black87),
											),
										],
									),
								),
								Expanded(
									child: SingleChildScrollView(
										padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
										child: Center(
											child: ConstrainedBox(
												constraints: const BoxConstraints(maxWidth: 480),
												child: AddStockFormPanel(
													onSubmitSuccess: onClose,
												),
											),
										),
									),
								),
							],
						),
					),
				),
			),
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
				: p.id.length >= 8
						? p.id.substring(0, 8).toUpperCase()
						: p.id.toUpperCase();

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
		this.stretch = false,
	});

	final String label;
	final IconData icon;
	final Color bg;
	final Color fg;
	final VoidCallback? onPressed;
	final bool stretch;

	@override
	Widget build(BuildContext context) {
		final btn = FilledButton.icon(
			style: FilledButton.styleFrom(
				backgroundColor: bg,
				foregroundColor: fg,
				padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
				minimumSize: stretch ? const Size(double.infinity, 48) : null,
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
		if (stretch) {
			return SizedBox(width: double.infinity, child: btn);
		}
		return btn;
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
