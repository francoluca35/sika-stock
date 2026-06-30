import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/widgets.dart" show ScrollableDetails;

/// Scroll táctil en web y barra visible e interactiva en escritorio.
abstract final class AppScrollBehavior {
	static bool showPersistentScrollbarThumb(BuildContext context) {
		switch (Theme.of(context).platform) {
			case TargetPlatform.android:
			case TargetPlatform.iOS:
			case TargetPlatform.fuchsia:
				return false;
			case TargetPlatform.windows:
			case TargetPlatform.linux:
			case TargetPlatform.macOS:
				break;
		}
		if (kIsWeb && MediaQuery.sizeOf(context).shortestSide < 600) {
			return false;
		}
		return true;
	}

	static ScrollBehavior material() => const _AppMaterialScrollBehavior();

	/// Evita barras automáticas en scroll anidado (p. ej. tabla stock).
	static ScrollBehavior withoutAutoScrollbar() =>
		const _NoAutoScrollbarScrollBehavior();
}

final class _AppMaterialScrollBehavior extends MaterialScrollBehavior {
	const _AppMaterialScrollBehavior();

	@override
	Set<PointerDeviceKind> get dragDevices => {
		PointerDeviceKind.touch,
		PointerDeviceKind.mouse,
		PointerDeviceKind.trackpad,
		PointerDeviceKind.stylus,
		PointerDeviceKind.invertedStylus,
		PointerDeviceKind.unknown,
	};

	@override
	Widget buildScrollbar(
		BuildContext context,
		Widget child,
		ScrollableDetails details,
	) {
		if (!AppScrollBehavior.showPersistentScrollbarThumb(context)) {
			return super.buildScrollbar(context, child, details);
		}
		if (axisDirectionToAxis(details.direction) != Axis.vertical) {
			return child;
		}
		final controller = details.controller;
		if (controller == null) return child;

		return Scrollbar(
			controller: controller,
			thumbVisibility: true,
			interactive: true,
			child: child,
		);
	}
}

final class _NoAutoScrollbarScrollBehavior extends _AppMaterialScrollBehavior {
	const _NoAutoScrollbarScrollBehavior();

	@override
	Widget buildScrollbar(
		BuildContext context,
		Widget child,
		ScrollableDetails details,
	) => child;
}
