import "package:flutter_riverpod/flutter_riverpod.dart";

import "../domain/stock_category_defaults.dart";

/// Lista de categorías en **memoria** (compartida entre Agregar stock y Categorías).
/// Más adelante: sustituir por tabla Supabase.
final stockCategoriesProvider =
		NotifierProvider<StockCategoriesNotifier, List<String>>(StockCategoriesNotifier.new);

class StockCategoriesNotifier extends Notifier<List<String>> {
	@override
	List<String> build() => List<String>.from(kDefaultStockCategories);

	/// `false` si ya existía (mismo texto ignorando mayúsculas).
	bool addCategory(String raw) {
		final name = raw.trim();
		if (name.length < 2) return false;
		final lower = name.toLowerCase();
		if (state.any((e) => e.toLowerCase() == lower)) return false;
		state = [...state, name];
		return true;
	}

	/// `false` si el nombre ya lo tiene otra categoría.
	bool updateAt(int index, String raw) {
		if (index < 0 || index >= state.length) return false;
		final name = raw.trim();
		if (name.length < 2) return false;
		final lower = name.toLowerCase();
		for (var i = 0; i < state.length; i++) {
			if (i != index && state[i].toLowerCase() == lower) return false;
		}
		final next = [...state];
		next[index] = name;
		state = next;
		return true;
	}

	void removeAt(int index) {
		if (index < 0 || index >= state.length) return;
		state = [...state]..removeAt(index);
	}
}
