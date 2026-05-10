import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/presentation/widgets/auth_field_styles.dart";
import "../../orders/presentation/widgets/mobile_sheet_select_field.dart";
import "../application/stock_categories_provider.dart";
import "widgets/stock_screen_header.dart";

/// Formulario para registrar entrada de stock (nombre, cantidad, categoría).
class AddStockScreen extends ConsumerStatefulWidget {
	const AddStockScreen({super.key});

	@override
	ConsumerState<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends ConsumerState<AddStockScreen> {
	final _formKey = GlobalKey<FormState>();
	final _nombreCtrl = TextEditingController();
	final _cantidadCtrl = TextEditingController();

	String? _categoria;
	bool _loading = false;

	@override
	void dispose() {
		_nombreCtrl.dispose();
		_cantidadCtrl.dispose();
		super.dispose();
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;

		setState(() => _loading = true);
		await Future<void>.delayed(const Duration(milliseconds: 350));
		if (!mounted) return;

		setState(() => _loading = false);

		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					"Stock cargado: ${_nombreCtrl.text.trim()} · ${_cantidadCtrl.text} u. · $_categoria",
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final categorias = ref.watch(stockCategoriesProvider);
		if (_categoria != null && !categorias.contains(_categoria)) {
			WidgetsBinding.instance.addPostFrameCallback((_) {
				if (mounted) setState(() => _categoria = null);
			});
		}

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "AGREGAR STOCK",
						onBack: () {
							if (context.canPop()) {
								context.pop();
							} else {
								context.go("/stock");
							}
						},
					),
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
							child: Center(
								child: ConstrainedBox(
									constraints: const BoxConstraints(maxWidth: 480),
									child: Form(
										key: _formKey,
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.stretch,
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
														"CANTIDAD",
														style: AuthFieldStyles.labelAbove,
													),
												),
												const SizedBox(height: 8),
												TextFormField(
													controller: _cantidadCtrl,
													keyboardType: TextInputType.number,
													enabled: !_loading,
													inputFormatters: [
														FilteringTextInputFormatter.digitsOnly,
													],
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
													validator: (v) =>
															v == null ? "Elegí una categoría" : null,
												),
												const SizedBox(height: 28),
												SizedBox(
													height: 52,
													child: FilledButton(
														style: FilledButton.styleFrom(
															backgroundColor: AppTokens.redAction,
															foregroundColor: Colors.white,
															shape: RoundedRectangleBorder(
																borderRadius: BorderRadius.circular(
																	AppTokens.radiusMd,
																),
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
																: const Text(
																		"GUARDAR",
																		style: TextStyle(
																			fontWeight: FontWeight.bold,
																			letterSpacing: 0.8,
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
					),
				],
			),
		);
	}
}
