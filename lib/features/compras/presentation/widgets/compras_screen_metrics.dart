import "package:flutter/material.dart";

import "../../../../core/theme/app_tokens.dart";

/// Breakpoints y márgenes para pantallas **Compras** (historiales, listados).
abstract final class ComprasScreenMetrics {
	/// A partir de este ancho se muestra tabla completa; debajo, tarjetas apiladas.
	static const double wideTableBreakpoint = 780;

	/// Ancho máximo del contenido en escritorio (legibilidad).
	static const double maxContentWidth = AppTokens.maxContentWidth;

	static bool useWideTable(BuildContext context) =>
			MediaQuery.sizeOf(context).width >= wideTableBreakpoint;

	static bool useWideTableFromConstraints(double maxWidth) =>
			maxWidth >= wideTableBreakpoint;

	/// Padding horizontal según ancho de ventana.
	static EdgeInsets horizontalPadding(BuildContext context) {
		final w = MediaQuery.sizeOf(context).width;
		if (w >= 1200) return const EdgeInsets.symmetric(horizontal: 32);
		if (w >= 600) return const EdgeInsets.symmetric(horizontal: 20);
		return const EdgeInsets.symmetric(horizontal: 12);
	}

	static EdgeInsets bodyPadding(BuildContext context) {
		final bottom = MediaQuery.paddingOf(context).bottom;
		final h = horizontalPadding(context).horizontal / 2;
		return EdgeInsets.fromLTRB(h, 0, h, 12 + bottom);
	}
}
