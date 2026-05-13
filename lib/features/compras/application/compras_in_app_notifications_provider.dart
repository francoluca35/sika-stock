import "package:flutter_riverpod/flutter_riverpod.dart";

import "../domain/compras_in_app_notification_row.dart";
import "compras_flow_realtime_tick_provider.dart";
import "compras_stock_repository_provider.dart";

final comprasInAppNotificationsProvider =
		FutureProvider.autoDispose<List<ComprasInAppNotificationRow>>((ref) async {
	ref.watch(comprasFlowRealtimeTickProvider);
	return ref.read(comprasStockRepositoryProvider).fetchMyNotifications();
});
