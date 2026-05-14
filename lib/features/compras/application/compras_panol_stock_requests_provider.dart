import "package:flutter_riverpod/flutter_riverpod.dart";

import "../domain/compras_panol_stock_request_row.dart";
import "compras_stock_repository_provider.dart";

final comprasPanolStockRequestsProvider =
		FutureProvider<List<ComprasPanolStockRequestRow>>((ref) async {
	ref.keepAlive();
	return ref.read(comprasStockRepositoryProvider).fetchPanolStockRequests();
});
