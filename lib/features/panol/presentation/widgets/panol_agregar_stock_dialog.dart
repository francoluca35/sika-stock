import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../../auth/presentation/widgets/auth_field_styles.dart";
import "../../../orders/presentation/widgets/mobile_sheet_select_field.dart";
import "../../../stock/application/stock_categories_provider.dart";
import "../../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../../stock/domain/stock_product.dart";
import "../../../supervisor/application/maintenance_stock_similarity.dart"
		show esCoincidenciaParcial;
import "../../../supervisor/domain/maintenance_order.dart";

/// Resultado: ítem de inventario y cantidad registrada en pañol.
typedef PanolAgregarStockResult = ({String stockItemId, int cantidad});

Future<PanolAgregarStockResult?> showPanolAgregarStockDialog({
	required BuildContext context,
	required MaintenanceOrder order,
	required StockProduct? matchedProduct,
	int matchScore = 0,
}) {
	return showDialog<PanolAgregarStockResult>(
		context: context,
		builder: (ctx) => _PanolAgregarStockDialog(
			order: order,
			matchedProduct: matchedProduct,
			matchScore: matchScore,
		),
	);
}

class _PanolAgregarStockDialog extends ConsumerStatefulWidget {
	const _PanolAgregarStockDialog({
		required this.order,
		required this.matchedProduct,
		required this.matchScore,
	});

	final MaintenanceOrder order;
	final StockProduct? matchedProduct;
	final int matchScore;

	@override
	ConsumerState<_PanolAgregarStockDialog> createState() =>
			_PanolAgregarStockDialogState();
}

class _PanolAgregarStockDialogState extends ConsumerState<_PanolAgregarStockDialog> {
	final _formKey = GlobalKey<FormState>();
	final _codigoCtrl = TextEditingController();
	final _nombreCtrl = TextEditingController();
	final _descripcionEmpresaCtrl = TextEditingController();
	final _descripcionFabricanteCtrl = TextEditingController();
	final _marcaCtrl = TextEditingController();
	final _cantidadCtrl = TextEditingController();

	String? _categoria;
	bool _loading = false;

	/// Si hay sugerencia de catálogo, arranca usándola; el usuario puede pasar a alta nueva.
	late bool _usarCoincidencia;

	bool get _tieneSugerencia => widget.matchedProduct != null;

	bool get _esCatalogo => _tieneSugerencia && _usarCoincidencia;

	bool get _esReposicionSinStock =>
			_esCatalogo && widget.matchedProduct!.cantidad <= 0;

	bool get _esParcial =>
			_tieneSugerencia && esCoincidenciaParcial(widget.matchScore);

	@override
	void initState() {
		super.initState();
		final mo = widget.order;
		_nombreCtrl.text = mo.producto.trim();
		_usarCoincidencia = _tieneSugerencia;
		_syncCantidadInicial();
	}

	void _syncCantidadInicial() {
		final mo = widget.order;
		if (_esCatalogo) {
			final p = widget.matchedProduct!;
			_cantidadCtrl.text =
					p.cantidad > 0 ? p.cantidad.toString() : mo.quantity.toString();
		} else {
			_cantidadCtrl.text = mo.quantity.toString();
		}
	}

	void _pasarAProductoNuevo() {
		setState(() {
			_usarCoincidencia = false;
			_nombreCtrl.text = widget.order.producto.trim();
			_syncCantidadInicial();
		});
	}

	void _usarSugerenciaCatalogo() {
		setState(() {
			_usarCoincidencia = true;
			_syncCantidadInicial();
		});
	}

	@override
	void dispose() {
		_codigoCtrl.dispose();
		_nombreCtrl.dispose();
		_descripcionEmpresaCtrl.dispose();
		_descripcionFabricanteCtrl.dispose();
		_marcaCtrl.dispose();
		_cantidadCtrl.dispose();
		super.dispose();
	}

	Future<void> _guardar() async {
		if (!_formKey.currentState!.validate()) return;
		final cant = int.tryParse(_cantidadCtrl.text.trim());
		if (cant == null || cant < 1) return;

		setState(() => _loading = true);
		try {
			if (_esCatalogo) {
				final id = widget.matchedProduct!.id;
				if (!mounted) return;
				Navigator.pop(
					context,
					(stockItemId: id, cantidad: cant),
				);
				return;
			}

			if (_categoria == null) {
				setState(() => _loading = false);
				return;
			}

			final inserted = await ref.read(stockCatalogRepositoryProvider).insert(
						codigo: _codigoCtrl.text.trim(),
						nombre: _nombreCtrl.text.trim(),
						descripcionEmpresa: _descripcionEmpresaCtrl.text.trim(),
						descripcionFabricante: _descripcionFabricanteCtrl.text.trim(),
						categoria: _categoria!,
						marca: _marcaCtrl.text.trim(),
						cantidad: cant,
						cantidadMinima: 0,
						cantidadMaxima: 0,
					);
			if (!mounted) return;
			Navigator.pop(
				context,
				(stockItemId: inserted.id, cantidad: cant),
			);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo guardar: $e")),
			);
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	Widget _labeledField({required String label, required Widget field}) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			mainAxisSize: MainAxisSize.min,
			children: [
				Align(
					alignment: Alignment.centerLeft,
					child: Text(label, style: AuthFieldStyles.labelAbove),
				),
				const SizedBox(height: 8),
				field,
			],
		);
	}

	Widget _bannerSugerencia({required bool destacada}) {
		final match = widget.matchedProduct!;
		final parcial = _esParcial;
		final sinStock = match.cantidad <= 0;
		final colorBg = parcial || sinStock
				? Colors.orange.shade50
				: AppTokens.statusOk.withValues(alpha: 0.15);
		final colorBorder = parcial || sinStock
				? Colors.orange.shade700
				: AppTokens.statusOk.withValues(alpha: 0.5);
		final titulo = parcial
				? "Coincidencia parcial en catálogo"
				: (sinStock
						? "Producto en catálogo · sin stock"
						: "Producto en catálogo");

		return Container(
			padding: const EdgeInsets.all(12),
			decoration: BoxDecoration(
				color: colorBg,
				borderRadius: BorderRadius.circular(AppTokens.radiusMd),
				border: Border.all(color: colorBorder),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						titulo,
						style: TextStyle(
							fontWeight: FontWeight.w800,
							fontSize: 12,
							color: parcial || sinStock
									? Colors.orange.shade900
									: Colors.black87,
						),
					),
					const SizedBox(height: 4),
					Text(
						"${match.codigo ?? "—"} · ${match.nombre}",
						style: const TextStyle(fontWeight: FontWeight.w600),
					),
					Text(
						sinStock
								? "Stock actual: 0 u."
								: "Stock actual en sistema: ${match.cantidad} u.",
						style: TextStyle(
							fontSize: 12,
							color: Colors.grey.shade700,
						),
					),
					if (parcial) ...[
						const SizedBox(height: 6),
						Text(
							"Puede no ser el repuesto exacto del pedido. "
							"Si no coincide, creá un producto nuevo.",
							style: TextStyle(
								fontSize: 12,
								height: 1.3,
								color: Colors.orange.shade900,
							),
						),
					],
					if (destacada) ...[
						const SizedBox(height: 10),
						SizedBox(
							width: double.infinity,
							child: OutlinedButton.icon(
								onPressed: _loading ? null : _pasarAProductoNuevo,
								icon: const Icon(Icons.add_box_outlined, size: 18),
								label: const Text(
									"No es este · crear producto nuevo",
									textAlign: TextAlign.center,
								),
								style: OutlinedButton.styleFrom(
									foregroundColor: Colors.orange.shade900,
									side: BorderSide(color: Colors.orange.shade700),
									padding: const EdgeInsets.symmetric(vertical: 10),
								),
							),
						),
					] else ...[
						const SizedBox(height: 8),
						TextButton(
							onPressed: _loading ? null : _usarSugerenciaCatalogo,
							child: const Text("Usar esta coincidencia"),
						),
					],
				],
			),
		);
	}

	Widget _formularioProductoNuevo(List<String> categorias) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.stretch,
			children: [
				if (_tieneSugerencia) ...[
					_bannerSugerencia(destacada: false),
					const SizedBox(height: 12),
				] else
					Container(
						padding: const EdgeInsets.all(12),
						decoration: BoxDecoration(
							color: Colors.orange.shade50,
							borderRadius: BorderRadius.circular(AppTokens.radiusMd),
							border: Border.all(color: Colors.orange.shade700),
						),
						child: Text(
							"No hay coincidencia en el catálogo. "
							"Completá el formulario para dar de alta el producto nuevo "
							"y registrar la cantidad en pañol.",
							style: TextStyle(
								fontSize: 13,
								color: Colors.orange.shade900,
								height: 1.35,
								fontWeight: FontWeight.w600,
							),
						),
					),
				if (_tieneSugerencia) ...[
					Text(
						"Alta nueva según el pedido: «${widget.order.producto.trim()}»",
						style: TextStyle(
							fontSize: 13,
							fontWeight: FontWeight.w600,
							color: Colors.grey.shade800,
							height: 1.3,
						),
					),
					const SizedBox(height: 12),
				] else
					const SizedBox(height: 14),
				_labeledField(
					label: "CÓDIGO",
					field: TextFormField(
						controller: _codigoCtrl,
						textCapitalization: TextCapitalization.characters,
						decoration: AuthFieldStyles.outline(
							hintText: "Código del producto",
							prefixIcon: Icons.tag_outlined,
						),
						validator: (v) =>
								(v ?? "").trim().isEmpty ? "El código es obligatorio" : null,
					),
				),
				const SizedBox(height: 12),
				_labeledField(
					label: "NOMBRE",
					field: TextFormField(
						controller: _nombreCtrl,
						decoration: AuthFieldStyles.outline(
							hintText: "Nombre del producto",
							prefixIcon: Icons.label_outline,
						),
						validator: (v) =>
								(v ?? "").trim().isEmpty ? "El nombre es obligatorio" : null,
					),
				),
				const SizedBox(height: 12),
				_labeledField(
					label: "DESCRIPCIÓN EMPRESA",
					field: TextFormField(
						controller: _descripcionEmpresaCtrl,
						maxLines: 2,
						decoration: AuthFieldStyles.outline(
							hintText: "Descripción empresa",
							prefixIcon: Icons.description_outlined,
						),
					),
				),
				const SizedBox(height: 12),
				_labeledField(
					label: "DESCRIPCIÓN FABRICANTE",
					field: TextFormField(
						controller: _descripcionFabricanteCtrl,
						maxLines: 2,
						decoration: AuthFieldStyles.outline(
							hintText: "Descripción fabricante",
							prefixIcon: Icons.factory_outlined,
						),
					),
				),
				const SizedBox(height: 12),
				_labeledField(
					label: "CATEGORÍA",
					field: MobileSheetSelectFormField<String>(
						value: _categoria,
						options: categorias,
						labelOf: (c) => c,
						hintText: "Seleccionar…",
						prefixIcon: Icons.category_outlined,
						title: "Categoría",
						onChanged: (v) => setState(() => _categoria = v),
						validator: (v) => v == null ? "Elegí una categoría" : null,
					),
				),
				const SizedBox(height: 12),
				_labeledField(
					label: "MARCA",
					field: TextFormField(
						controller: _marcaCtrl,
						decoration: AuthFieldStyles.outline(
							hintText: "Marca",
							prefixIcon: Icons.branding_watermark_outlined,
						),
					),
				),
				const SizedBox(height: 12),
				_labeledField(
					label: "CANTIDAD EN PAÑOL",
					field: TextFormField(
						controller: _cantidadCtrl,
						keyboardType: TextInputType.number,
						inputFormatters: [FilteringTextInputFormatter.digitsOnly],
						decoration: AuthFieldStyles.outline(
							hintText: "Cantidad",
							prefixIcon: Icons.numbers,
						),
						validator: (v) {
							final n = int.tryParse((v ?? "").trim());
							if (n == null || n < 1) {
								return "Ingresá una cantidad válida";
							}
							return null;
						},
					),
				),
			],
		);
	}

	@override
	Widget build(BuildContext context) {
		final mo = widget.order;

		final titulo = !_tieneSugerencia
				? "Cargar producto nuevo"
				: (!_usarCoincidencia
						? "Cargar producto nuevo"
						: (_esReposicionSinStock
								? "Reponer stock en pañol"
								: (_esParcial
										? "Revisar coincidencia"
										: "Agregar stock en pañol")));

		return AlertDialog(
			title: Text(titulo),
			content: SizedBox(
				width: 420,
				child: Form(
					key: _formKey,
					child: SingleChildScrollView(
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Text(
									"${mo.numeroOrden} · pedido ${mo.quantity} u.",
									style: TextStyle(
										fontSize: 13,
										color: Colors.grey.shade700,
										fontWeight: FontWeight.w600,
									),
								),
								const SizedBox(height: 4),
								Text(
									"Pedido: ${mo.producto.trim()}",
									style: TextStyle(
										fontSize: 12,
										color: Colors.grey.shade700,
										height: 1.3,
									),
								),
								const SizedBox(height: 12),
								if (_esCatalogo) ...[
									_bannerSugerencia(destacada: true),
									const SizedBox(height: 14),
									_labeledField(
										label: _esReposicionSinStock
												? "CANTIDAD A REPONER"
												: "CANTIDAD DISPONIBLE EN PAÑOL",
										field: TextFormField(
											controller: _cantidadCtrl,
											keyboardType: TextInputType.number,
											inputFormatters: [
												FilteringTextInputFormatter.digitsOnly,
											],
											decoration: AuthFieldStyles.outline(
												hintText: _esReposicionSinStock
														? "Cantidad a reponer"
														: "Ingrese cantidad",
												prefixIcon: Icons.numbers,
											),
											validator: (v) {
												final n = int.tryParse((v ?? "").trim());
												if (n == null || n < 1) {
													return "Ingresá una cantidad válida";
												}
												return null;
											},
										),
									),
								] else
									ref.watch(stockCategoriesProvider).when(
												data: (cats) {
													final categorias = cats.map((c) => c.name).toList();
													return _formularioProductoNuevo(categorias);
												},
												loading: () => const Padding(
													padding: EdgeInsets.symmetric(vertical: 16),
													child: Center(child: CircularProgressIndicator()),
												),
												error: (_, __) => const Text(
													"No se pudieron cargar las categorías.",
												),
											),
							],
						),
					),
				),
			),
			actions: [
				TextButton(
					onPressed: _loading ? null : () => Navigator.pop(context),
					child: const Text("Cancelar"),
				),
				FilledButton(
					onPressed: _loading ? null : _guardar,
					child: _loading
							? const SizedBox(
									width: 18,
									height: 18,
									child: CircularProgressIndicator(strokeWidth: 2),
								)
							: Text(
									_esCatalogo ? "Guardar y avisar" : "Crear y avisar",
								),
				),
			],
		);
	}
}
