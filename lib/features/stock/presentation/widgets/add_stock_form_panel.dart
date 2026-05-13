import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../../auth/presentation/widgets/auth_field_styles.dart";
import "../../../orders/presentation/widgets/mobile_sheet_select_field.dart";
import "../../application/stock_categories_provider.dart";
import "../../application/supervisor_stock_catalog_provider.dart";

/// Formulario de alta de stock: código (manual), nombre, descripciones, categoría, marca y cantidad.
///
/// [onSubmitSuccess] se llama después de un guardado exitoso (p. ej. para cerrar un panel).
class AddStockFormPanel extends ConsumerStatefulWidget {
	const AddStockFormPanel({
		super.key,
		this.padding = EdgeInsets.zero,
		this.onSubmitSuccess,
		this.submitLabel = "GUARDAR",
	});

	final EdgeInsetsGeometry padding;
	final VoidCallback? onSubmitSuccess;
	final String submitLabel;

	@override
	ConsumerState<AddStockFormPanel> createState() => _AddStockFormPanelState();
}

class _AddStockFormPanelState extends ConsumerState<AddStockFormPanel> {
	final _formKey = GlobalKey<FormState>();
	final _codigoCtrl = TextEditingController();
	final _nombreCtrl = TextEditingController();
	final _descripcionEmpresaCtrl = TextEditingController();
	final _descripcionFabricanteCtrl = TextEditingController();
	final _marcaCtrl = TextEditingController();
	final _cantidadCtrl = TextEditingController();
	final _minimoCtrl = TextEditingController();
	final _maximoCtrl = TextEditingController();

	String? _categoria;
	bool _loading = false;

	@override
	void dispose() {
		_codigoCtrl.dispose();
		_nombreCtrl.dispose();
		_descripcionEmpresaCtrl.dispose();
		_descripcionFabricanteCtrl.dispose();
		_marcaCtrl.dispose();
		_cantidadCtrl.dispose();
		_minimoCtrl.dispose();
		_maximoCtrl.dispose();
		super.dispose();
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;
		final cant = int.tryParse(_cantidadCtrl.text.trim());
		final min = int.tryParse(_minimoCtrl.text.trim());
		final max = int.tryParse(_maximoCtrl.text.trim());
		if (cant == null || cant < 1 || _categoria == null) return;
		if (min == null || min < 0 || max == null || max < 0) return;
		if (max > 0 && min > max) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("El mínimo no puede ser mayor que el máximo.")),
			);
			return;
		}

		setState(() => _loading = true);
		try {
			final codigo = _codigoCtrl.text.trim();
			final nombre = _nombreCtrl.text.trim();
			final descripcionEmpresa = _descripcionEmpresaCtrl.text.trim();
			final descripcionFabricante = _descripcionFabricanteCtrl.text.trim();
			final marca = _marcaCtrl.text.trim();
			final cat = _categoria!;
			await ref.read(stockCatalogRepositoryProvider).insert(
						codigo: codigo,
						nombre: nombre,
						descripcionEmpresa: descripcionEmpresa,
						descripcionFabricante: descripcionFabricante,
						categoria: cat,
						marca: marca,
						cantidad: cant,
						cantidadMinima: min,
						cantidadMaxima: max,
					);
			ref.invalidate(supervisorStockCatalogProvider);
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						"Stock cargado: $codigo · $nombre · $cant u. · $cat",
					),
				),
			);
			_codigoCtrl.clear();
			_nombreCtrl.clear();
			_descripcionEmpresaCtrl.clear();
			_descripcionFabricanteCtrl.clear();
			_marcaCtrl.clear();
			_cantidadCtrl.clear();
			_minimoCtrl.clear();
			_maximoCtrl.clear();
			setState(() => _categoria = null);
			widget.onSubmitSuccess?.call();
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo guardar: $e")),
			);
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	Widget _labeledField({
		required String label,
		required Widget field,
	}) {
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

	String? _requiredText(String? v, {int minLen = 2, String? emptyMsg}) {
		final t = (v ?? "").trim();
		if (t.isEmpty) return emptyMsg ?? "Requerido";
		if (t.length < minLen) return "Mínimo $minLen caracteres";
		return null;
	}

	@override
	Widget build(BuildContext context) {
		final catAsync = ref.watch(stockCategoriesProvider);

		return Padding(
			padding: widget.padding,
			child: catAsync.when(
				loading: () => const Padding(
					padding: EdgeInsets.symmetric(vertical: 24),
					child: Center(child: CircularProgressIndicator()),
				),
				error: (e, _) => Padding(
					padding: const EdgeInsets.symmetric(vertical: 8),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Text(
								"No se pudieron cargar las categorías.\n$e",
								style: TextStyle(color: Colors.red.shade800, fontSize: 13),
							),
							const SizedBox(height: 12),
							FilledButton(
								onPressed: () => ref.invalidate(stockCategoriesProvider),
								child: const Text("Reintentar"),
							),
						],
					),
				),
				data: (cats) {
					final categorias = cats.map((c) => c.name).toList();
					if (_categoria != null && !categorias.contains(_categoria)) {
						WidgetsBinding.instance.addPostFrameCallback((_) {
							if (mounted) setState(() => _categoria = null);
						});
					}
					return Form(
						key: _formKey,
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							mainAxisSize: MainAxisSize.min,
							children: [
								_labeledField(
									label: "CÓDIGO",
									field: TextFormField(
										controller: _codigoCtrl,
										enabled: !_loading,
										textCapitalization: TextCapitalization.characters,
										decoration: AuthFieldStyles.outline(
											hintText: "Ingresá el código del producto",
											prefixIcon: Icons.tag_outlined,
										),
										validator: (v) {
											final t = (v ?? "").trim();
											if (t.isEmpty) return "Ingresá el código";
											if (t.length < 2) return "Mínimo 2 caracteres";
											if (t.length > 64) return "Máximo 64 caracteres";
											return null;
										},
									),
								),
								const SizedBox(height: 18),
								_labeledField(
									label: "NOMBRE DEL PRODUCTO",
									field: TextFormField(
										controller: _nombreCtrl,
										textCapitalization: TextCapitalization.sentences,
										enabled: !_loading,
										decoration: AuthFieldStyles.outline(
											hintText: "Ingrese nombre del producto",
											prefixIcon: Icons.label_outline,
										),
										validator: (v) => _requiredText(v),
									),
								),
								const SizedBox(height: 18),
								_labeledField(
									label: "DESCRIPCIÓN EMPRESA",
									field: TextFormField(
										controller: _descripcionEmpresaCtrl,
										textCapitalization: TextCapitalization.sentences,
										enabled: !_loading,
										maxLines: 3,
										decoration: AuthFieldStyles.outline(
											hintText: "Descripción según la empresa",
											prefixIcon: Icons.business_outlined,
										),
										validator: (v) => _requiredText(v),
									),
								),
								const SizedBox(height: 18),
								_labeledField(
									label: "DESCRIPCIÓN FABRICANTE",
									field: TextFormField(
										controller: _descripcionFabricanteCtrl,
										textCapitalization: TextCapitalization.sentences,
										enabled: !_loading,
										maxLines: 3,
										decoration: AuthFieldStyles.outline(
											hintText: "Descripción según el fabricante",
											prefixIcon: Icons.factory_outlined,
										),
										validator: (v) => _requiredText(v),
									),
								),
								const SizedBox(height: 18),
								_labeledField(
									label: "CATEGORÍA",
									field: MobileSheetSelectFormField<String>(
										value: _categoria,
										options: categorias,
										labelOf: (c) => c,
										hintText: "Seleccionar…",
										prefixIcon: Icons.category_outlined,
										title: "Categoría",
										enabled: !_loading,
										onChanged: (v) => setState(() => _categoria = v),
										validator: (v) => v == null ? "Elegí una categoría" : null,
									),
								),
								const SizedBox(height: 18),
								_labeledField(
									label: "MARCA",
									field: TextFormField(
										controller: _marcaCtrl,
										textCapitalization: TextCapitalization.words,
										enabled: !_loading,
										decoration: AuthFieldStyles.outline(
											hintText: "Ingrese la marca",
											prefixIcon: Icons.branding_watermark_outlined,
										),
										validator: (v) => _requiredText(v),
									),
								),
								const SizedBox(height: 18),
								_labeledField(
									label: "CANTIDAD",
									field: TextFormField(
										controller: _cantidadCtrl,
										keyboardType: TextInputType.number,
										enabled: !_loading,
										inputFormatters: [FilteringTextInputFormatter.digitsOnly],
										decoration: AuthFieldStyles.outline(
											hintText: "Ingrese cantidad",
											prefixIcon: Icons.numbers,
										),
										validator: (v) {
											final n = int.tryParse((v ?? "").trim());
											if (n == null || n < 1) {
												return "Indicá una cantidad válida";
											}
											return null;
										},
									),
								),
								const SizedBox(height: 18),
								_labeledField(
									label: "CANTIDAD MÍNIMA (ALERTA STOCK BAJO)",
									field: TextFormField(
										controller: _minimoCtrl,
										keyboardType: TextInputType.number,
										enabled: !_loading,
										inputFormatters: [FilteringTextInputFormatter.digitsOnly],
										decoration: AuthFieldStyles.outline(
											hintText: "Umbral mínimo (0 = sin alerta)",
											prefixIcon: Icons.trending_down_outlined,
										),
										validator: (v) {
											final n = int.tryParse((v ?? "").trim());
											if (n == null || n < 0) {
												return "Indicá un mínimo válido (≥ 0)";
											}
											return null;
										},
									),
								),
								const SizedBox(height: 18),
								_labeledField(
									label: "CANTIDAD MÁXIMA (ALERTA STOCK ALTO)",
									field: TextFormField(
										controller: _maximoCtrl,
										keyboardType: TextInputType.number,
										enabled: !_loading,
										inputFormatters: [FilteringTextInputFormatter.digitsOnly],
										decoration: AuthFieldStyles.outline(
											hintText: "Umbral máximo (0 = sin alerta)",
											prefixIcon: Icons.trending_up_outlined,
										),
										validator: (v) {
											final n = int.tryParse((v ?? "").trim());
											if (n == null || n < 0) {
												return "Indicá un máximo válido (≥ 0)";
											}
											final min = int.tryParse(_minimoCtrl.text.trim());
											if (min != null && n > 0 && min > n) {
												return "El máximo debe ser ≥ al mínimo";
											}
											return null;
										},
									),
								),
								const SizedBox(height: 28),
								SizedBox(
									height: 52,
									child: FilledButton(
										style: FilledButton.styleFrom(
											backgroundColor: AppTokens.redAction,
											foregroundColor: Colors.white,
											shape: RoundedRectangleBorder(
												borderRadius: BorderRadius.circular(AppTokens.radiusMd),
											),
										),
										onPressed: _loading ? null : _submit,
										child: _loading
												? const SizedBox(
														height: 22,
														width: 22,
														child: CircularProgressIndicator(
															strokeWidth: 2,
															color: Colors.white,
														),
													)
												: Text(
														widget.submitLabel,
														style: const TextStyle(
															fontWeight: FontWeight.bold,
															letterSpacing: 0.8,
														),
													),
									),
								),
							],
						),
					);
				},
			),
		);
	}
}
