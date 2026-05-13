import "dart:math";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../../auth/presentation/widgets/auth_field_styles.dart";
import "../../../orders/presentation/widgets/mobile_sheet_select_field.dart";
import "../../application/stock_categories_provider.dart";
import "../../application/supervisor_stock_catalog_provider.dart";

/// Formulario de alta de stock: nombre, **n° producto** (manual o aleatorio), cantidad, categoría.
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
	final _nombreCtrl = TextEditingController();
	final _numeroProductoCtrl = TextEditingController();
	final _cantidadCtrl = TextEditingController();

	String? _categoria;
	bool _loading = false;

	/// Código legible tipo `PRD-X7K2M9NA` (sin O/0 ni I/1 para evitar confusiones).
	static String generarNumeroProductoAleatorio() {
		const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
		final r = Random();
		final sb = StringBuffer("PRD-");
		for (var i = 0; i < 8; i++) {
			sb.write(chars[r.nextInt(chars.length)]);
		}
		return sb.toString();
	}

	@override
	void dispose() {
		_nombreCtrl.dispose();
		_numeroProductoCtrl.dispose();
		_cantidadCtrl.dispose();
		super.dispose();
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;
		final cant = int.tryParse(_cantidadCtrl.text.trim());
		if (cant == null || cant < 1 || _categoria == null) return;

		setState(() => _loading = true);
		try {
			final nombre = _nombreCtrl.text.trim();
			final nro = _numeroProductoCtrl.text.trim();
			final codigo = nro.isEmpty ? null : nro;
			final cat = _categoria!;
			await ref.read(stockCatalogRepositoryProvider).insert(
						nombre: nombre,
						categoria: cat,
						cantidad: cant,
						codigo: codigo,
					);
			ref.invalidate(supervisorStockCatalogProvider);
			if (!mounted) return;
			final nroTxt = codigo != null ? " · N° $codigo" : "";
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						"Stock cargado: $nombre$nroTxt · $cant u. · $cat",
					),
				),
			);
			_nombreCtrl.clear();
			_numeroProductoCtrl.clear();
			_cantidadCtrl.clear();
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
								Align(
									alignment: Alignment.centerLeft,
									child: Text(
										"NOMBRE DEL PRODUCTO",
										style: AuthFieldStyles.labelAbove,
									),
								),
								const SizedBox(height: 8),
								TextFormField(
									controller: _nombreCtrl,
									textCapitalization: TextCapitalization.sentences,
									enabled: !_loading,
									decoration: AuthFieldStyles.outline(
										hintText: "Ingrese nombre del producto",
										prefixIcon: Icons.label_outline,
									),
									validator: (v) {
										if ((v ?? "").trim().length < 2) {
											return "Requerido";
										}
										return null;
									},
								),
								const SizedBox(height: 18),
								Align(
									alignment: Alignment.centerLeft,
									child: Text(
										"N° PRODUCTO",
										style: AuthFieldStyles.labelAbove,
									),
								),
								const SizedBox(height: 8),
								Row(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Expanded(
											child: TextFormField(
												controller: _numeroProductoCtrl,
												enabled: !_loading,
												textCapitalization: TextCapitalization.characters,
												decoration: AuthFieldStyles.outline(
													hintText: "Ingresá el número o tocá «Aleatorio»",
													prefixIcon: Icons.tag_outlined,
												),
												validator: (v) {
													final t = (v ?? "").trim();
													if (t.isEmpty) return null;
													if (t.length < 2) {
														return "Mínimo 2 caracteres";
													}
													if (t.length > 64) {
														return "Máximo 64 caracteres";
													}
													return null;
												},
											),
										),
										const SizedBox(width: 8),
										Padding(
											padding: const EdgeInsets.only(top: 2),
											child: OutlinedButton.icon(
												onPressed: _loading
														? null
														: () {
																setState(() {
																	_numeroProductoCtrl.text =
																			generarNumeroProductoAleatorio();
																});
															},
												icon: const Icon(Icons.casino_outlined, size: 18),
												label: const Text("Aleatorio"),
												style: OutlinedButton.styleFrom(
													foregroundColor: Colors.black87,
													padding: const EdgeInsets.symmetric(
														horizontal: 12,
														vertical: 14,
													),
												),
											),
										),
									],
								),
								const SizedBox(height: 18),
								Align(
									alignment: Alignment.centerLeft,
									child: Text(
										"CANTIDAD",
										style: AuthFieldStyles.labelAbove,
									),
								),
								const SizedBox(height: 8),
								TextFormField(
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
								const SizedBox(height: 18),
								Align(
									alignment: Alignment.centerLeft,
									child: Text(
										"CATEGORÍA",
										style: AuthFieldStyles.labelAbove,
									),
								),
								const SizedBox(height: 8),
								MobileSheetSelectFormField<String>(
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
