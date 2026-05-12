import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/presentation/widgets/auth_field_styles.dart";
import "../application/stock_categories_provider.dart";
import "widgets/stock_screen_header.dart";

/// Alta y listado de categorías (editar / eliminar).
///
/// [fallbackLocation] cuando no hay historial para `pop` (p. ej. `/home` en Pañol).
class CategoriesScreen extends ConsumerStatefulWidget {
	const CategoriesScreen({
		super.key,
		this.fallbackLocation = "/stock",
	});

	final String fallbackLocation;

	@override
	ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
	final _formKey = GlobalKey<FormState>();
	final _nombreCtrl = TextEditingController();
	bool _loading = false;

	@override
	void dispose() {
		_nombreCtrl.dispose();
		super.dispose();
	}

	Future<void> _guardar() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _loading = true);
		await Future<void>.delayed(const Duration(milliseconds: 200));
		if (!mounted) return;

		final ok = ref.read(stockCategoriesProvider.notifier).addCategory(_nombreCtrl.text);
		setState(() => _loading = false);

		if (!mounted) return;
		if (ok) {
			_nombreCtrl.clear();
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Categoría guardada.")),
			);
		} else {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text("Ya existe una categoría con ese nombre."),
				),
			);
		}
	}

	Future<void> _editar(int index, String actual) async {
		final ctrl = TextEditingController(text: actual);
		final nuevo = await showDialog<String>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text("Editar categoría"),
				content: TextField(
					controller: ctrl,
					autofocus: true,
					decoration: const InputDecoration(
						border: OutlineInputBorder(),
						hintText: "Nombre",
					),
					textCapitalization: TextCapitalization.sentences,
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx),
						child: const Text("Cancelar"),
					),
					FilledButton(
						onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
						child: const Text("Guardar"),
					),
				],
			),
		);
		ctrl.dispose();

		if (nuevo == null || nuevo.length < 2 || !mounted) return;
		final ok = ref.read(stockCategoriesProvider.notifier).updateAt(index, nuevo);
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					ok
							? "Categoría actualizada."
							: "Ya existe otra categoría con ese nombre.",
				),
			),
		);
	}

	Future<void> _eliminar(int index, String nombre) async {
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text("Eliminar categoría"),
				content: Text("¿Eliminar «$nombre»?"),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text("Cancelar"),
					),
					FilledButton(
						style: FilledButton.styleFrom(
							backgroundColor: AppTokens.redAction,
							foregroundColor: Colors.white,
						),
						onPressed: () => Navigator.pop(ctx, true),
						child: const Text("Eliminar"),
					),
				],
			),
		);
		if (ok != true || !mounted) return;
		ref.read(stockCategoriesProvider.notifier).removeAt(index);
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(content: Text("Se eliminó «$nombre».")),
		);
	}

	@override
	Widget build(BuildContext context) {
		final categorias = ref.watch(stockCategoriesProvider);

		return Scaffold(
			backgroundColor: AppTokens.surfacePage,
			body: Column(
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					StockScreenHeader(
						title: "CATEGORÍAS",
						onBack: () {
							if (context.canPop()) {
								context.pop();
							} else {
								context.go(widget.fallbackLocation);
							}
						},
					),
					Expanded(
						child: SingleChildScrollView(
							padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
							child: Center(
								child: ConstrainedBox(
									constraints: const BoxConstraints(maxWidth: 480),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: [
											Form(
												key: _formKey,
												child: Column(
													crossAxisAlignment: CrossAxisAlignment.stretch,
													children: [
														Align(
															alignment: Alignment.centerLeft,
															child: Text(
																"NOMBRE DE LA CATEGORÍA",
																style: AuthFieldStyles.labelAbove,
															),
														),
														const SizedBox(height: 8),
														TextFormField(
															controller: _nombreCtrl,
															enabled: !_loading,
															textCapitalization: TextCapitalization.sentences,
															decoration: AuthFieldStyles.outline(
																hintText: "Ej. Seguridad e higiene",
																prefixIcon: Icons.label_outline,
															),
															validator: (v) {
																if ((v ?? "").trim().length < 2) {
																	return "Mínimo 2 caracteres";
																}
																return null;
															},
														),
														const SizedBox(height: 20),
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
																onPressed: _loading ? null : _guardar,
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
											const SizedBox(height: 28),
											Align(
												alignment: Alignment.centerLeft,
												child: Text(
													"CATEGORÍAS REGISTRADAS",
													style: AuthFieldStyles.labelAbove,
												),
											),
											const SizedBox(height: 10),
											Container(
												width: double.infinity,
												decoration: BoxDecoration(
													color: AppTokens.whiteSurface,
													borderRadius: BorderRadius.circular(AppTokens.radiusMd),
													border: Border.all(color: AppTokens.greyBorder),
												),
												child: categorias.isEmpty
														? Padding(
																padding: const EdgeInsets.symmetric(
																	horizontal: 16,
																	vertical: 24,
																),
																child: Text(
																	"No hay categorías. Creá una arriba.",
																	textAlign: TextAlign.center,
																	style: TextStyle(
																		color: Colors.grey.shade600,
																		fontSize: 14,
																	),
																),
															)
														: Column(
																mainAxisSize: MainAxisSize.min,
																children: [
																	for (var i = 0; i < categorias.length; i++) ...[
																		if (i > 0)
																			Divider(
																				height: 1,
																				color: Colors.grey.shade200,
																			),
																		Material(
																			color: Colors.transparent,
																			child: Padding(
																				padding: const EdgeInsets.symmetric(
																					horizontal: 10,
																					vertical: 8,
																				),
																				child: Row(
																					crossAxisAlignment:
																							CrossAxisAlignment.center,
																					children: [
																						Expanded(
																							child: Text(
																								categorias[i],
																								style: const TextStyle(
																									fontSize: 15,
																									fontWeight:
																											FontWeight.w600,
																									color: Colors.black87,
																								),
																							),
																						),
																						TextButton.icon(
																							onPressed: () => _editar(
																								i,
																								categorias[i],
																							),
																							icon: const Icon(
																								Icons.edit_outlined,
																								size: 20,
																							),
																							label: const Text("Editar"),
																							style: TextButton.styleFrom(
																								foregroundColor:
																										Colors.black87,
																							),
																						),
																						TextButton.icon(
																							onPressed: () => _eliminar(
																								i,
																								categorias[i],
																							),
																							icon: Icon(
																								Icons.delete_outline,
																								size: 20,
																								color: Colors.red.shade700,
																							),
																							label: Text(
																								"Eliminar",
																								style: TextStyle(
																									color: Colors.red.shade700,
																								),
																							),
																						),
																					],
																				),
																			),
																		),
																	],
																],
															),
											),
										],
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
