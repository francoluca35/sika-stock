import "package:flutter_riverpod/flutter_riverpod.dart";

class OrderNavigationTargetNotifier extends Notifier<String?> {
	@override
	String? build() => null;

	void setTarget(String? orderId) => state = orderId;
}

/// Pedido a abrir automáticamente tras navegar desde un aviso o el tablero.
final orderNavigationTargetProvider =
		NotifierProvider<OrderNavigationTargetNotifier, String?>(
	OrderNavigationTargetNotifier.new,
);
