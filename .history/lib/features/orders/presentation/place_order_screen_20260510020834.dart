import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/presentation/widgets/auth_field_styles.dart";
import "../domain/order_priority.dart";
import "widgets/order_hub_bottom_bar.dart";

/// Formulario **Hacer pedido** (potenciamiento) según mockup.
class PlaceOrderScreen extends StatefulWidget {
	const PlaceOrderScreen({super.key});

	@override
	State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
	final _formKey = GlobalKey<FormState>();
	final _nombreCtrl = TextEditingController();
	final _cantidadCtrl = TextEditingController();
	final _destinoCtrl = TextEditingController();

	String? _tipoProducto;
	OrderPriority? _prioridad;
	bool _loading = false;

	static const List<String> _tiposProducto = [
		"Materiales",
		"Herramientas",
		"Repuestos",
		"Consumibles",
		"Otro",
	];

	@override
	void dispose() {
		_nombreCtrl.dispose();
		_cantidadCtrl.dispose();
		_destinoCtrl.dispose();
		super.dispose();
	}

	void _soon(BuildContext context, String msg) {
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text("$msg — próximamente.")),
		);
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;

		setState(() => _loading = true);
		await Future<void>.delayed(const Duration(milliseconds: 400));
		if (!mounted) return;

		setState(() => _loading = false);
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					"Pedido preparado: ${_nombreCtrl.text.trim()} · ${_cantidadCtrl.text} · $_tipoProducto · ${_prioridad!.label} · ${_destinoCtrl.text.trim()}",
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final bottomInset = MediaQuery.paddingOf(context).bottom;

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					_PlaceOrderHeader(
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
														"TIPO DE PRODUCTO",
														style: AuthFieldStyles.labelAbove,
													),
												),
												const SizedBox(height: 8),
												DropdownButtonFormField<String>(
													value: _tipoProducto,
													decoration: AuthFieldStyles.outline(
														hintText: "Seleccionar…",
														prefixIcon: Icons.category_outlined,
													),
													items: [
														for (final t in _tiposProducto)
															DropdownMenuItem(value: t, child: Text(t)),
													],
													onChanged: _loading
														? null
														: (v) => setState(() => _tipoProducto = v),
													validator: (v) => v == null ? "Elegí un tipo" : null,
												),
												const SizedBox(height: 18),
												Align(
													alignment: Alignment.centerLeft,
													child: Text(
														"PRIORIDAD",
														style: AuthFieldStyles.labelAbove,
													),
												),
												const SizedBox(height: 8),
												DropdownButtonFormField<OrderPriority>(
													value: _prioridad,
													decoration: AuthFieldStyles.outline(
														hintText: "Seleccionar…",
														prefixIcon: Icons.flag_outlined,
													),
													items: [
														for (final p in OrderPriority.values)
															DropdownMenuItem(
																value: p,
																child: Text(p.label),
															),
													],
													onChanged: _loading
														? null
														: (v) => setState(() => _prioridad = v),
													validator: (v) => v == null ? "Elegí prioridad" : null,
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
					OrderHubBottomBar(
						bottomPadding: bottomInset,
						selectedIndex: 0,
						onPedido: () {},
						onHistorial: () => _soon(context, "Historial de pedidos"),
						onPerfil: () => _soon(context, "Perfil"),
					),
				],
			),
		);
	}
}

class _PlaceOrderHeader extends StatelessWidget {
	const _PlaceOrderHeader({required this.onBack});

	final VoidCallback onBack;

	@override
	Widget build(BuildContext context) {
		return Container(
			width: double.infinity,
			decoration: BoxDecoration(
				color: AppTokens.yellowHeader,
				boxShadow: [
					BoxShadow(
						color: Colors.black.withValues(alpha: 0.08),
						blurRadius: 10,
						offset: const Offset(0, 3),
					),
				],
			),
			child: SafeArea(
				bottom: false,
				child: SizedBox(
					height: 56,
					child: Stack(
						alignment: Alignment.center,
						children: [
							Align(
								alignment: Alignment.centerLeft,
								child: IconButton(
									icon: const Icon(Icons.arrow_back, color: Colors.black87),
									onPressed: onBack,
								),
							),
							const Text(
								"POTENCIAMIENTO",
								style: TextStyle(
									fontWeight: FontWeight.bold,
									fontSize: 17,
									letterSpacing: 0.8,
									color: Colors.black87,
								),
							),
						],
					),
				),
			),
		);
	}
}
