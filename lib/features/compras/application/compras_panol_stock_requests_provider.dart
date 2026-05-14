import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/realtime/realtime_refresh.dart";
import "../domain/compras_panol_stock_request_row.dart";
import "compras_flow_realtime_tick_provider.dart";
import "compras_stock_repository_provider.dart";

final comprasPanolStockRequestsProvider =
		FutureProvider<List<ComprasPanolStockRequestRow>>((ref) async {
	ref.keepAlive();
	bindRealtimeTickRefresh(
		ref,
		comprasFlowRealtimeTickProvider,
		() => ref.invalidateSelf(),
	);
	ref.watch(comprasFlowRealtimeTickProvider);
	return ref.read(comprasStockRepositoryProvider).fetchPanolStockRequests();
});
