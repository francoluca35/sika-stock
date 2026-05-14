import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../data/stock_categories_repository.dart";
import "../domain/stock_category.dart";

final stockCategoriesRepositoryProvider = Provider<StockCategoriesRepository>(
	(ref) => StockCategoriesRepository(ref.watch(supabaseClientProvider)),
);

/// Categorías persistidas en Supabase (`stock_categories`).
final stockCategoriesProvider =
		AsyncNotifierProvider<StockCategoriesNotifier, List<StockCategory>>(
	StockCategoriesNotifier.new,
);

class StockCategoriesNotifier extends AsyncNotifier<List<StockCategory>> {
	@override
	Future<List<StockCategory>> build() async {
		return ref.read(stockCategoriesRepositoryProvider).fetchAll();
	}

	Future<void> refresh() async {
		state = const AsyncValue.loading();
		state = await AsyncValue.guard(
			() => ref.read(stockCategoriesRepositoryProvider).fetchAll(),
		);
	}

	/// `false` si falla (duplicado, red, permisos, etc.).
	Future<bool> addCategory(String raw) async {
		final name = raw.trim();
		if (name.length < 2) return false;
		try {
			await ref.read(stockCategoriesRepositoryProvider).insert(name);
		} catch (_) {
			return false;
		}
		await refresh();
		return true;
	}

	/// `false` si el nombre ya existe en otra fila o falla la actualización.
	Future<bool> updateCategory(String id, String raw) async {
		final name = raw.trim();
		if (name.length < 2) return false;
		try {
			await ref.read(stockCategoriesRepositoryProvider).updateName(id, name);
		} catch (_) {
			return false;
		}
		await refresh();
		return true;
	}

	Future<void> deleteById(String id) async {
		await ref.read(stockCategoriesRepositoryProvider).deleteById(id);
		await refresh();
	}
}
