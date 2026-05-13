import "package:supabase_flutter/supabase_flutter.dart";

import "../domain/stock_category.dart";

class StockCategoriesRepository {
	StockCategoriesRepository(this._client);

	final SupabaseClient _client;

	Future<List<StockCategory>> fetchAll() async {
		final raw = await _client.from("stock_categories").select("id, name").order("name");
		final list = raw as List? ?? [];
		return list
				.map((e) => StockCategory.fromJson(Map<String, dynamic>.from(e as Map)))
				.toList();
	}

	Future<void> insert(String rawName) async {
		final name = rawName.trim();
		if (name.length < 2) {
			throw ArgumentError("Nombre demasiado corto");
		}
		await _client.from("stock_categories").insert({"name": name});
	}

	Future<void> updateName(String id, String rawName) async {
		final name = rawName.trim();
		if (name.length < 2) {
			throw ArgumentError("Nombre demasiado corto");
		}
		await _client.from("stock_categories").update({"name": name}).eq("id", id);
	}

	Future<void> deleteById(String id) async {
		await _client.from("stock_categories").delete().eq("id", id);
	}
}
