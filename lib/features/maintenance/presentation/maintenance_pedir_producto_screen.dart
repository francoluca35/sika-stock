import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/presentation/widgets/auth_field_styles.dart";
import "../../orders/presentation/widgets/mobile_sheet_select_field.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "../application/maintenance_my_requests_provider.dart";
import "../domain/maintenance_product_request.dart";

/// Formulario **Pedir producto** (etapa 2 rol mantenimiento).
class MaintenancePedirProductoScreen extends ConsumerStatefulWidget {
	const MaintenancePedirProductoScreen({super.key});

	static const List<String> tiposPedido = [
		"Normal",
		"Urgente",
		"Programado",
	];

	static const List<String> tiposProducto = [
		"Materiales",
		"Herramientas",
		"Repuestos",
		"Consumibles",
		"Otro",
	];

	@override
	ConsumerState<MaintenancePedirProductoScreen> createState() =>
			_MaintenancePedirProductoScreenState();
}

class _MaintenancePedirProductoScreenState
		extends ConsumerState<MaintenancePedirProductoScreen> {
	final _formKey = GlobalKey<FormState>();
	final _cantidadCtrl = TextEditingController();
	final _destinoCtrl = TextEditingController();

	String? _tipoPedido;
	String? _tipoProducto;
	bool _loading = false;

	@override
	void dispose() {
		_cantidadCtrl.dispose();
		_destinoCtrl.dispose();
		super.dispose();
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _loading = true);
		await Future<void>.delayed(const Duration(milliseconds: 350));
		if (!mounted) return;

		final cant = int.parse(_cantidadCtrl.text.trim());
		final req = MaintenanceProductRequest(
			id: DateTime.now().millisecondsSinceEpoch.toString(),
			tipoPedido: _tipoPedido!,
			cantidad: cant,
			tipoProducto: _tipoProducto!,
			destino: _destinoCtrl.text.trim(),
			createdAt: DateTime.now(),
		);
		ref.read(maintenanceMyRequestsProvider.notifier).registrar(req);

		setState(() => _loading = false);

		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					"Pedido registrado: $cant u. · $_tipoProducto · ${req.destino}",
				),
			),
		);
		if (context.canPop()) {
			context.pop();
		} else {
			context.go("/home");
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "PEDIR PRODUCTO",
						onBack: () {
							if (context.canPop()) {
								context.pop();
							} else {
								context.go("/home");
							}
						},
					),
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
														"TIPO DE PEDIDO",
														style: AuthFieldStyles.labelAbove,
													),
												),
												const SizedBox(height: 8),
												MobileSheetSelectFormField<String>(
													value: _tipoPedido,
													options: MaintenancePedirProductoScreen.tiposPedido,
													labelOf: (t) => t,
													hintText: "Seleccionar…",
													prefixIcon: Icons.assignment_outlined,
													title: "Tipo de pedido",
													enabled: !_loading,
													onChanged: (v) => setState(() => _tipoPedido = v),
													validator: (v) => v == null ? "Elegí un tipo" : null,
												),
												const SizedBox(height: 18),
												Align(
													alignment: Alignment.centerLeft,
													child: Text(
														"CANTIDAD PRODUCTOS",
														style: AuthFieldStyles.labelAbove,
													),
												),
												const SizedBox(height: 8),
												TextFormField(
													controller: _cantidadCtrl,
													keyboardType: TextInputType.number,
													inputFormatters: [
														FilteringTextInputFormatter.digitsOnly,
													],
													enabled: !_loading,
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
														"TIPO DE PRODUCTO",
														style: AuthFieldStyles.labelAbove,
													),
												),
												const SizedBox(height: 8),
												MobileSheetSelectFormField<String>(
													value: _tipoProducto,
													options: MaintenancePedirProductoScreen.tiposProducto,
													labelOf: (t) => t,
													hintText: "Seleccionar…",
													prefixIcon: Icons.category_outlined,
													title: "Tipo de producto",
													enabled: !_loading,
													onChanged: (v) => setState(() => _tipoProducto = v),
													validator: (v) => v == null ? "Elegí un tipo" : null,
												),
												const SizedBox(height: 18),
												Align(
													alignment: Alignment.centerLeft,
													child: Text(
														"PARA DÓNDE ES",
														style: AuthFieldStyles.labelAbove,
													),
												),
												const SizedBox(height: 8),
												TextFormField(
													controller: _destinoCtrl,
													textCapitalization: TextCapitalization.sentences,
													enabled: !_loading,
													decoration: AuthFieldStyles.outline(
														hintText: "Ingrese destino",
														prefixIcon: Icons.place_outlined,
													),
													validator: (v) {
														if ((v ?? "").trim().length < 2) {
															return "Requerido";
														}
														return null;
													},
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
																: const Row(
																		mainAxisAlignment: MainAxisAlignment.center,
																		mainAxisSize: MainAxisSize.min,
																		children: [
																			Text(
																				"ENVIAR",
																				style: TextStyle(
																					fontWeight: FontWeight.bold,
																					letterSpacing: 0.8,
																				),
																			),
																			SizedBox(width: 10),
																			Icon(Icons.send_rounded, size: 22),
																		],
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
