import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../core/theme/app_tokens.dart";
import "../../../stock/application/supervisor_stock_catalog_provider.dart";
import "../../../stock/domain/stock_product.dart";
import "../../../supervisor/domain/maintenance_order.dart";

/// Detalle del producto retirado: línea de inventario pañol (+ foto del pedido si hay).
void showRetiroProductoDetailSheet(BuildContext context, MaintenanceOrder order) {
	showModalBottomSheet<void>(
		context: context,
		isScrollControlled: true,
		useSafeArea: true,
		backgroundColor: Colors.white,
		shape: const RoundedRectangleBorder(
			borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
		),
		builder: (ctx) => _RetiroProductoDetailSheet(order: order),
	);
}

class _RetiroProductoDetailSheet extends ConsumerStatefulWidget {
	const _RetiroProductoDetailSheet({required this.order});

	final MaintenanceOrder order;

	@override
	ConsumerState<_RetiroProductoDetailSheet> createState() =>
			_RetiroProductoDetailSheetState();
}

class _RetiroProductoDetailSheetState extends ConsumerState<_RetiroProductoDetailSheet> {
	StockProduct? _stock;
	bool _loading = false;
	String? _error;

	@override
	void initState() {
		super.initState();
		_cargarStock();
	}

	Future<void> _cargarStock() async {
		final stockId = widget.order.stockItemId?.trim();
		if (stockId == null || stockId.isEmpty) return;
		setState(() {
			_loading = true;
			_error = null;
		});
		try {
			final repo = ref.read(stockCatalogRepositoryProvider);
			final p = await repo.fetchById(stockId);
			if (!mounted) return;
			setState(() {
				_stock = p;
				_loading = false;
			});
		} catch (e) {
			if (!mounted) return;
			setState(() {
				_error = "$e";
				_loading = false;
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		final o = widget.order;
		final bottom = MediaQuery.paddingOf(context).bottom;
		final foto = o.imagenUrl?.trim();

		return Padding(
			padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
			child: SingleChildScrollView(
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					mainAxisSize: MainAxisSize.min,
					children: [
						Center(
							child: Container(
								width: 40,
								height: 4,
								decoration: BoxDecoration(
									color: Colors.grey.shade400,
									borderRadius: BorderRadius.circular(40),
								),
							),
						),
						const SizedBox(height: 14),
						const Text(
							"Producto retirado",
							textAlign: TextAlign.center,
							style: TextStyle(
								fontWeight: FontWeight.bold,
								fontSize: 18,
								color: Colors.black87,
							),
						),
						const SizedBox(height: 6),
						Text(
							o.numeroOrden,
							textAlign: TextAlign.center,
							style: TextStyle(
								fontWeight: FontWeight.w700,
								fontSize: 14,
								color: Colors.grey.shade800,
							),
						),
						const SizedBox(height: 18),
						_seccionTitulo("Retiro registrado"),
						_DetalleFila(label: "Producto pedido", valor: o.producto),
						_DetalleFila(label: "Cantidad retirada", valor: "${o.quantity} u."),
						_DetalleFila(label: "Tipo", valor: o.productType),
						_DetalleFila(label: "Destino", valor: o.destination),
						const SizedBox(height: 14),
						_seccionTitulo("Inventario pañol"),
						if (_loading)
							const Padding(
								padding: EdgeInsets.symmetric(vertical: 20),
								child: Center(child: CircularProgressIndicator()),
							)
						else if (_error != null)
							Text(
								"No se pudo cargar la línea de inventario.\n$_error",
								style: TextStyle(fontSize: 13, color: Colors.red.shade800),
							)
						else if (_stock != null) ...[
							_DetalleFila(label: "Nombre en catálogo", valor: _stock!.nombre),
							_DetalleFila(label: "Categoría", valor: _stock!.categoria),
							if (_stock!.codigo != null && _stock!.codigo!.isNotEmpty)
								_DetalleFila(label: "Código", valor: _stock!.codigo!),
							if (_stock!.marca.isNotEmpty)
								_DetalleFila(label: "Marca", valor: _stock!.marca),
							_DetalleFila(
								label: "Stock actual en planta",
								valor: "${_stock!.cantidad} u.",
							),
							if (_stock!.descripcionEmpresa.isNotEmpty)
								_DetalleFila(
									label: "Descripción (empresa)",
									valor: _stock!.descripcionEmpresa,
								),
							if (_stock!.descripcionFabricante.isNotEmpty)
								_DetalleFila(
									label: "Descripción (fabricante)",
									valor: _stock!.descripcionFabricante,
								),
							if (_stock!.cantidadMinima > 0 || _stock!.cantidadMaxima > 0)
								_DetalleFila(
									label: "Mín. / máx.",
									valor:
											"${_stock!.cantidadMinima} / ${_stock!.cantidadMaxima} u.",
								),
						] else
							Text(
								o.stockItemId != null && o.stockItemId!.isNotEmpty
										? "No se encontró la línea de inventario vinculada al retiro."
										: "Este retiro no tiene una línea de catálogo asociada (sin descuento automático en inventario).",
								style: TextStyle(
									fontSize: 13,
									height: 1.35,
									color: Colors.grey.shade800,
								),
							),
						if (foto != null && foto.isNotEmpty) ...[
							const SizedBox(height: 14),
							_seccionTitulo("Foto del pedido"),
							const SizedBox(height: 6),
							ClipRRect(
								borderRadius: BorderRadius.circular(AppTokens.radiusMd),
								child: Image.network(
									foto,
									height: 200,
									width: double.infinity,
									fit: BoxFit.cover,
									errorBuilder: (_, __, ___) => const SizedBox.shrink(),
								),
							),
						],
						const SizedBox(height: 16),
						FilledButton(
							onPressed: () => Navigator.pop(context),
							child: const Text("Cerrar"),
						),
					],
				),
			),
		);
	}

	Widget _seccionTitulo(String t) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 8),
			child: Text(
				t,
				style: const TextStyle(
					fontWeight: FontWeight.w800,
					fontSize: 13,
					letterSpacing: 0.4,
					color: Colors.black87,
				),
			),
		);
	}
}

class _DetalleFila extends StatelessWidget {
	const _DetalleFila({required this.label, required this.valor});

	final String label;
	final String valor;

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 10),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						label,
						style: TextStyle(
							fontSize: 11,
							fontWeight: FontWeight.w700,
							color: Colors.grey.shade700,
							letterSpacing: 0.2,
						),
					),
					const SizedBox(height: 2),
					Text(
						valor.trim().isEmpty ? "—" : valor,
						style: const TextStyle(
							fontSize: 14,
							height: 1.35,
							color: Colors.black87,
						),
					),
				],
			),
		);
	}
}
