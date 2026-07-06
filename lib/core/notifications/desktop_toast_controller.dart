import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class DesktopToastItem {
	const DesktopToastItem({
		required this.id,
		required this.title,
		required this.message,
		this.subtitle,
		this.actionLabel,
		this.onAction,
	});

	final String id;
	final String title;
	final String message;
	final String? subtitle;
	final String? actionLabel;
	final VoidCallback? onAction;
}

class DesktopToastNotifier extends Notifier<List<DesktopToastItem>> {
	final Map<String, Timer> _timers = {};

	@override
	List<DesktopToastItem> build() {
		ref.onDispose(() {
			for (final t in _timers.values) {
				t.cancel();
			}
			_timers.clear();
		});
		return const [];
	}

	void show({
		required String idKey,
		required String title,
		required String message,
		String? subtitle,
		String? actionLabel,
		VoidCallback? onAction,
		Duration duration = const Duration(seconds: 9),
	}) {
		final id = idKey;
		_timers[id]?.cancel();

		final item = DesktopToastItem(
			id: id,
			title: title,
			message: message,
			subtitle: subtitle,
			actionLabel: actionLabel,
			onAction: onAction,
		);

		final current = state.where((t) => t.id != id).toList();
		state = [...current, item].take(4).toList();

		_timers[id] = Timer(duration, () => dismiss(id));
	}

	void dismiss(String id) {
		_timers.remove(id)?.cancel();
		state = state.where((t) => t.id != id).toList();
	}
}

final desktopToastProvider =
		NotifierProvider<DesktopToastNotifier, List<DesktopToastItem>>(
	DesktopToastNotifier.new,
);
