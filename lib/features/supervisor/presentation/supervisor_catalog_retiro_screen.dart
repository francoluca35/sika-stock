import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/refresh/screen_refresh.dart";
import "../../../core/theme/app_tokens.dart";
import "../../auth/application/auth_providers.dart";
import "../../auth/domain/app_role.dart";
import "../../orders/domain/order_priority.dart";
import "../../panol/application/panol_forwarded_orders_provider.dart";
import "../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../stock/domain/stock_product.dart";
import "../../stock/presentation/widgets/stock_screen_header.dart";
import "../application/maintenance_orders_provider.dart";
import "widgets/supervisor_pedir_producto_dialog.dart";

/// Supervisor: elige una línea del **catálogo** de stock, confirma cantidad y destino,
/// y registra retiro con stock o deriva a pañol si no alcanza el inventario.
class SupervisorCatalogRetiroScreen extends ConsumerStatefulWidget {
	const SupervisorCatalogRetiroScreen({super.key});

	@override
	ConsumerState<SupervisorCatalogRetiroScreen> createState() =>
			_SupervisorCatalogRetiroScreenState();
}

class _SupervisorCatalogRetiroScreenState extends ConsumerState<SupervisorCatalogRetiroScreen> {
	final _buscarCtrl = TextEditingController();
	final _cantidadCtrl = TextEditingController(text: "1");
	final _destinoCtrl = TextEditingController();
	final _formKey = GlobalKey<FormState>();
	StockProduct? _seleccion;
	bool _enviando = false;

	@override
	void dispose() {
		_buscarCtrl.dispose();
		_cantidadCtrl.dispose();
		_destinoCtrl.dispose();
		super.dispose();
	}

	void _onBack(BuildContext context) {
		if (context.canPop()) {
			context.pop();
		} else {
			context.go("/home");
		}
	}

	List<StockProduct> _filtrar(List<StockProduct> todos) {
		final q = _buscarCtrl.text.trim().toLowerCase();
		final list = todos.where((p) {
			if (q.isEmpty) return true;
			final enNombre = p.nombre.toLowerCase().contains(q);
			final enCat = p.categoria.toLowerCase().contains(q);
			final enCod = (p.codigo ?? "").toLowerCase().contains(q);
			return enNombre || enCat || enCod;
		}).toList();
		list.sort(
			(a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
		);
		return list;
	}

	int? _cantidadPedida() {
		final raw = _cantidadCtrl.text.trim();
		if (raw.isEmpty) return null;
		return int.tryParse(raw);
	}

	bool _hayStockSuficiente(StockProduct p, int cantidad) {
		return p.cantidad > 0 && p.cantidad >= cantidad;
	}

	Future<void> _confirmar({required bool hayStock}) async {
		if (!_formKey.currentState!.validate()) return;
		final sel = _seleccion;
		if (sel == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Elegí un producto del catálogo.")),
			);
			return;
		}
		final cant = _cantidadPedida();
		if (cant == null || cant < 1) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Indicá una cantidad válida (≥ 1).")),
			);
			return;
		}
		if (hayStock && !_hayStockSuficiente(sel, cant)) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text("No hay stock suficiente para esa cantidad. Usá «Derivar a pañol»."),
				),
			);
			return;
		}
		if (!hayStock && _hayStockSuficiente(sel, cant)) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text("Hay stock suficiente: usá «Confirmar retiro» para avisar el retiro."),
				),
			);
			return;
		}

		final perfil = await ref.read(currentProfileProvider.future);
		if (perfil?.rol != AppRole.supervisor) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Solo el rol Supervisor puede usar este flujo.")),
			);
			return;
		}

		final nombre = perfil!.nombre?.trim();
		final usuario = perfil.usuario?.trim();
		final display = (nombre != null && nombre.isNotEmpty)
				? nombre
				: (usuario != null && usuario.isNotEmpty)
						? usuario
						: "Supervisor";
		final solicitanteDisplay = "$display · SUPERVISOR (catálogo)";

		setState(() => _enviando = true);
		try {
			await ref.read(maintenanceOrdersProvider.notifier).supervisorCreateFromCatalogAndDecide(
						solicitanteDisplay: solicitanteDisplay,
						productName: sel.nombre,
						quantity: cant,
						productType: sel.categoria,
						priority: OrderPriority.media.dbValue,
						destination: _destinoCtrl.text.trim(),
						hayStock: hayStock,
						stockItemId: hayStock ? sel.id : null,
					);
			if (!hayStock) {
				ref.invalidate(panolForwardedOrdersProvider);
			}
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						hayStock
								? "RETIRO OK: pañol y mantenimiento avisados; pedido en historial; stock descontado."
								: "Registrado: derivado a pañol (sin stock suficiente en inventario).",
					),
				),
			);
			_onBack(context);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo registrar: $e")),
			);
		} finally {
			if (mounted) setState(() => _enviando = false);
		}
	}

	bool _busquedaSinResultados(List<StockProduct> filtrados) {
		return _buscarCtrl.text.trim().isNotEmpty && filtrados.isEmpty;
	}

	Future<void> _pedirProductoAPanol() async {
		final busqueda = _buscarCtrl.text.trim();
		if (busqueda.isEmpty) return;

		final datos = await showSupervisorPedirProductoDialog(
			context: context,
			nombreInicial: busqueda,
			cantidadInicial: _cantidadPedida(),
			destinoInicial: _destinoCtrl.text.trim().isEmpty ? null : _destinoCtrl.text.trim(),
		);
		if (datos == null || !mounted) return;

		final perfil = await ref.read(currentProfileProvider.future);
		if (perfil?.rol != AppRole.supervisor) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text("Solo el rol Supervisor puede usar este flujo.")),
			);
			return;
		}

		final nombre = perfil!.nombre?.trim();
		final usuario = perfil.usuario?.trim();
		final display = (nombre != null && nombre.isNotEmpty)
				? nombre
				: (usuario != null && usuario.isNotEmpty)
						? usuario
						: "Supervisor";
		final solicitanteDisplay = "$display · SUPERVISOR (pedido a pañol)";

		setState(() => _enviando = true);
		try {
			await ref.read(maintenanceOrdersProvider.notifier).supervisorCreateFromCatalogAndDecide(
						solicitanteDisplay: solicitanteDisplay,
						productName: datos.productName,
						quantity: datos.quantity,
						productType: datos.productType,
						priority: datos.priority,
						destination: datos.destination,
						hayStock: false,
					);
			ref.invalidate(panolForwardedOrdersProvider);
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(
						"Pedido enviado a pañol: ${datos.productName} · ${datos.quantity} u.",
					),
				),
			);
			_onBack(context);
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text("No se pudo enviar el pedido: $e")),
			);
		} finally {
			if (mounted) setState(() => _enviando = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final catalogAsync = ref.watch(supervisorStockCatalogProvider);
		return catalogAsync.when(
			loading: () => Scaffold(
				backgroundColor: AppTokens.surfacePage,
				body: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						StockScreenHeader(
							title: "ELEGIR PRODUCTO",
							onBack: () => _onBack(context),
							onRefresh: () => ScreenRefresh.pedidosSupervisor(ref),
						),
						const Expanded(child: Center(child: CircularProgressIndicator())),
					],
				),
			),
			error: (e, _) => Scaffold(
				backgroundColor: AppTokens.surfacePage,
				body: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						StockScreenHeader(
							title: "ELEGIR PRODUCTO",
							onBack: () => _onBack(context),
							onRefresh: () => ScreenRefresh.pedidosSupervisor(ref),
						),
						Expanded(
							child: Center(
								child: Padding(
									padding: const EdgeInsets.all(24),
									child: Column(
										mainAxisSize: MainAxisSize.min,
										children: [
											Text("No se pudo cargar el catálogo.\n$e", textAlign: TextAlign.center),
											const SizedBox(height: 12),
											FilledButton(
												onPressed: () => ref.invalidate(supervisorStockCatalogProvider),
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
			data: (catalog) {
				final filtrados = _filtrar(catalog);
				final cant = _cantidadPedida() ?? 0;
				final sel = _seleccion;
				final haySuf = sel != null && cant > 0 && _hayStockSuficiente(sel, cant);
				final sinResultados = _busquedaSinResultados(filtrados);

				return Scaffold(
					backgroundColor: AppTokens.surfacePage,
					body: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							StockScreenHeader(
								title: "ELEGIR PRODUCTO",
								onBack: () => _onBack(context),
								onRefresh: () => ScreenRefresh.pedidosSupervisor(ref),
							),
							Expanded(
								child: Form(
									key: _formKey,
									child: ListView(
										padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
										children: [
											Text(
												"Elegí la línea del inventario, la cantidad y el destino. "
												"Si hay unidades disponibles, confirmá el retiro; si no alcanza, derivá a pañol.",
												style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.35),
											),
											const SizedBox(height: 14),
											TextFormField(
												controller: _buscarCtrl,
												decoration: const InputDecoration(
													labelText: "Buscar en catálogo",
													border: OutlineInputBorder(),
													isDense: true,
												),
												onChanged: (_) => setState(() {}),
											),
											const SizedBox(height: 12),
											...filtrados.take(80).map((p) {
												final marcado = _seleccion?.id == p.id;
												return Padding(
													padding: const EdgeInsets.only(bottom: 6),
													child: Material(
														color: marcado ? AppTokens.yellowHeader.withValues(alpha: 0.35) : AppTokens.whiteSurface,
														borderRadius: BorderRadius.circular(10),
														child: InkWell(
															borderRadius: BorderRadius.circular(10),
															onTap: () => setState(() => _seleccion = p),
															child: Padding(
																padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
																child: Row(
																	children: [
																		Expanded(
																			child: Column(
																				crossAxisAlignment: CrossAxisAlignment.start,
																				children: [
																					Text(
																						p.nombre,
																						style: const TextStyle(
																							fontWeight: FontWeight.w700,
																							fontSize: 13,
																							color: Colors.black87,
																						),
																					),
																					const SizedBox(height: 2),
																					Text(
																						"${p.categoria} · Disponible: ${p.cantidad} u."
																						"${p.codigo != null && p.codigo!.isNotEmpty ? " · ${p.codigo}" : ""}",
																						style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
																					),
																				],
																			),
																		),
																		if (marcado)
																			const Icon(Icons.check_circle, color: Colors.black87, size: 22),
																	],
																),
															),
														),
													),
												);
											}),
											if (sinResultados)
												Padding(
													padding: const EdgeInsets.symmetric(vertical: 16),
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.stretch,
														children: [
															Text(
																"No figura en el catálogo: «${_buscarCtrl.text.trim()}».",
																textAlign: TextAlign.center,
																style: TextStyle(
																	color: Colors.grey.shade800,
																	fontWeight: FontWeight.w600,
																),
															),
															const SizedBox(height: 12),
															FilledButton.icon(
																style: FilledButton.styleFrom(
																	backgroundColor: AppTokens.redAction,
																	foregroundColor: Colors.white,
																	padding: const EdgeInsets.symmetric(vertical: 14),
																),
																onPressed: _enviando ? null : _pedirProductoAPanol,
																icon: const Icon(Icons.add_shopping_cart_outlined),
																label: const Text(
																	"PEDIR PRODUCTO",
																	style: TextStyle(fontWeight: FontWeight.w800),
																),
															),
														],
													),
												)
											else if (filtrados.isEmpty)
												Padding(
													padding: const EdgeInsets.symmetric(vertical: 24),
													child: Text(
														"No hay resultados.",
														textAlign: TextAlign.center,
														style: TextStyle(color: Colors.grey.shade700),
													),
												),
											const SizedBox(height: 16),
											TextFormField(
												controller: _cantidadCtrl,
												keyboardType: TextInputType.number,
												decoration: const InputDecoration(
													labelText: "Cantidad",
													border: OutlineInputBorder(),
													isDense: true,
												),
												validator: (v) {
													final n = int.tryParse((v ?? "").trim());
													if (n == null || n < 1) return "Cantidad ≥ 1";
													return null;
												},
												onChanged: (_) => setState(() {}),
											),
											const SizedBox(height: 12),
											TextFormField(
												controller: _destinoCtrl,
												decoration: const InputDecoration(
													labelText: "Destino / sector",
													border: OutlineInputBorder(),
													isDense: true,
												),
												validator: (v) {
													if ((v ?? "").trim().isEmpty) return "Requerido";
													return null;
												},
											),
											if (sel != null && cant > 0) ...[
												const SizedBox(height: 12),
												DecoratedBox(
													decoration: BoxDecoration(
														color: haySuf
																? const Color(0xFFE8F5E9)
																: Colors.orange.shade50,
														borderRadius: BorderRadius.circular(10),
														border: Border.all(
															color: haySuf ? const Color(0xFF2E7D32) : Colors.orange.shade800,
															width: 1.1,
														),
													),
													child: Padding(
														padding: const EdgeInsets.all(12),
														child: Text(
															haySuf
																	? "Hay ${sel.cantidad} u. en inventario; pedís $cant u. Podés confirmar retiro."
																	: "No alcanza el inventario (${sel.cantidad} u.) o no hay stock. Derivá a pañol.",
															style: TextStyle(
																fontSize: 13,
																height: 1.3,
																color: haySuf ? const Color(0xFF1B5E20) : Colors.orange.shade900,
															),
														),
													),
												),
											],
											const SizedBox(height: 20),
											if (_enviando)
												const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
											else if (!sinResultados) ...[
												FilledButton(
													style: FilledButton.styleFrom(
														backgroundColor: AppTokens.statusOk,
														foregroundColor: Colors.white,
													),
													onPressed: (sel != null && haySuf) ? () => _confirmar(hayStock: true) : null,
													child: const Text(
														"RETIRO OK",
														style: TextStyle(fontWeight: FontWeight.w800),
													),
												),
												const SizedBox(height: 10),
												FilledButton(
													style: FilledButton.styleFrom(
														backgroundColor: Colors.orange.shade800,
														foregroundColor: Colors.white,
													),
													onPressed: (sel != null && cant > 0 && !haySuf)
															? () => _confirmar(hayStock: false)
															: null,
													child: const Text(
														"DERIVAR A PAÑOL (SIN STOCK)",
														style: TextStyle(fontWeight: FontWeight.w800),
													),
												),
											],
										],
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
