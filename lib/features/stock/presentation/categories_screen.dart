import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";
import "../../auth/presentation/widgets/auth_field_styles.dart";
import "../application/stock_categories_provider.dart";
import "../domain/stock_category.dart";
import "widgets/stock_screen_header.dart";

/// Alta y listado de categorías (editar / eliminar solo rol **Pañol** vía Supabase).
///
/// [fallbackLocation] cuando no hay historial para `pop` (p. ej. `/home` en Pañol).
///
/// [allowPanolCategoryMutations] en `true` solo en la ruta `/panol/categorías`; la UI
/// habilita alta/edición/baja si además el perfil es `AppRole.panol`.
class CategoriesScreen extends ConsumerStatefulWidget {
	const CategoriesScreen({
		super.key,
		this.fallbackLocation = "/stock",
		this.allowPanolCategoryMutations = false,
	});

	final String fallbackLocation;

	/// Si es `true`, se permite gestión **solo** cuando el usuario autenticado es pañol.
	final bool allowPanolCategoryMutations;

	@override
	ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
	final _formKey = GlobalKey<FormState>();
	final _nombreCtrl = TextEditingController();
	bool _saving = false;

	@override
	void dispose() {
		_nombreCtrl.dispose();
		super.dispose();
	}

	bool get _canMutate {
		if (!widget.allowPanolCategoryMutations) return false;
		final p = ref.watch(currentProfileProvider);
		return p.maybeWhen(
			data: (row) => row?.rol == AppRole.panol,
			orElse: () => false,
		);
	}

	Future<void> _guardar() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _saving = true);
		final ok = await ref.read(stockCategoriesProvider.notifier).addCategory(_nombreCtrl.text);
		if (!mounted) return;
		setState(() => _saving = false);

		if (ok) {
			_nombreCtrl.clear();
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Categoría guardada.")),
			);
		} else {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text("No se pudo guardar (nombre duplicado o sin permiso)."),
				),
			);
		}
	}

	Future<void> _editar(StockCategory actual) async {
		final ctrl = TextEditingController(text: actual.name);
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
		final ok = await ref.read(stockCategoriesProvider.notifier).updateCategory(actual.id, nuevo);
		if (!mounted) return;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					ok
							? "Categoría actualizada."
							: "No se pudo actualizar (nombre duplicado o sin permiso).",
				),
			),
		);
	}

	Future<void> _eliminar(StockCategory cat) async {
		final ok = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text("Eliminar categoría"),
				content: Text("¿Eliminar «${cat.name}»?"),
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
		try {
			await ref.read(stockCategoriesProvider.notifier).deleteById(cat.id);
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("Se eliminó «${cat.name}».")),
			);
		} catch (_) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("No se pudo eliminar la categoría.")),
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		final asyncCats = ref.watch(stockCategoriesProvider);
		final showReadOnlyInfo = !widget.allowPanolCategoryMutations
				? true
				: ref.watch(currentProfileProvider).maybeWhen(
						data: (p) => p?.rol != AppRole.panol,
						orElse: () => false,
					);

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
						child: RefreshIndicator(
							onRefresh: () => ref.read(stockCategoriesProvider.notifier).refresh(),
							child: asyncCats.when(
								loading: () => const Center(child: CircularProgressIndicator()),
								error: (e, _) => ListView(
									padding: const EdgeInsets.all(24),
									children: [
										Text(
											"No se pudieron cargar las categorías.\n$e",
											style: TextStyle(color: Colors.red.shade800),
										),
										const SizedBox(height: 16),
										FilledButton(
											onPressed: () => ref.invalidate(stockCategoriesProvider),
											child: const Text("Reintentar"),
										),
									],
								),
								data: (categorias) => SingleChildScrollView(
									physics: const AlwaysScrollableScrollPhysics(),
									padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
									child: Center(
										child: ConstrainedBox(
											constraints: const BoxConstraints(maxWidth: 480),
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.stretch,
												children: [
													if (showReadOnlyInfo) ...[
														Container(
															width: double.infinity,
															padding: const EdgeInsets.all(12),
															decoration: BoxDecoration(
																color: Colors.amber.shade50,
																borderRadius: BorderRadius.circular(
																	AppTokens.radiusMd,
																),
																border: Border.all(color: Colors.amber.shade200),
															),
															child: Text(
																!widget.allowPanolCategoryMutations
																		? "La gestión de categorías la realiza Pañol desde su panel."
																		: "Solo el rol Pañol puede crear, editar o eliminar categorías.",
																style: TextStyle(
																	fontSize: 13,
																	color: Colors.grey.shade900,
																	height: 1.3,
																),
															),
														),
														const SizedBox(height: 16),
													],
													if (_canMutate) ...[
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
																		enabled: !_saving,
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
																			onPressed: _saving ? null : _guardar,
																			child: _saving
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
													],
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
																			_canMutate
																					? "No hay categorías. Creá una arriba."
																					: "No hay categorías cargadas.",
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
																										categorias[i].name,
																										style: const TextStyle(
																											fontSize: 15,
																											fontWeight:
																													FontWeight.w600,
																											color: Colors.black87,
																										),
																									),
																								),
																								if (_canMutate) ...[
																									TextButton.icon(
																										onPressed: () =>
																												_editar(categorias[i]),
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
																										onPressed: () =>
																												_eliminar(categorias[i]),
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
						),
					),
				],
			),
		);
	}
}
