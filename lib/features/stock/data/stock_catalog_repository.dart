import "package:supabase_flutter/supabase_flutter.dart";

import "../domain/stock_product.dart";

class StockCatalogRepository {
	StockCatalogRepository(this._client);

	final SupabaseClient _client;

	static const _selectCols =
			"id, nombre, categoria, cantidad, cantidad_minima, cantidad_maxima, codigo, descripcion_empresa, descripcion_fabricante, marca";

	Future<List<StockProduct>> fetchAll() async {
		const pageSize = 1000;
		var offset = 0;
		final all = <StockProduct>[];
		while (true) {
			final raw = await _client
					.from("stock_items")
					.select(_selectCols)
					.order("nombre")
					.range(offset, offset + pageSize - 1);
			final page = raw as List? ?? [];
			if (page.isEmpty) break;
			all.addAll(
				page.map(
					(e) => StockProduct.fromJson(Map<String, dynamic>.from(e as Map)),
				),
			);
			if (page.length < pageSize) break;
			offset += pageSize;
		}
		return all;
	}

	Future<StockProduct?> fetchById(String id) async {
		final row = await _client
				.from("stock_items")
				.select(_selectCols)
				.eq("id", id)
				.maybeSingle();
		if (row == null) return null;
		return StockProduct.fromJson(Map<String, dynamic>.from(row as Map));
	}

	Future<void> update(StockProduct p) async {
		await _client.from("stock_items").update({
			"nombre": p.nombre,
			"categoria": p.categoria,
			"cantidad": p.cantidad,
			"cantidad_minima": p.cantidadMinima,
			"cantidad_maxima": p.cantidadMaxima,
			"codigo": p.codigo,
			"descripcion_empresa": p.descripcionEmpresa,
			"descripcion_fabricante": p.descripcionFabricante,
			"marca": p.marca,
		}).eq("id", p.id);
	}

	Future<StockProduct> insert({
		required String codigo,
		required String nombre,
		required String descripcionEmpresa,
		required String descripcionFabricante,
		required String categoria,
		required String marca,
		required int cantidad,
		required int cantidadMinima,
		required int cantidadMaxima,
	}) async {
		final row = await _client
				.from("stock_items")
				.insert({
					"codigo": codigo,
					"nombre": nombre,
					"descripcion_empresa": descripcionEmpresa,
					"descripcion_fabricante": descripcionFabricante,
					"categoria": categoria,
					"marca": marca,
					"cantidad": cantidad,
					"cantidad_minima": cantidadMinima,
					"cantidad_maxima": cantidadMaxima,
				})
				.select(_selectCols)
				.single();
		return StockProduct.fromJson(Map<String, dynamic>.from(row as Map));
	}

	Future<int> insertBatch(List<Map<String, dynamic>> rows) async {
		if (rows.isEmpty) return 0;
		const chunkSize = 80;
		var total = 0;
		for (var i = 0; i < rows.length; i += chunkSize) {
			final end = i + chunkSize > rows.length ? rows.length : i + chunkSize;
			final chunk = rows.sublist(i, end);
			await _client.from("stock_items").insert(chunk);
			total += chunk.length;
		}
		return total;
	}

	Future<void> deleteByIds(Set<String> ids) async {
		if (ids.isEmpty) return;
		final list = ids.toList();
		await _client.from("stock_items").delete().inFilter("id", list);
	}
}
