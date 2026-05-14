import "package:flutter_riverpod/flutter_riverpod.dart";

/// Al cambiar el tick Realtime, ejecuta [onTick] (p. ej. `refresh` o `invalidateSelf`).
void bindRealtimeTickRefresh<T extends Notifier<int>>(
	Ref ref,
	NotifierProvider<T, int> tickProvider,
	void Function() onTick,
) {
	ref.listen<int>(tickProvider, (prev, next) {
		if (prev != next) onTick();
	});
}
