import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../data/stock_catalog_repository.dart";
import "../domain/stock_product.dart";

final stockCatalogRepositoryProvider = Provider<StockCatalogRepository>(
	(ref) => StockCatalogRepository(ref.watch(supabaseClientProvider)),
);

/// Catálogo de stock desde Supabase (`stock_items`).
final supervisorStockCatalogProvider =
		AsyncNotifierProvider<SupervisorStockCatalogNotifier, List<StockProduct>>(
	SupervisorStockCatalogNotifier.new,
);

class SupervisorStockCatalogNotifier extends AsyncNotifier<List<StockProduct>> {
	@override
	Future<List<StockProduct>> build() async {
		return ref.read(stockCatalogRepositoryProvider).fetchAll();
	}

	Future<void> refresh() async {
		state = const AsyncValue.loading();
		state = await AsyncValue.guard(
			() => ref.read(stockCatalogRepositoryProvider).fetchAll(),
		);
	}

	Future<void> replaceProduct(StockProduct updated) async {
		await ref.read(stockCatalogRepositoryProvider).update(updated);
		await refresh();
	}

	Future<void> removeByIds(Set<String> ids) async {
		await ref.read(stockCatalogRepositoryProvider).deleteByIds(ids);
		await refresh();
	}
}
