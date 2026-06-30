import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_providers.dart";
import "../data/stock_catalog_repository.dart";
import "../domain/stock_product.dart";

final stockCatalogRepositoryProvider = Provider<StockCatalogRepository>(
	(ref) => StockCatalogRepository(ref.watch(supabaseClientProvider)),
);

/// Catálogo de stock desde Supabase (`stock_items`), cargado una vez y cacheado.
final supervisorStockCatalogProvider =
		AsyncNotifierProvider<SupervisorStockCatalogNotifier, List<StockProduct>>(
	SupervisorStockCatalogNotifier.new,
);

class SupervisorStockCatalogNotifier extends AsyncNotifier<List<StockProduct>> {
	@override
	Future<List<StockProduct>> build() async {
		ref.keepAlive();
		return ref.read(stockCatalogRepositoryProvider).fetchAll();
	}

	Future<void> refresh({bool showLoading = false}) async {
		final cached = state.asData?.value;
		if (showLoading || cached == null) {
			state = const AsyncValue.loading();
		}
		state = await AsyncValue.guard(
			() => ref.read(stockCatalogRepositoryProvider).fetchAll(),
		);
	}

	Future<void> replaceProduct(StockProduct updated) async {
		await ref.read(stockCatalogRepositoryProvider).update(updated);
		final prev = state.asData?.value;
		if (prev == null) {
			await refresh();
			return;
		}
		state = AsyncData([
			for (final p in prev)
				if (p.id == updated.id) updated else p,
		]);
	}

	Future<void> removeByIds(Set<String> ids) async {
		await ref.read(stockCatalogRepositoryProvider).deleteByIds(ids);
		final prev = state.asData?.value;
		if (prev == null) {
			await refresh();
			return;
		}
		state = AsyncData(prev.where((p) => !ids.contains(p.id)).toList());
	}
}
