import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";
import "../../auth/domain/profile_row.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/presentation/widgets/stock_excel_import_dialog.dart";
import "../../stock/domain/stock_product.dart";
import "../../stock/domain/stock_alert_level.dart";
import "../../stock/presentation/widgets/add_stock_form_panel.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";

/// Ancho por debajo del cual el stock Pañol usa layout compacto (escritorio ≥720px sin cambios).
bool _panolStockLayoutCompact(BuildContext context) =>
		MediaQuery.sizeOf(context).width < 720;

/// Ancho mínimo de la tabla desktop (evita que DataTable comprima columnas).
const double _kPanolStockTableWidth = 1480;

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
	String? _categoriaFiltro;

	List<StockProduct>? _visiblesCache;
	List<StockProduct>? _visiblesCacheSource;
	String _visiblesCacheBusqueda = "";
	_PanolStockFilterSort _visiblesCacheOrden = _PanolStockFilterSort.catalogo;
	String? _visiblesCacheCategoria;

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

	Future<void> _cargarExcel() async {
		setState(() {
			_modoEdicion = false;
			_modoEliminar = false;
			_idsSeleccionados.clear();
		});
		if (!mounted) return;
		await showStockExcelImportDialog(context, ref);
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

	String _textoLista(String v) {
		final t = v.trim();
		return t.isEmpty ? "—" : t;
	}

	Widget _detalleListaLinea(String etiqueta, String valor) {
		return Padding(
			padding: const EdgeInsets.only(top: 4),
			child: Text(
				"$etiqueta · ${_textoLista(valor)}",
				style: TextStyle(
					fontSize: 13,
					height: 1.3,
					color: Colors.grey.shade700,
				),
				maxLines: 4,
				overflow: TextOverflow.ellipsis,
			),
		);
	}

	Widget _celdaLista(String texto, {double minWidth = 132, double maxWidth = 220}) {
		final t = _textoLista(texto);
		return ConstrainedBox(
			constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
			child: Tooltip(
				message: t == "—" ? "" : t,
				child: Text(
					t,
					maxLines: 3,
					overflow: TextOverflow.ellipsis,
					softWrap: true,
				),
			),
		);
	}

	void _onTapEditarFila(StockProduct p, bool puedeGestionar) {
		if (puedeGestionar && _modoEdicion && !_modoEliminar) {
			_abrirModalEdicion(p);
		}
	}

	bool get _hayFiltrosActivos =>
			_busqueda.trim().isNotEmpty ||
			_filtroOrden != _PanolStockFilterSort.catalogo ||
			_categoriaFiltro != null;

	List<String> _categoriasOrdenadas(List<StockProduct> productos) {
		final s = productos.map((p) => p.categoria).toSet().toList();
		s.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
		return s;
	}

	List<StockProduct> _productosVisibles(List<StockProduct> todos) {
		if (_visiblesCache != null &&
				identical(_visiblesCacheSource, todos) &&
				_visiblesCacheBusqueda == _busqueda &&
				_visiblesCacheOrden == _filtroOrden &&
				_visiblesCacheCategoria == _categoriaFiltro) {
			return _visiblesCache!;
		}

		final q = _busqueda.trim().toLowerCase();
		var list = List<StockProduct>.from(todos);
		if (q.isNotEmpty) {
			list = list.where((p) {
				final cod = _codigoStock(p).toLowerCase();
				return p.nombre.toLowerCase().contains(q) ||
						p.categoria.toLowerCase().contains(q) ||
						p.marca.toLowerCase().contains(q) ||
						p.descripcionEmpresa.toLowerCase().contains(q) ||
						p.descripcionFabricante.toLowerCase().contains(q) ||
						cod.contains(q);
			}).toList();
		}
		if (_categoriaFiltro != null) {
			list = list.where((p) => p.categoria == _categoriaFiltro).toList();
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
		_visiblesCacheSource = todos;
		_visiblesCacheBusqueda = _busqueda;
		_visiblesCacheOrden = _filtroOrden;
		_visiblesCacheCategoria = _categoriaFiltro;
		_visiblesCache = list;
		return list;
	}

	Future<void> _abrirBottomSheetFiltros(List<StockProduct> productos) async {
		final result = await showModalBottomSheet<
				({String q, _PanolStockFilterSort orden, String? categoria})>(
			context: context,
			isScrollControlled: true,
			useSafeArea: true,
			backgroundColor: Colors.transparent,
			builder: (ctx) => _PanolFiltrosStockBottomSheet(
				busquedaInicial: _busqueda,
				ordenInicial: _filtroOrden,
				categoriaInicial: _categoriaFiltro,
				categorias: _categoriasOrdenadas(productos),
			),
		);
		if (!mounted || result == null) return;
		setState(() {
			_busqueda = result.q;
			_filtroOrden = result.orden;
			_categoriaFiltro = result.categoria;
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
										_detalleListaLinea("Categoría", p.categoria),
										_detalleListaLinea("Marca", p.marca),
										_detalleListaLinea("Desc. empresa", p.descripcionEmpresa),
										_detalleListaLinea("Desc. fabricante", p.descripcionFabricante),
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
												_EstadoStockChip(level: p.alertLevel),
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
						padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 8, compact ? 12 : 16, 0),
						child: Align(
							alignment: compact ? Alignment.center : Alignment.centerRight,
							child: TextButton.icon(
								onPressed: () => _abrirBottomSheetFiltros(productos),
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
						child: compact
								? Center(
										child: ConstrainedBox(
											constraints: const BoxConstraints(maxWidth: 960),
											child: _buildStockPanel(
												compact: true,
												visibles: visibles,
												productos: productos,
												puedeGestionar: puedeGestionar,
											),
										),
									)
								: _buildStockPanel(
										compact: false,
										visibles: visibles,
										productos: productos,
										puedeGestionar: puedeGestionar,
									),
					),
				],
			),
		);
			},
		);
	}
	Widget _buildStockPanel({
		required bool compact,
		required List<StockProduct> visibles,
		required List<StockProduct> productos,
		required bool puedeGestionar,
	}) {
		final toolbarPad = compact ? 10.0 : 16.0;

		return Material(
			color: AppTokens.whiteSurface,
			borderRadius: compact
					? BorderRadius.circular(AppTokens.radiusLg)
					: BorderRadius.zero,
			clipBehavior: Clip.antiAlias,
			elevation: compact ? 1 : 0,
			shadowColor: Colors.black12,
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Padding(
						padding: EdgeInsets.fromLTRB(toolbarPad, 12, toolbarPad, 8),
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
														crossAxisAlignment: CrossAxisAlignment.stretch,
														children: [
															Row(
																children: [
																	cell(
																		_PanolToolbarBtn(
																			stretch: true,
																			label: _modoEdicion ? "LISTO" : "EDITAR",
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
																					_setModoEdicion(!_modoEdicion),
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
																			onPressed: _abrirBottomSheetAgregar,
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
																			label: _modoEliminar ? "LISTO" : "ELIMINAR",
																			icon: _modoEliminar
																					? Icons.check
																					: Icons.delete_outline,
																			bg: _modoEliminar
																					? AppTokens.statusOk
																					: AppTokens.redAction,
																			fg: Colors.white,
																			onPressed: () =>
																					_setModoEliminar(!_modoEliminar),
																		),
																	),
																],
															),
															SizedBox(height: gap),
															_PanolToolbarBtn(
																stretch: true,
																label: "CARGAR EXCEL",
																icon: Icons.upload_file_outlined,
																bg: Colors.black87,
																fg: Colors.white,
																onPressed: _cargarExcel,
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
														onPressed: _abrirBottomSheetAgregar,
													),
													_PanolToolbarBtn(
														label: "CARGAR EXCEL",
														icon: Icons.upload_file_outlined,
														bg: Colors.black87,
														fg: Colors.white,
														onPressed: _cargarExcel,
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
																	: _confirmarEliminarSeleccion,
														),
												],
											),
					),
					if (_modoEdicion && puedeGestionar)
						Padding(
							padding: EdgeInsets.fromLTRB(toolbarPad, 0, toolbarPad, 8),
							child: DecoratedBox(
								decoration: BoxDecoration(
									color: AppTokens.yellowHeader.withValues(alpha: 0.35),
									borderRadius: BorderRadius.circular(AppTokens.radiusMd),
									border: Border.all(color: Colors.black26),
								),
								child: const Padding(
									padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
							padding: EdgeInsets.fromLTRB(toolbarPad, 0, toolbarPad, 8),
							child: DecoratedBox(
								decoration: BoxDecoration(
									color: AppTokens.redAction.withValues(alpha: 0.12),
									borderRadius: BorderRadius.circular(AppTokens.radiusMd),
									border: Border.all(
										color: AppTokens.redAction.withValues(alpha: 0.45),
									),
								),
								child: const Padding(
									padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
						Expanded(
							child: Center(
								child: Padding(
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
								),
							),
						)
					else
						Expanded(
							child: compact
									? _buildMobileStockList(visibles, puedeGestionar)
									: _buildDesktopStockTable(visibles, puedeGestionar),
						),
				],
			),
		);
	}

	static const TextStyle _kTableHeaderStyle = TextStyle(
		fontWeight: FontWeight.w700,
		fontSize: 12,
		letterSpacing: 0.3,
		color: Colors.black87,
	);

	Widget _buildDesktopStockTable(List<StockProduct> visibles, bool puedeGestionar) {
		final showCheck = puedeGestionar && _modoEliminar;
		return LayoutBuilder(
			builder: (context, constraints) {
				final tableW = constraints.maxWidth > _kPanolStockTableWidth
						? constraints.maxWidth
						: _kPanolStockTableWidth;
				return Scrollbar(
					thumbVisibility: true,
					notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
					child: SingleChildScrollView(
						scrollDirection: Axis.horizontal,
						child: SizedBox(
							width: tableW,
							height: constraints.maxHeight,
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									_desktopTableHeader(showCheck),
									Expanded(
										child: Scrollbar(
											child: ListView.builder(
												itemCount: visibles.length,
												itemBuilder: (context, i) => _desktopStockRow(
													visibles[i],
													puedeGestionar,
													showCheck,
												),
											),
										),
									),
								],
							),
						),
					),
				);
			},
		);
	}

	Widget _desktopTableHeader(bool showCheck) {
		return Container(
			color: AppTokens.surfaceMuted,
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
			child: Row(
				children: [
					if (showCheck) const SizedBox(width: 48),
					const SizedBox(width: 100, child: Text("CÓDIGO", style: _kTableHeaderStyle)),
					const SizedBox(width: 12),
					const SizedBox(width: 180, child: Text("NOMBRE", style: _kTableHeaderStyle)),
					const SizedBox(width: 12),
					const SizedBox(
						width: 72,
						child: Align(
							alignment: Alignment.centerRight,
							child: Text("CANTIDAD", style: _kTableHeaderStyle),
						),
					),
					const SizedBox(width: 12),
					const SizedBox(width: 100, child: Text("ESTADO", style: _kTableHeaderStyle)),
					const SizedBox(width: 12),
					const SizedBox(width: 140, child: Text("CATEGORÍA", style: _kTableHeaderStyle)),
					const SizedBox(width: 12),
					const SizedBox(width: 120, child: Text("MARCA", style: _kTableHeaderStyle)),
					const SizedBox(width: 12),
					const SizedBox(width: 200, child: Text("DESC. EMPRESA", style: _kTableHeaderStyle)),
					const SizedBox(width: 12),
					const Expanded(child: Text("DESC. FABRICANTE", style: _kTableHeaderStyle)),
				],
			),
		);
	}

	Widget _desktopStockRow(StockProduct p, bool puedeGestionar, bool showCheck) {
		final sel = _idsSeleccionados.contains(p.id);
		return Material(
			color: sel ? AppTokens.redAction.withValues(alpha: 0.08) : Colors.transparent,
			child: InkWell(
				onTap: showCheck
						? () => _toggleSeleccionFila(p.id, !sel)
						: () => _onTapEditarFila(p, puedeGestionar),
				child: Container(
					constraints: const BoxConstraints(minHeight: 48, maxHeight: 80),
					padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
					decoration: BoxDecoration(
						border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
					),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							if (showCheck)
								SizedBox(
									width: 48,
									child: Checkbox(
										value: sel,
										onChanged: (v) => _toggleSeleccionFila(p.id, v),
									),
								),
							SizedBox(
								width: 100,
								child: Text(
									_codigoStock(p),
									overflow: TextOverflow.ellipsis,
								),
							),
							const SizedBox(width: 12),
							SizedBox(
								width: 180,
								child: Text(
									p.nombre,
									maxLines: 2,
									overflow: TextOverflow.ellipsis,
								),
							),
							const SizedBox(width: 12),
							SizedBox(
								width: 72,
								child: Align(
									alignment: Alignment.centerRight,
									child: Text(
										"${p.cantidad}",
										style: const TextStyle(
											fontWeight: FontWeight.w700,
											fontSize: 15,
										),
									),
								),
							),
							const SizedBox(width: 12),
							SizedBox(width: 100, child: _EstadoStockChip(level: p.alertLevel)),
							const SizedBox(width: 12),
							SizedBox(
								width: 140,
								child: _celdaLista(p.categoria, minWidth: 100, maxWidth: 140),
							),
							const SizedBox(width: 12),
							SizedBox(
								width: 120,
								child: _celdaLista(p.marca, minWidth: 96, maxWidth: 120),
							),
							const SizedBox(width: 12),
							SizedBox(
								width: 200,
								child: _celdaLista(
									p.descripcionEmpresa,
									minWidth: 160,
									maxWidth: 200,
								),
							),
							const SizedBox(width: 12),
							Expanded(
								child: _celdaLista(
									p.descripcionFabricante,
									minWidth: 160,
									maxWidth: 280,
								),
							),
						],
					),
				),
			),
		);
	}

	Widget _buildMobileStockList(List<StockProduct> productos, bool puedeGestionar) {
		return ListView.builder(
			padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
			itemCount: productos.length,
			itemBuilder: (context, i) => Padding(
				padding: const EdgeInsets.only(bottom: 10),
				child: _mobileProductCard(productos[i], puedeGestionar),
			),
		);
	}
}

/// Bottom sheet: búsqueda + orden / filtro de la lista de stock.
class _PanolFiltrosStockBottomSheet extends StatefulWidget {
	const _PanolFiltrosStockBottomSheet({
		required this.busquedaInicial,
		required this.ordenInicial,
		required this.categoriaInicial,
		required this.categorias,
	});

	final String busquedaInicial;
	final _PanolStockFilterSort ordenInicial;
	final String? categoriaInicial;
	final List<String> categorias;

	@override
	State<_PanolFiltrosStockBottomSheet> createState() => _PanolFiltrosStockBottomSheetState();
}

class _PanolFiltrosStockBottomSheetState extends State<_PanolFiltrosStockBottomSheet> {
	late final TextEditingController _busquedaCtrl;
	late _PanolStockFilterSort _orden;
	late String? _categoria;

	@override
	void initState() {
		super.initState();
		_busquedaCtrl = TextEditingController(text: widget.busquedaInicial);
		_orden = widget.ordenInicial;
		_categoria = widget.categoriaInicial;
	}

	@override
	void dispose() {
		_busquedaCtrl.dispose();
		super.dispose();
	}

	void _aplicar() {
		Navigator.pop(
			context,
			(q: _busquedaCtrl.text.trim(), orden: _orden, categoria: _categoria),
		);
	}

	void _restablecer() {
		Navigator.pop(
			context,
			(q: "", orden: _PanolStockFilterSort.catalogo, categoria: null),
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
												hintText: "Buscar por código, nombre, marca, categoría o descripción",
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
											"Categoría",
											style: TextStyle(
												fontWeight: FontWeight.w700,
												fontSize: 13,
												color: Colors.grey.shade800,
											),
										),
										const SizedBox(height: 6),
										DropdownButtonFormField<String?>(
											value: _categoria != null && widget.categorias.contains(_categoria)
													? _categoria
													: null,
											isExpanded: true,
											decoration: InputDecoration(
												isDense: true,
												hintText: "Todas las categorías",
												border: OutlineInputBorder(
													borderRadius: BorderRadius.circular(AppTokens.radiusMd),
												),
												filled: true,
												fillColor: AppTokens.surfaceMuted,
												contentPadding: const EdgeInsets.symmetric(
													horizontal: 12,
													vertical: 10,
												),
											),
											items: [
												const DropdownMenuItem<String?>(
													value: null,
													child: Text("Todas"),
												),
												for (final c in widget.categorias)
													DropdownMenuItem<String?>(
														value: c,
														child: Text(c),
													),
											],
											onChanged: (v) => setState(() => _categoria = v),
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
	late final TextEditingController _descripcionEmpresa;
	late final TextEditingController _descripcionFabricante;
	late final TextEditingController _categoria;
	late final TextEditingController _marca;
	late final TextEditingController _cantidad;
	late final TextEditingController _minimo;
	late final TextEditingController _maximo;

	@override
	void initState() {
		super.initState();
		final p = widget.producto;
		_codigo = TextEditingController(text: p.codigo?.trim() ?? "");
		_nombre = TextEditingController(text: p.nombre);
		_descripcionEmpresa = TextEditingController(text: p.descripcionEmpresa);
		_descripcionFabricante = TextEditingController(text: p.descripcionFabricante);
		_categoria = TextEditingController(text: p.categoria);
		_marca = TextEditingController(text: p.marca);
		_cantidad = TextEditingController(text: "${p.cantidad}");
		_minimo = TextEditingController(text: "${p.cantidadMinima}");
		_maximo = TextEditingController(text: "${p.cantidadMaxima}");
	}

	@override
	void dispose() {
		_codigo.dispose();
		_nombre.dispose();
		_descripcionEmpresa.dispose();
		_descripcionFabricante.dispose();
		_categoria.dispose();
		_marca.dispose();
		_cantidad.dispose();
		_minimo.dispose();
		_maximo.dispose();
		super.dispose();
	}

	void _guardar() {
		if (!_formKey.currentState!.validate()) return;
		final cant = int.tryParse(_cantidad.text.trim());
		final min = int.tryParse(_minimo.text.trim());
		final max = int.tryParse(_maximo.text.trim());
		if (cant == null || cant < 0 || min == null || min < 0 || max == null || max < 0) {
			return;
		}
		if (max > 0 && min > max) return;
		final cod = _codigo.text.trim();
		final actualizado = StockProduct(
			id: widget.producto.id,
			nombre: _nombre.text.trim(),
			categoria: _categoria.text.trim(),
			cantidad: cant,
			cantidadMinima: min,
			cantidadMaxima: max,
			codigo: cod.isEmpty ? null : cod,
			descripcionEmpresa: _descripcionEmpresa.text.trim(),
			descripcionFabricante: _descripcionFabricante.text.trim(),
			marca: _marca.text.trim(),
		);
		Navigator.of(context).pop(actualizado);
	}

	@override
	Widget build(BuildContext context) {
		final p = widget.producto;

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
								"ID interno: ${p.id}",
								style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
							),
							const SizedBox(height: 16),
							TextFormField(
								controller: _codigo,
								textCapitalization: TextCapitalization.characters,
								decoration: const InputDecoration(
									labelText: "Código",
									border: OutlineInputBorder(),
								),
								validator: (v) {
									if (v == null || v.trim().isEmpty) {
										return "Ingresá el código";
									}
									return null;
								},
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
								controller: _descripcionEmpresa,
								textCapitalization: TextCapitalization.sentences,
								maxLines: 3,
								decoration: const InputDecoration(
									labelText: "Descripción empresa",
									border: OutlineInputBorder(),
								),
								validator: (v) {
									if (v == null || v.trim().isEmpty) {
										return "Ingresá la descripción empresa";
									}
									return null;
								},
							),
							const SizedBox(height: 12),
							TextFormField(
								controller: _descripcionFabricante,
								textCapitalization: TextCapitalization.sentences,
								maxLines: 3,
								decoration: const InputDecoration(
									labelText: "Descripción fabricante",
									border: OutlineInputBorder(),
								),
								validator: (v) {
									if (v == null || v.trim().isEmpty) {
										return "Ingresá la descripción fabricante";
									}
									return null;
								},
							),
							const SizedBox(height: 12),
							TextFormField(
								controller: _categoria,
								textCapitalization: TextCapitalization.words,
								decoration: const InputDecoration(
									labelText: "Categoría",
									border: OutlineInputBorder(),
								),
								validator: (v) {
									if (v == null || v.trim().isEmpty) {
										return "Ingresá la categoría";
									}
									return null;
								},
							),
							const SizedBox(height: 12),
							TextFormField(
								controller: _marca,
								textCapitalization: TextCapitalization.words,
								decoration: const InputDecoration(
									labelText: "Marca",
									border: OutlineInputBorder(),
								),
								validator: (v) {
									if (v == null || v.trim().isEmpty) {
										return "Ingresá la marca";
									}
									return null;
								},
							),
							const SizedBox(height: 12),
							TextFormField(
								controller: _minimo,
								keyboardType: TextInputType.number,
								inputFormatters: [FilteringTextInputFormatter.digitsOnly],
								decoration: const InputDecoration(
									labelText: "Cantidad mínima (alerta bajo stock)",
									border: OutlineInputBorder(),
								),
								validator: (v) {
									final n = int.tryParse((v ?? "").trim());
									if (n == null || n < 0) return "Mínimo ≥ 0";
									return null;
								},
							),
							const SizedBox(height: 12),
							TextFormField(
								controller: _maximo,
								keyboardType: TextInputType.number,
								inputFormatters: [FilteringTextInputFormatter.digitsOnly],
								decoration: const InputDecoration(
									labelText: "Cantidad máxima (alerta alto stock)",
									border: OutlineInputBorder(),
								),
								validator: (v) {
									final n = int.tryParse((v ?? "").trim());
									if (n == null || n < 0) return "Máximo ≥ 0";
									final min = int.tryParse(_minimo.text.trim());
									if (min != null && n > 0 && min > n) {
										return "Máximo ≥ mínimo";
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
	const _EstadoStockChip({required this.level});

	final StockAlertLevel level;

	@override
	Widget build(BuildContext context) {
		final String text;
		final Color bg;
		switch (level) {
			case StockAlertLevel.bajo:
				text = "BAJO STOCK";
				bg = AppTokens.redAction;
			case StockAlertLevel.alto:
				text = "ALTO STOCK";
				bg = Colors.orange.shade800;
			case StockAlertLevel.ok:
				text = "OK";
				bg = AppTokens.statusOk;
		}
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
