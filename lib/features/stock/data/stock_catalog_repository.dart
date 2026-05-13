import "package:supabase_flutter/supabase_flutter.dart";

import "../domain/stock_product.dart";

class StockCatalogRepository {
	StockCatalogRepository(this._client);

	final SupabaseClient _client;

	Future<List<StockProduct>> fetchAll() async {
		final raw = await _client
				.from("stock_items")
				.select("id, nombre, categoria, cantidad, codigo")
				.order("nombre");
		final list = raw as List? ?? [];
		return list
				.map((e) => StockProduct.fromJson(Map<String, dynamic>.from(e as Map)))
				.toList();
	}

	Future<void> update(StockProduct p) async {
		await _client.from("stock_items").update({
			"nombre": p.nombre,
			"categoria": p.categoria,
			"cantidad": p.cantidad,
			"codigo": p.codigo,
		}).eq("id", p.id);
	}

	Future<StockProduct> insert({
		required String nombre,
		required String categoria,
		required int cantidad,
		String? codigo,
	}) async {
		final row = await _client
				.from("stock_items")
				.insert({
					"nombre": nombre,
					"categoria": categoria,
					"cantidad": cantidad,
					"codigo": codigo,
				})
				.select("id, nombre, categoria, cantidad, codigo")
				.single();
		return StockProduct.fromJson(Map<String, dynamic>.from(row as Map));
	}

	Future<void> deleteByIds(Set<String> ids) async {
		if (ids.isEmpty) return;
		final list = ids.toList();
		await _client.from("stock_items").delete().inFilter("id", list);
	}
}
