import "package:flutter_riverpod/flutter_riverpod.dart";

import "../domain/stock_product.dart";

/// Catálogo consultable por supervisores (demo en memoria → reemplazar por fetch Supabase).
final supervisorStockCatalogProvider =
		NotifierProvider<SupervisorStockCatalogNotifier, List<StockProduct>>(
	SupervisorStockCatalogNotifier.new,
);

class SupervisorStockCatalogNotifier extends Notifier<List<StockProduct>> {
	static List<StockProduct> _demoSeed() => [
				const StockProduct(
					id: "1",
					nombre: "Tuerca M12 inox",
					categoria: "Repuestos",
					cantidad: 240,
					codigo: "REP-M12",
				),
				const StockProduct(
					id: "2",
					nombre: "Guantes nitrilo L",
					categoria: "Consumibles",
					cantidad: 85,
					codigo: "CON-GNL",
				),
				const StockProduct(
					id: "3",
					nombre: "Llave allen 10 mm",
					categoria: "Herramientas",
					cantidad: 12,
				),
				const StockProduct(
					id: "4",
					nombre: "Cable flexible 2,5 mm²",
					categoria: "Materiales",
					cantidad: 450,
					codigo: "MAT-C25",
				),
				const StockProduct(
					id: "5",
					nombre: "Grasa litio EP2",
					categoria: "Consumibles",
					cantidad: 0,
					codigo: "CON-GR2",
				),
				const StockProduct(
					id: "6",
					nombre: "Casco seguridad blanco",
					categoria: "Materiales",
					cantidad: 18,
				),
				const StockProduct(
					id: "7",
					nombre: "Rodamiento 6205-2RS",
					categoria: "Repuestos",
					cantidad: 6,
				),
				const StockProduct(
					id: "8",
					nombre: "Sierra caladora industrial",
					categoria: "Herramientas",
					cantidad: 3,
				),
				const StockProduct(
					id: "9",
					nombre: "Perno hexagonal M16×80",
					categoria: "Repuestos",
					cantidad: 110,
				),
				const StockProduct(
					id: "10",
					nombre: "Chaleco reflectivo XL",
					categoria: "Otro",
					cantidad: 22,
				),
				const StockProduct(
					id: "11",
					nombre: "Brida acople motor-bomba serie M",
					categoria: "Repuestos",
					cantidad: 5,
					codigo: "REP-MBM",
				),
			];

	@override
	List<StockProduct> build() => _demoSeed();

	/// Reemplaza un ítem por `id` (misma fuente en memoria hasta Supabase).
	void replaceProduct(StockProduct updated) {
		final i = state.indexWhere((e) => e.id == updated.id);
		if (i < 0) return;
		final next = List<StockProduct>.from(state);
		next[i] = updated;
		state = next;
	}

	/// Quita todos los ítems cuyo `id` esté en [ids].
	void removeByIds(Set<String> ids) {
		if (ids.isEmpty) return;
		state = [
			for (final x in state)
				if (!ids.contains(x.id)) x,
		];
	}
}
