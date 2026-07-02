import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../auth/application/auth_session_provider.dart";
import "../domain/compras_in_app_notification_row.dart";
import "compras_stock_repository_provider.dart";

/// Notificaciones in-app de Compras (HTTP; actualización manual o Realtime global).
final comprasInAppNotificationsProvider =
		AsyncNotifierProvider<ComprasInAppNotificationsNotifier,
				List<ComprasInAppNotificationRow>>(
	ComprasInAppNotificationsNotifier.new,
);

class ComprasInAppNotificationsNotifier
		extends AsyncNotifier<List<ComprasInAppNotificationRow>> {
	@override
	Future<List<ComprasInAppNotificationRow>> build() async {
		ref.keepAlive();
		final session = ref.watch(authSessionProvider);
		if (session == null) return const [];
		return ref.read(comprasStockRepositoryProvider).fetchMyNotifications();
	}

	Future<void> refresh({bool silent = false}) async {
		if (!silent) {
			state = const AsyncValue.loading();
		}
		state = await AsyncValue.guard(() async {
			final session = ref.read(authSessionProvider);
			if (session == null) return const <ComprasInAppNotificationRow>[];
			return ref.read(comprasStockRepositoryProvider).fetchMyNotifications();
		});
	}
}
